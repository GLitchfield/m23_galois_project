#include "m23_native_replay.hpp"

#include <sqlite3.h>

#include <limits>
#include <optional>
#include <stdexcept>
#include <string>

namespace m23 {
namespace {

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
    throw std::runtime_error("execute replay SQLite statement: " + detail);
  }
}

void bind_integer(sqlite3* database, sqlite3_stmt* statement, const int index,
                  const std::uint64_t value) {
  if (value > static_cast<std::uint64_t>(
                  std::numeric_limits<sqlite3_int64>::max())) {
    throw std::runtime_error("replay SQLite integer exceeds signed range");
  }
  check(sqlite3_bind_int64(statement, index,
                           static_cast<sqlite3_int64>(value)),
        database, "bind replay SQLite integer");
}

std::uint64_t column_u64(sqlite3_stmt* statement, const int column) {
  const auto value = sqlite3_column_int64(statement, column);
  if (value < 0) {
    throw std::runtime_error("replay SQLite row contains a negative integer");
  }
  return static_cast<std::uint64_t>(value);
}

std::string column_text(sqlite3_stmt* statement, const int column) {
  const auto* value = sqlite3_column_text(statement, column);
  if (!value) {
    throw std::runtime_error("replay SQLite row contains unexpected NULL");
  }
  return reinterpret_cast<const char*>(value);
}

std::string metadata(sqlite3* database, const std::string& key) {
  sqlite3_stmt* statement = nullptr;
  check(sqlite3_prepare_v2(database,
                           "SELECT value FROM meta WHERE key=?", -1,
                           &statement, nullptr),
        database, "prepare replay metadata read");
  try {
    check(sqlite3_bind_text(statement, 1, key.c_str(),
                            static_cast<int>(key.size()), SQLITE_TRANSIENT),
          database, "bind replay metadata key");
    const auto status = sqlite3_step(statement);
    if (status != SQLITE_ROW) {
      check(status, database, "read replay metadata");
      throw std::runtime_error("native replay metadata is missing " + key);
    }
    const auto result = column_text(statement, 0);
    sqlite3_finalize(statement);
    return result;
  } catch (...) {
    sqlite3_finalize(statement);
    throw;
  }
}

std::uint64_t metadata_u64(sqlite3* database, const std::string& key) {
  const auto value = metadata(database, key);
  std::size_t consumed = 0;
  const auto result = std::stoull(value, &consumed);
  if (consumed != value.size()) {
    throw std::runtime_error("native replay metadata is not an integer: " +
                             key);
  }
  return result;
}

}  // namespace

NativeReplayLedger::NativeReplayLedger(const std::string& path) {
  const auto status = sqlite3_open_v2(path.c_str(), &database_,
                                      SQLITE_OPEN_READONLY, nullptr);
  if (status != SQLITE_OK) {
    const std::string detail = database_ ? sqlite3_errmsg(database_)
                                         : sqlite3_errstr(status);
    if (database_) {
      sqlite3_close(database_);
      database_ = nullptr;
    }
    throw std::runtime_error("open native replay ledger: " + detail);
  }
  try {
    check(sqlite3_busy_timeout(database_, 300000), database_,
          "set replay SQLite busy timeout");
    execute(database_, "PRAGMA foreign_keys=ON");
    if (metadata(database_, "schema_version") != "1" ||
        metadata(database_, "config_pair_schema") != "2" ||
        metadata(database_, "config_traversal_order") != "native-v1" ||
        metadata(database_, "native_coordinate_convention") != "native-v1") {
      throw std::runtime_error("unsupported native replay ledger schema");
    }
    const auto target_order = metadata_u64(database_, "config_target_order");
    if (target_order > std::numeric_limits<std::uint32_t>::max()) {
      throw std::runtime_error("native replay target order exceeds range");
    }
    config_ = {
        static_cast<std::uint32_t>(target_order),
        metadata_u64(database_, "config_macroblock_count"),
        metadata_u64(database_, "config_proof_limit"),
        metadata_u64(database_, "config_walk_limit"),
        metadata(database_, "native_source_checkpoint_sha256"),
    };
    if (config_.macroblock_count == 0 || config_.proof_limit == 0 ||
        config_.walk_limit < config_.proof_limit ||
        config_.source_checkpoint_sha256.empty()) {
      throw std::runtime_error("invalid native replay configuration");
    }
    check(sqlite3_prepare_v2(
              database_,
              "SELECT status,walk_status,linked_certificate,seed_ordinal,"
              "seed_twist,checked_vertices,discovered_vertices,"
              "discovered_classes FROM certificates WHERE id=?",
              -1, &certificate_statement_, nullptr),
          database_, "prepare replay certificate read");
    check(sqlite3_prepare_v2(
              database_,
              "SELECT ordinal,twist FROM certificate_vertices "
              "WHERE certificate=? ORDER BY position",
              -1, &vertices_statement_, nullptr),
          database_, "prepare replay certificate vertices");
    check(sqlite3_prepare_v2(
              database_,
              "SELECT certificate FROM vertices WHERE ordinal=? AND twist=? "
              "AND certificate<?",
              -1, &lookup_statement_, nullptr),
          database_, "prepare replay prefix lookup");
  } catch (...) {
    sqlite3_finalize(certificate_statement_);
    sqlite3_finalize(vertices_statement_);
    sqlite3_finalize(lookup_statement_);
    sqlite3_close(database_);
    database_ = nullptr;
    throw;
  }
}

