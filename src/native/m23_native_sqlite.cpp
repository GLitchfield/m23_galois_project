#include "m23_native_sqlite.hpp"

#include <sqlite3.h>

#include <chrono>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>

namespace m23 {
namespace {

constexpr const char* schema = R"SQL(
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS certificates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  status TEXT NOT NULL CHECK(status IN ('closed','overflow','linked')),
  walk_status TEXT NOT NULL CHECK(walk_status IN ('closed','overflow','linked')),
  linked_certificate INTEGER REFERENCES certificates(id),
  seed_ordinal INTEGER NOT NULL,
  seed_twist INTEGER NOT NULL,
  checked_vertices INTEGER NOT NULL,
  discovered_vertices INTEGER NOT NULL,
  discovered_classes INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS vertices (
  ordinal INTEGER NOT NULL,
  twist INTEGER NOT NULL,
  certificate INTEGER NOT NULL REFERENCES certificates(id),
  PRIMARY KEY (ordinal, twist)
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS certificate_vertices (
  certificate INTEGER NOT NULL REFERENCES certificates(id),
  position INTEGER NOT NULL,
  ordinal INTEGER NOT NULL,
  twist INTEGER NOT NULL,
  PRIMARY KEY (certificate, position),
  FOREIGN KEY (ordinal, twist) REFERENCES vertices(ordinal, twist)
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS frontier (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  ordinal INTEGER NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS planned_work (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  ordinal INTEGER NOT NULL UNIQUE,
  shard_index INTEGER NOT NULL,
  shard_count INTEGER NOT NULL,
  CHECK(shard_count > 0 AND shard_index > 0 AND shard_index <= shard_count)
);
CREATE TABLE IF NOT EXISTS blocks (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  ordinal INTEGER NOT NULL UNIQUE,
  source TEXT NOT NULL CHECK(source IN ('ordinal','frontier')),
  refined_vertices INTEGER NOT NULL,
  generating_vertices INTEGER NOT NULL,
  new_certificates INTEGER NOT NULL,
  ledger_hits INTEGER NOT NULL,
  worker TEXT,
  shard_index INTEGER NOT NULL DEFAULT 1,
  shard_count INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS leases (
  worker TEXT PRIMARY KEY,
  ordinal INTEGER NOT NULL UNIQUE,
  source TEXT NOT NULL CHECK(source IN ('ordinal','frontier')),
  expires REAL NOT NULL,
  shard_index INTEGER NOT NULL DEFAULT 1,
  shard_count INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS vertices_certificate_idx ON vertices(certificate);
CREATE INDEX IF NOT EXISTS certificates_seed_ordinal_idx
  ON certificates(seed_ordinal);
CREATE INDEX IF NOT EXISTS planned_work_shard_idx
  ON planned_work(shard_count,shard_index,sequence);
)SQL";

constexpr const char* planned_work_schema = R"SQL(
CREATE TABLE IF NOT EXISTS planned_work (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  ordinal INTEGER NOT NULL UNIQUE,
  shard_index INTEGER NOT NULL,
  shard_count INTEGER NOT NULL,
  CHECK(shard_count > 0 AND shard_index > 0 AND shard_index <= shard_count)
);
CREATE INDEX IF NOT EXISTS planned_work_shard_idx
  ON planned_work(shard_count,shard_index,sequence);
)SQL";

class Statement {
 public:
  Statement(sqlite3* database, const char* sql) : database_(database) {
    const auto status = sqlite3_prepare_v2(database, sql, -1, &statement_, nullptr);
    if (status != SQLITE_OK) {
      throw std::runtime_error(std::string("prepare SQLite statement: ") +
                               sqlite3_errmsg(database));
    }
  }
  ~Statement() { sqlite3_finalize(statement_); }
  Statement(const Statement&) = delete;
  Statement& operator=(const Statement&) = delete;
  sqlite3_stmt* get() const { return statement_; }

 private:
  sqlite3* database_{};
  sqlite3_stmt* statement_{};
};

void check(const int status, sqlite3* database, const char* operation) {
  if (status != SQLITE_OK && status != SQLITE_DONE && status != SQLITE_ROW) {
    throw std::runtime_error(std::string(operation) + ": " +
                             sqlite3_errmsg(database));
  }
}

void execute(sqlite3* database, const char* sql) {
  char* message = nullptr;
  const auto status = sqlite3_exec(database, sql, nullptr, nullptr, &message);
  if (status != SQLITE_OK) {
    const std::string detail = message ? message : sqlite3_errmsg(database);
    sqlite3_free(message);
    throw std::runtime_error("execute SQLite statement: " + detail);
  }
}

void bind_integer(sqlite3* database, sqlite3_stmt* statement, const int index,
                  const std::uint64_t value) {
  if (value > static_cast<std::uint64_t>(
                  std::numeric_limits<sqlite3_int64>::max())) {
    throw std::runtime_error("native SQLite integer exceeds signed range");
  }
  check(sqlite3_bind_int64(statement, index,
                           static_cast<sqlite3_int64>(value)),
        database, "bind SQLite integer");
}

void bind_text(sqlite3* database, sqlite3_stmt* statement, const int index,
               const std::string& value) {
  check(sqlite3_bind_text(statement, index, value.c_str(),
                          static_cast<int>(value.size()), SQLITE_TRANSIENT),
        database, "bind SQLite text");
}

std::uint64_t column_u64(sqlite3_stmt* statement, const int column) {
  const auto value = sqlite3_column_int64(statement, column);
  if (value < 0) {
    throw std::runtime_error("native SQLite row contains a negative integer");
  }
  return static_cast<std::uint64_t>(value);
}

double unix_time() {
  return std::chrono::duration<double>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

void rollback(sqlite3* database) noexcept {
  sqlite3_exec(database, "ROLLBACK", nullptr, nullptr, nullptr);
}

std::uint64_t owned_at_or_after(const std::uint64_t first,
                                const std::uint64_t candidate,
                                const std::uint32_t shard_index,
                                const std::uint32_t shard_count) {
  const auto remainder = (candidate - first) % shard_count;
  const auto target = static_cast<std::uint64_t>(shard_index - 1);
  return candidate + (target + shard_count - remainder) % shard_count;
}

}  // namespace

NativeSqliteLedger::NativeSqliteLedger(const std::string& path,
                                       const NativeLedgerConfig& config)
    : config_(config) {
  if (config.target_order < 2 || config.macroblock_count == 0 ||
      config.start_ordinal == 0 ||
      config.start_ordinal > config.macroblock_count ||
      config.proof_limit == 0 || config.walk_limit < config.proof_limit ||
      config.source_checkpoint_sha256.empty()) {
    throw std::invalid_argument("invalid native SQLite ledger configuration");
  }
  const auto status = sqlite3_open_v2(
      path.c_str(), &database_, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
      nullptr);
  if (status != SQLITE_OK) {
    const std::string detail = database_ ? sqlite3_errmsg(database_)
                                         : sqlite3_errstr(status);
    if (database_) {
      sqlite3_close(database_);
      database_ = nullptr;
    }
    throw std::runtime_error("open native SQLite ledger: " + detail);
  }
  try {
    check(sqlite3_busy_timeout(database_, 300000), database_,
          "set SQLite busy timeout");
    execute(database_, "PRAGMA foreign_keys=ON");
    bool has_schema = false;
    {
      Statement statement(
          database_,
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name='meta'");
      const auto schema_status = sqlite3_step(statement.get());
      if (schema_status != SQLITE_ROW && schema_status != SQLITE_DONE) {
        check(schema_status, database_, "inspect native SQLite schema");
      }
      has_schema = schema_status == SQLITE_ROW;
    }
    if (!has_schema) {
      execute(database_, "PRAGMA journal_mode=WAL");
      execute(database_, "PRAGMA synchronous=FULL");
      execute(database_, schema);
    } else {
      Statement journal(database_, "PRAGMA journal_mode");
      check(sqlite3_step(journal.get()), database_, "read SQLite journal mode");
      const std::string mode = reinterpret_cast<const char*>(
          sqlite3_column_text(journal.get(), 0));
      if (mode != "wal") {
        execute(database_, "PRAGMA journal_mode=WAL");
      }
      execute(database_, "PRAGMA synchronous=FULL");
      bool has_planned_work = false;
      {
        Statement planned_table(
            database_,
            "SELECT 1 FROM sqlite_master WHERE type='table' "
            "AND name='planned_work'");
        const auto planned_status = sqlite3_step(planned_table.get());
        if (planned_status != SQLITE_ROW && planned_status != SQLITE_DONE) {
          check(planned_status, database_,
                "inspect native planned-work schema");
        }
        has_planned_work = planned_status == SQLITE_ROW;
      }
      if (!has_planned_work) {
        execute(database_, planned_work_schema);
      }
    }
    initialize();
    if (const auto planned_shards = metadata("native_work_plan_shards");
        planned_shards.has_value()) {
      const auto shards = std::stoull(*planned_shards);
      if (shards == 0 ||
          shards > std::numeric_limits<std::uint32_t>::max()) {
        throw std::runtime_error("invalid native planned-work shard count");
      }
      const auto planned_blocks = metadata("native_work_plan_blocks");
      if (!planned_blocks.has_value()) {
        throw std::runtime_error("native planned-work block count is absent");
      }
      const auto plan_schema = metadata("native_work_plan_schema");
      if (!plan_schema.has_value()) {
        throw std::runtime_error("native planned-work schema is absent");
      }
      if (*plan_schema == "m23-native-stratified-plan-v1") {
        Statement plan(
            database_,
            "SELECT COUNT(*),MIN(shard_count),MAX(shard_count) "
            "FROM planned_work");
        check(sqlite3_step(plan.get()), database_,
              "validate native planned-work rows");
        if (column_u64(plan.get(), 0) != std::stoull(*planned_blocks) ||
            column_u64(plan.get(), 1) != shards ||
            column_u64(plan.get(), 2) != shards) {
          throw std::runtime_error("native planned-work rows are incomplete");
        }
        explicit_planned_work_ = true;
      } else if (*plan_schema == "m23-native-full-cursor-plan-v1") {
        if (std::stoull(*planned_blocks) != config_.macroblock_count ||
            metadata("native_work_plan_ownership").value_or("") !=
                "ordinal-modulo-v1") {
          throw std::runtime_error("invalid native full-cursor work plan");
        }
        Statement plan(database_, "SELECT COUNT(*) FROM planned_work");
        check(sqlite3_step(plan.get()), database_,
              "validate empty native full-cursor rows");
        if (column_u64(plan.get(), 0) != 0) {
          throw std::runtime_error(
              "native full-cursor plan unexpectedly has explicit rows");
        }
      } else {
        throw std::runtime_error("unsupported native planned-work schema");
      }
      planned_shard_count_ = static_cast<std::uint32_t>(shards);
    }
    check(sqlite3_prepare_v2(
              database_,
              "SELECT certificate FROM vertices WHERE ordinal=? AND twist=?",
              -1, &lookup_statement_, nullptr),
          database_, "prepare persistent native ownership lookup");
  } catch (...) {
    sqlite3_finalize(lookup_statement_);
    sqlite3_close(database_);
    database_ = nullptr;
    throw;
  }
}

NativeSqliteLedger::~NativeSqliteLedger() {
  if (database_) {
    sqlite3_finalize(lookup_statement_);
    sqlite3_close(database_);
  }
}

std::optional<std::string> NativeSqliteLedger::metadata(
    const std::string& key) const {
  Statement statement(database_, "SELECT value FROM meta WHERE key=?");
  bind_text(database_, statement.get(), 1, key);
  const auto status = sqlite3_step(statement.get());
  if (status == SQLITE_DONE) {
    return std::nullopt;
  }
  check(status, database_, "read native SQLite metadata");
  const auto* value = sqlite3_column_text(statement.get(), 0);
  return std::string(reinterpret_cast<const char*>(value));
}

void NativeSqliteLedger::set_metadata(const std::string& key,
                                      const std::string& value) {
  Statement statement(
      database_,
      "INSERT INTO meta(key,value) VALUES(?,?) "
      "ON CONFLICT(key) DO UPDATE SET value=excluded.value");
  bind_text(database_, statement.get(), 1, key);
  bind_text(database_, statement.get(), 2, value);
  check(sqlite3_step(statement.get()), database_,
        "write native SQLite metadata");
}

void NativeSqliteLedger::initialize() {
  const std::vector<std::pair<std::string, std::string>> expected = {
      {"schema_version", "1"},
      {"config_target_order", std::to_string(config_.target_order)},
      {"config_pair_schema", "2"},
      {"config_macroblock_count", std::to_string(config_.macroblock_count)},
      {"config_first_ordinal", "1"},
      {"config_last_ordinal", std::to_string(config_.macroblock_count)},
      {"config_proof_limit", std::to_string(config_.proof_limit)},
      {"config_walk_limit", std::to_string(config_.walk_limit)},
      {"config_schedule", "frontier"},
      {"config_start_ordinal", std::to_string(config_.start_ordinal)},
      {"config_traversal_order", "native-v1"},
      {"native_coordinate_convention", "native-v1"},
      {"native_source_checkpoint_sha256",
       config_.source_checkpoint_sha256},
      {"native_source_git_revision", config_.source_git_revision},
      {"native_gap_version", config_.gap_version},
  };
  execute(database_, "BEGIN IMMEDIATE");
  try {
    const bool fresh = !metadata("schema_version").has_value();
    for (const auto& [key, value] : expected) {
      const auto stored = metadata(key);
      if (fresh) {
        set_metadata(key, value);
      } else if (!stored.has_value() || *stored != value) {
        throw std::runtime_error("native SQLite metadata mismatch for " + key);
      }
    }
    if (fresh) {
      set_metadata("sequential_next", std::to_string(config_.start_ordinal));
      set_metadata("sequential_wrapped", "0");
    }
    execute(database_, "COMMIT");
  } catch (...) {
    rollback(database_);
    throw;
  }
}

std::optional<std::uint64_t> NativeSqliteLedger::lookup(
    const NativeVertexKey& vertex) {
  sqlite3_reset(lookup_statement_);
  sqlite3_clear_bindings(lookup_statement_);
  bind_integer(database_, lookup_statement_, 1, vertex.ordinal);
  bind_integer(database_, lookup_statement_, 2, vertex.twist);
  const auto status = sqlite3_step(lookup_statement_);
  if (status == SQLITE_DONE) {
    sqlite3_reset(lookup_statement_);
    return std::nullopt;
  }
  check(status, database_, "lookup native vertex ownership");
  const auto certificate = column_u64(lookup_statement_, 0);
  sqlite3_reset(lookup_statement_);
  return certificate;
}

std::optional<NativeClaimedBlock> NativeSqliteLedger::claim_block(
    const std::string& worker, const std::uint64_t lease_seconds,
    const std::uint64_t block_target, const std::uint32_t shard_index,
    const std::uint32_t shard_count) {
  if (worker.empty() || lease_seconds == 0 || shard_count == 0 ||
      shard_index == 0 || shard_index > shard_count) {
    throw std::invalid_argument("invalid native block claim parameters");
  }
  execute(database_, "BEGIN IMMEDIATE");
  try {
    const auto now = unix_time();
    {
      Statement statement(database_, "DELETE FROM leases WHERE expires<=?");
      check(sqlite3_bind_double(statement.get(), 1, now), database_,
            "bind native lease expiry");
      check(sqlite3_step(statement.get()), database_,
            "prune expired native leases");
    }
    {
      Statement statement(
          database_,
          "SELECT ordinal,source,shard_index,shard_count FROM leases "
          "WHERE worker=?");
      bind_text(database_, statement.get(), 1, worker);
      const auto status = sqlite3_step(statement.get());
      if (status == SQLITE_ROW) {
        if (column_u64(statement.get(), 2) != shard_index ||
            column_u64(statement.get(), 3) != shard_count) {
          throw std::runtime_error("native worker changed shard assignment");
        }
        const NativeClaimedBlock result{
            column_u64(statement.get(), 0),
            reinterpret_cast<const char*>(sqlite3_column_text(statement.get(),
                                                               1))};
        Statement renew(database_,
                        "UPDATE leases SET expires=? WHERE worker=?");
        check(sqlite3_bind_double(renew.get(), 1, now + lease_seconds),
              database_, "bind native renewed expiry");
        bind_text(database_, renew.get(), 2, worker);
        check(sqlite3_step(renew.get()), database_, "renew native lease");
        execute(database_, "COMMIT");
        return result;
      }
      check(status, database_, "read existing native lease");
    }
    if (block_target > 0) {
      Statement statement(
          database_,
          "SELECT (SELECT COUNT(*) FROM blocks) + "
          "(SELECT COUNT(*) FROM leases)");
      check(sqlite3_step(statement.get()), database_,
            "count native block target");
      if (column_u64(statement.get(), 0) >= block_target) {
        execute(database_, "COMMIT");
        return std::nullopt;
      }
    }

    if (planned_shard_count_.has_value()) {
      if (shard_count != *planned_shard_count_) {
        throw std::runtime_error(
            "native worker shard count differs from the work plan");
      }
    }
    std::optional<NativeClaimedBlock> result;
    if (explicit_planned_work_) {
      Statement statement(
          database_,
          "SELECT p.ordinal FROM planned_work p "
          "LEFT JOIN blocks b USING(ordinal) "
          "LEFT JOIN leases l USING(ordinal) "
          "WHERE p.shard_index=? AND p.shard_count=? "
          "AND b.ordinal IS NULL AND l.ordinal IS NULL "
          "ORDER BY p.sequence LIMIT 1");
      bind_integer(database_, statement.get(), 1, shard_index);
      bind_integer(database_, statement.get(), 2, shard_count);
      const auto status = sqlite3_step(statement.get());
      if (status == SQLITE_ROW) {
        result = NativeClaimedBlock{column_u64(statement.get(), 0),
                                    "frontier"};
      } else {
        check(status, database_, "claim native planned block");
      }
      if (!result.has_value()) {
        Statement unfinished(
            database_,
            "SELECT EXISTS(SELECT 1 FROM planned_work p "
            "LEFT JOIN blocks b USING(ordinal) WHERE b.ordinal IS NULL)");
        check(sqlite3_step(unfinished.get()), database_,
              "inspect native planned-work barrier");
        if (sqlite3_column_int(unfinished.get(), 0) != 0) {
          execute(database_, "COMMIT");
          return std::nullopt;
        }
      }
    }
    {
      if (!result.has_value()) {
        Statement statement(
            database_,
            "SELECT f.ordinal FROM frontier f LEFT JOIN leases l USING(ordinal) "
            "WHERE l.ordinal IS NULL AND ((f.ordinal - 1) % ?) = ? "
            "ORDER BY f.sequence LIMIT 1");
        bind_integer(database_, statement.get(), 1, shard_count);
        bind_integer(database_, statement.get(), 2, shard_index - 1);
        const auto status = sqlite3_step(statement.get());
        if (status == SQLITE_ROW) {
          result = NativeClaimedBlock{column_u64(statement.get(), 0),
                                      "frontier"};
        } else {
          check(status, database_, "claim native frontier block");
        }
      }
    }
    if (!result.has_value()) {
      const auto suffix = "_" + std::to_string(shard_index) + "_of_" +
                          std::to_string(shard_count);
      const auto next_key = "sequential_next" + suffix;
      const auto wrapped_key = "sequential_wrapped" + suffix;
      auto candidate = metadata(next_key).has_value()
                           ? std::stoull(*metadata(next_key))
                           : owned_at_or_after(1, config_.start_ordinal,
                                               shard_index, shard_count);
      bool wrapped = metadata(wrapped_key).value_or("0") == "1";
      while (!result.has_value()) {
        std::uint64_t proposed = 0;
        if (!wrapped) {
          if (candidate <= config_.macroblock_count) {
            proposed = candidate;
            candidate += shard_count;
          } else if (config_.start_ordinal > 1) {
            wrapped = true;
            candidate = owned_at_or_after(1, 1, shard_index, shard_count);
            continue;
          } else {
            break;
          }
        } else if (candidate < config_.start_ordinal) {
          proposed = candidate;
          candidate += shard_count;
        } else {
          break;
        }
        set_metadata(next_key, std::to_string(candidate));
        set_metadata(wrapped_key, wrapped ? "1" : "0");
        Statement available(
            database_,
            "SELECT NOT EXISTS(SELECT 1 FROM blocks WHERE ordinal=?) AND "
            "NOT EXISTS(SELECT 1 FROM leases WHERE ordinal=?)");
        bind_integer(database_, available.get(), 1, proposed);
        bind_integer(database_, available.get(), 2, proposed);
        check(sqlite3_step(available.get()), database_,
              "test native sequential block");
        if (sqlite3_column_int(available.get(), 0) != 0) {
          result = NativeClaimedBlock{proposed, "ordinal"};
        }
      }
    }
    if (!result.has_value()) {
      execute(database_, "COMMIT");
      return std::nullopt;
    }
    {
      Statement frontier(database_,
                         "INSERT OR IGNORE INTO frontier(ordinal) VALUES(?)");
      bind_integer(database_, frontier.get(), 1, result->ordinal);
      check(sqlite3_step(frontier.get()), database_,
            "record native claimed frontier");
      Statement lease(
          database_,
          "INSERT INTO leases(worker,ordinal,source,expires,shard_index,"
          "shard_count) VALUES(?,?,?,?,?,?)");
      bind_text(database_, lease.get(), 1, worker);
      bind_integer(database_, lease.get(), 2, result->ordinal);
      bind_text(database_, lease.get(), 3, result->source);
      check(sqlite3_bind_double(lease.get(), 4, now + lease_seconds), database_,
            "bind native lease deadline");
      bind_integer(database_, lease.get(), 5, shard_index);
      bind_integer(database_, lease.get(), 6, shard_count);
      check(sqlite3_step(lease.get()), database_, "insert native lease");
    }
    execute(database_, "COMMIT");
    return result;
  } catch (...) {
    rollback(database_);
    throw;
  }
}

void NativeSqliteLedger::renew_lease(const std::string& worker,
                                     const std::uint64_t ordinal,
                                     const std::uint64_t lease_seconds) {
  Statement statement(
      database_,
      "UPDATE leases SET expires=? WHERE worker=? AND ordinal=? AND expires>?");
  const auto now = unix_time();
  check(sqlite3_bind_double(statement.get(), 1, now + lease_seconds), database_,
        "bind renewed native lease deadline");
  bind_text(database_, statement.get(), 2, worker);
  bind_integer(database_, statement.get(), 3, ordinal);
  check(sqlite3_bind_double(statement.get(), 4, now), database_,
        "bind native lease validation time");
  check(sqlite3_step(statement.get()), database_, "renew native block lease");
  if (sqlite3_changes(database_) != 1) {
    throw std::runtime_error("cannot renew absent native block lease");
  }
}

NativeCertificateCommit NativeSqliteLedger::try_add_certificate(
    const std::string& worker, const std::uint64_t leased_ordinal,
    const NativeCertificateData& data,
    const std::vector<NativeVertexKey>& vertices) {
  execute(database_, "BEGIN IMMEDIATE");
  try {
    const auto result = add_certificate_in_transaction(
        worker, leased_ordinal, data, vertices);
    execute(database_, "COMMIT");
    return result;
  } catch (...) {
    rollback(database_);
    throw;
  }
}

std::vector<NativeCertificateCommit>
NativeSqliteLedger::try_add_certificates(
    const std::vector<NativeCertificateRequest>& requests) {
  if (requests.empty()) {
    throw std::invalid_argument("native certificate batch is empty");
  }
  execute(database_, "BEGIN IMMEDIATE");
  try {
    std::vector<NativeCertificateCommit> results;
    results.reserve(requests.size());
    for (const auto& request : requests) {
      results.push_back(add_certificate_in_transaction(
          request.worker, request.leased_ordinal, request.data,
          request.vertices));
    }
    execute(database_, "COMMIT");
    return results;
  } catch (...) {
    rollback(database_);
    throw;
  }
}

NativeCertificateCommit NativeSqliteLedger::add_certificate_in_transaction(
    const std::string& worker, const std::uint64_t leased_ordinal,
    const NativeCertificateData& data,
    const std::vector<NativeVertexKey>& vertices) {
  if (worker.empty() || vertices.empty()) {
    throw std::invalid_argument("native certificate has no vertices");
  }
  if ((data.status != "closed" && data.status != "overflow" &&
       data.status != "linked") ||
      (data.walk_status != "closed" && data.walk_status != "overflow" &&
       data.walk_status != "linked") ||
      data.discovered_classes < vertices.size()) {
    throw std::invalid_argument("invalid native certificate accounting");
  }
  {
    Statement lease(database_,
                    "SELECT 1 FROM leases WHERE worker=? AND ordinal=? "
                    "AND expires>?");
    bind_text(database_, lease.get(), 1, worker);
    bind_integer(database_, lease.get(), 2, leased_ordinal);
    check(sqlite3_bind_double(lease.get(), 3, unix_time()), database_,
          "bind native certificate lease time");
    const auto lease_status = sqlite3_step(lease.get());
    if (lease_status != SQLITE_ROW) {
      check(lease_status, database_, "validate native certificate lease");
      throw std::runtime_error(
          "native certificate worker lacks an active block lease");
    }
  }
  Statement conflict(
      database_,
      "SELECT certificate FROM vertices WHERE ordinal=? AND twist=?");
  for (const auto& vertex : vertices) {
    sqlite3_reset(conflict.get());
    sqlite3_clear_bindings(conflict.get());
    bind_integer(database_, conflict.get(), 1, vertex.ordinal);
    bind_integer(database_, conflict.get(), 2, vertex.twist);
    const auto status = sqlite3_step(conflict.get());
    if (status == SQLITE_ROW) {
      return {false, column_u64(conflict.get(), 0)};
    }
    check(status, database_, "recheck native certificate overlap");
  }
  Statement certificate(
      database_,
      "INSERT INTO certificates(status,walk_status,linked_certificate,"
      "seed_ordinal,seed_twist,checked_vertices,discovered_vertices,"
      "discovered_classes) VALUES(?,?,?,?,?,?,?,?)");
  bind_text(database_, certificate.get(), 1, data.status);
  bind_text(database_, certificate.get(), 2, data.walk_status);
  if (data.linked_certificate.has_value()) {
    bind_integer(database_, certificate.get(), 3, *data.linked_certificate);
  } else {
    check(sqlite3_bind_null(certificate.get(), 3), database_,
          "bind native linked certificate");
  }
  bind_integer(database_, certificate.get(), 4, data.seed.ordinal);
  bind_integer(database_, certificate.get(), 5, data.seed.twist);
  bind_integer(database_, certificate.get(), 6, data.checked_vertices);
  bind_integer(database_, certificate.get(), 7, vertices.size());
  bind_integer(database_, certificate.get(), 8, data.discovered_classes);
  check(sqlite3_step(certificate.get()), database_,
        "insert native certificate");
  const auto certificate_id =
      static_cast<std::uint64_t>(sqlite3_last_insert_rowid(database_));

  Statement owner(database_,
                  "INSERT INTO vertices(ordinal,twist,certificate) "
                  "VALUES(?,?,?)");
  Statement ordered(
      database_,
      "INSERT INTO certificate_vertices(certificate,position,ordinal,twist) "
      "VALUES(?,?,?,?)");
  Statement frontier(
      database_,
      "INSERT OR IGNORE INTO frontier(ordinal) SELECT ? WHERE NOT EXISTS "
      "(SELECT 1 FROM blocks WHERE ordinal=?)");
  std::uint64_t position = 0;
  for (const auto& vertex : vertices) {
    sqlite3_reset(owner.get());
    sqlite3_clear_bindings(owner.get());
    bind_integer(database_, owner.get(), 1, vertex.ordinal);
    bind_integer(database_, owner.get(), 2, vertex.twist);
    bind_integer(database_, owner.get(), 3, certificate_id);
    check(sqlite3_step(owner.get()), database_, "insert native vertex owner");

    sqlite3_reset(ordered.get());
    sqlite3_clear_bindings(ordered.get());
    bind_integer(database_, ordered.get(), 1, certificate_id);
    bind_integer(database_, ordered.get(), 2, ++position);
    bind_integer(database_, ordered.get(), 3, vertex.ordinal);
    bind_integer(database_, ordered.get(), 4, vertex.twist);
    check(sqlite3_step(ordered.get()), database_,
          "insert ordered native certificate vertex");

    sqlite3_reset(frontier.get());
    sqlite3_clear_bindings(frontier.get());
    bind_integer(database_, frontier.get(), 1, vertex.ordinal);
    bind_integer(database_, frontier.get(), 2, vertex.ordinal);
    check(sqlite3_step(frontier.get()), database_,
          "insert native certificate frontier");
  }
  return {true, certificate_id};
}

void NativeSqliteLedger::finish_block(const std::string& worker,
                                      const NativeClaimedBlock& block,
                                      const std::uint64_t refined,
                                      const std::uint64_t generating) {
  execute(database_, "BEGIN IMMEDIATE");
  try {
    Statement lease(
        database_,
        "SELECT source,shard_index,shard_count FROM leases WHERE worker=? "
        "AND ordinal=? AND expires>?");
    bind_text(database_, lease.get(), 1, worker);
    bind_integer(database_, lease.get(), 2, block.ordinal);
    check(sqlite3_bind_double(lease.get(), 3, unix_time()), database_,
          "bind native finish lease time");
    const auto lease_status = sqlite3_step(lease.get());
    if (lease_status != SQLITE_ROW) {
      check(lease_status, database_, "validate finished native lease");
      throw std::runtime_error("finished native block lacks an active lease");
    }
    const std::string source = reinterpret_cast<const char*>(
        sqlite3_column_text(lease.get(), 0));
    if (source != block.source) {
      throw std::runtime_error("finished native block changed source");
    }
    const auto shard_index = column_u64(lease.get(), 1);
    const auto shard_count = column_u64(lease.get(), 2);
    Statement count(database_,
                    "SELECT COUNT(*) FROM certificates WHERE seed_ordinal=?");
    bind_integer(database_, count.get(), 1, block.ordinal);
    check(sqlite3_step(count.get()), database_,
          "count native block certificates");
    const auto new_certificates = column_u64(count.get(), 0);
    if (new_certificates > generating) {
      throw std::runtime_error(
          "native block has more certificates than generating seeds");
    }
    Statement insert(
        database_,
        "INSERT INTO blocks(ordinal,source,refined_vertices,"
        "generating_vertices,new_certificates,ledger_hits,worker,shard_index,"
        "shard_count) VALUES(?,?,?,?,?,?,?,?,?)");
    bind_integer(database_, insert.get(), 1, block.ordinal);
    bind_text(database_, insert.get(), 2, block.source);
    bind_integer(database_, insert.get(), 3, refined);
    bind_integer(database_, insert.get(), 4, generating);
    bind_integer(database_, insert.get(), 5, new_certificates);
    bind_integer(database_, insert.get(), 6, generating - new_certificates);
    bind_text(database_, insert.get(), 7, worker);
    bind_integer(database_, insert.get(), 8, shard_index);
    bind_integer(database_, insert.get(), 9, shard_count);
    check(sqlite3_step(insert.get()), database_, "finish native block");
    Statement frontier(database_, "DELETE FROM frontier WHERE ordinal=?");
    bind_integer(database_, frontier.get(), 1, block.ordinal);
    check(sqlite3_step(frontier.get()), database_,
          "remove finished native frontier");
    Statement clear(database_, "DELETE FROM leases WHERE worker=?");
    bind_text(database_, clear.get(), 1, worker);
    check(sqlite3_step(clear.get()), database_, "clear finished native lease");
    execute(database_, "COMMIT");
  } catch (...) {
    rollback(database_);
    throw;
  }
}

NativeLedgerStats NativeSqliteLedger::stats() const {
  Statement statement(
      database_,
      "SELECT (SELECT COUNT(*) FROM blocks),"
      "(SELECT COUNT(*) FROM certificates),"
      "(SELECT COUNT(*) FROM vertices),"
      "(SELECT COUNT(*) FROM leases)");
  check(sqlite3_step(statement.get()), database_, "read native ledger stats");
  return {column_u64(statement.get(), 0), column_u64(statement.get(), 1),
          column_u64(statement.get(), 2), column_u64(statement.get(), 3)};
}

}  // namespace m23