NativeReplayLedger::~NativeReplayLedger() {
  if (database_) {
    sqlite3_finalize(certificate_statement_);
    sqlite3_finalize(vertices_statement_);
    sqlite3_finalize(lookup_statement_);
    sqlite3_close(database_);
  }
}

std::uint64_t NativeReplayLedger::certificate_count() const {
  sqlite3_stmt* statement = nullptr;
  check(sqlite3_prepare_v2(database_, "SELECT COUNT(*) FROM certificates", -1,
                           &statement, nullptr),
        database_, "prepare replay certificate count");
  try {
    const auto status = sqlite3_step(statement);
    if (status != SQLITE_ROW) {
      check(status, database_, "read replay certificate count");
      throw std::runtime_error("native replay certificate count is absent");
    }
    const auto result = column_u64(statement, 0);
    sqlite3_finalize(statement);
    return result;
  } catch (...) {
    sqlite3_finalize(statement);
    throw;
  }
}

NativeReplayCertificate NativeReplayLedger::certificate(
    const std::uint64_t id) {
  if (id == 0) {
    throw std::invalid_argument("native replay certificate ID is zero");
  }
  sqlite3_reset(certificate_statement_);
  sqlite3_clear_bindings(certificate_statement_);
  bind_integer(database_, certificate_statement_, 1, id);
  const auto status = sqlite3_step(certificate_statement_);
  if (status != SQLITE_ROW) {
    check(status, database_, "read replay certificate");
    throw std::runtime_error("native replay certificate is absent");
  }
  NativeReplayCertificate result;
  result.id = id;
  result.data.status = column_text(certificate_statement_, 0);
  result.data.walk_status = column_text(certificate_statement_, 1);
  if (sqlite3_column_type(certificate_statement_, 2) != SQLITE_NULL) {
    result.data.linked_certificate = column_u64(certificate_statement_, 2);
  }
  const auto seed_twist = column_u64(certificate_statement_, 4);
  if (seed_twist > std::numeric_limits<std::uint32_t>::max()) {
    throw std::runtime_error("native replay seed twist exceeds range");
  }
  result.data.seed = {column_u64(certificate_statement_, 3),
                      static_cast<std::uint32_t>(seed_twist)};
  result.data.checked_vertices = column_u64(certificate_statement_, 5);
  const auto discovered_vertices = column_u64(certificate_statement_, 6);
  result.data.discovered_classes = column_u64(certificate_statement_, 7);
  sqlite3_reset(certificate_statement_);

  sqlite3_reset(vertices_statement_);
  sqlite3_clear_bindings(vertices_statement_);
  bind_integer(database_, vertices_statement_, 1, id);
  while (true) {
    const auto vertex_status = sqlite3_step(vertices_statement_);
    if (vertex_status == SQLITE_DONE) {
      break;
    }
    check(vertex_status, database_, "read replay certificate vertex");
    const auto twist = column_u64(vertices_statement_, 1);
    if (twist > std::numeric_limits<std::uint32_t>::max()) {
      throw std::runtime_error("native replay twist exceeds range");
    }
    result.vertices.push_back(
        {column_u64(vertices_statement_, 0),
         static_cast<std::uint32_t>(twist)});
  }
  sqlite3_reset(vertices_statement_);
  const bool valid_status =
      result.data.status == "closed" || result.data.status == "overflow" ||
      result.data.status == "linked";
  const bool valid_walk_status =
      result.data.walk_status == "closed" ||
      result.data.walk_status == "overflow" ||
      result.data.walk_status == "linked";
  const bool valid_link = result.data.status == "linked"
                              ? result.data.linked_certificate.has_value() &&
                                    *result.data.linked_certificate < id
                              : !result.data.linked_certificate.has_value();
  if (!valid_status || !valid_walk_status || !valid_link ||
      result.vertices.empty() || result.vertices.size() != discovered_vertices ||
      result.vertices.front() != result.data.seed ||
      result.data.discovered_classes < result.vertices.size()) {
    throw std::runtime_error("native replay certificate vertices are invalid");
  }
  return result;
}

std::optional<std::uint64_t> NativeReplayLedger::lookup_before(
    const NativeVertexKey& vertex, const std::uint64_t certificate) {
  if (certificate == 0) {
    return std::nullopt;
  }
  sqlite3_reset(lookup_statement_);
  sqlite3_clear_bindings(lookup_statement_);
  bind_integer(database_, lookup_statement_, 1, vertex.ordinal);
  bind_integer(database_, lookup_statement_, 2, vertex.twist);
  bind_integer(database_, lookup_statement_, 3, certificate);
  const auto status = sqlite3_step(lookup_statement_);
  if (status == SQLITE_DONE) {
    sqlite3_reset(lookup_statement_);
    return std::nullopt;
  }
  check(status, database_, "lookup replay prefix ownership");
  const auto result = column_u64(lookup_statement_, 0);
  sqlite3_reset(lookup_statement_);
  return result;
}

}  // namespace m23
