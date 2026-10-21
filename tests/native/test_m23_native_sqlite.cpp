#include "m23_native_sqlite.hpp"

#include <sqlite3.h>

#include <cstdio>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

void require(const bool condition, const std::string& message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

m23::NativeCertificateData certificate(
    const std::uint64_t seed_ordinal, const std::uint32_t seed_twist,
    const std::uint64_t discovered_classes) {
  return {"overflow", "overflow", std::nullopt,
          {seed_ordinal, seed_twist}, 1, discovered_classes};
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 2) {
      throw std::runtime_error("usage: test_m23_native_sqlite DATABASE");
    }
    const m23::NativeLedgerConfig config{
        5, 100, 10, 10, 20, "checkpoint-sha256", "revision", "4.12.1"};
    {
      m23::NativeSqliteLedger preparer(argv[1], config);
    }
    sqlite3* raw = nullptr;
    require(sqlite3_open(argv[1], &raw) == SQLITE_OK,
            "cannot open native planned-work ledger");
    require(sqlite3_exec(
                raw,
                "BEGIN;"
                "INSERT INTO frontier(ordinal) VALUES(11),(10);"
                "INSERT INTO planned_work(ordinal,shard_index,shard_count) "
                "VALUES(11,1,2),(10,2,2);"
                "INSERT INTO meta(key,value) VALUES"
                "('native_work_plan_schema','m23-native-stratified-plan-v1'),"
                "('native_work_plan_sha256','plan-sha256'),"
                "('native_work_plan_blocks','2'),"
                "('native_work_plan_shards','2');"
                "COMMIT;",
                nullptr, nullptr, nullptr) == SQLITE_OK,
            "cannot seed native planned-work ledger");
    sqlite3_close(raw);
    {
      m23::NativeSqliteLedger first(argv[1], config);
      m23::NativeSqliteLedger second(argv[1], config);
      const auto first_block = first.claim_block("first", 60, 2, 1, 2);
      const auto second_block = second.claim_block("second", 60, 2, 2, 2);
      require(first_block.has_value() && first_block->ordinal == 11,
              "first deterministic shard claimed the wrong block");
      require(second_block.has_value() && second_block->ordinal == 10,
              "second deterministic shard claimed the wrong block");
      const auto added = first.try_add_certificate(
          "first", first_block->ordinal,
          certificate(first_block->ordinal, 1, 2),
          {{first_block->ordinal, 1}, {50, 2}});
      require(added.added && added.certificate == 1,
              "first native certificate was not committed");
      const auto conflict = second.try_add_certificate(
          "second", second_block->ordinal,
          certificate(second_block->ordinal, 1, 2),
          {{second_block->ordinal, 1}, {50, 2}});
      require(!conflict.added && conflict.certificate == 1,
              "overlapping native certificate was not rejected atomically");
      const auto batch = first.try_add_certificates({
          {"first", first_block->ordinal,
           certificate(first_block->ordinal, 2, 2),
           {{first_block->ordinal, 2}, {60, 1}}},
          {"first", first_block->ordinal,
           certificate(first_block->ordinal, 3, 2),
           {{first_block->ordinal, 3}, {60, 1}}},
      });
      require(batch.size() == 2 && batch[0].added &&
                  batch[0].certificate == 2 && !batch[1].added &&
                  batch[1].certificate == 2,
              "native certificate batch did not resolve conflicts in order");
      first.finish_block("first", *first_block, 3, 3);
      require(!first.claim_block("first", 60, 3, 1, 2).has_value(),
              "planned shard escaped to discovered frontier before barrier");
      second.finish_block("second", *second_block, 1, 1);
      const auto stats = first.stats();
      require(stats.blocks == 2 && stats.certificates == 2 &&
                  stats.vertices == 4 && stats.leases == 0,
              "two-worker native ledger accounting is inconsistent");
    }

    {
      m23::NativeSqliteLedger crashed(argv[1], config);
      const auto block = crashed.claim_block("crashed", 60, 3, 2, 2);
      require(block.has_value() && block->ordinal == 50 &&
                  block->source == "frontier",
              "crash pilot did not prioritize the durable frontier");
      const auto added = crashed.try_add_certificate(
          "crashed", block->ordinal, certificate(block->ordinal, 3, 1),
          {{block->ordinal, 3}});
      require(added.added && added.certificate == 3,
              "pre-crash native certificate was not durable");
      // Deliberately close without finishing the block. The lease is the only
      // incomplete state that remains.
    }

    raw = nullptr;
    require(sqlite3_open(argv[1], &raw) == SQLITE_OK,
            "cannot open native crash-test ledger");
    require(sqlite3_exec(raw, "UPDATE leases SET expires=0", nullptr, nullptr,
                         nullptr) == SQLITE_OK,
            "cannot expire native crash-test lease");
    sqlite3_close(raw);

    {
      m23::NativeSqliteLedger replacement(argv[1], config);
      const auto block = replacement.claim_block(
          "replacement", 60, 3, 2, 2);
      require(block.has_value() && block->ordinal == 50,
              "replacement did not reclaim the expired native lease");
      require(replacement.lookup({50, 3}) == 3,
              "replacement cannot see the pre-crash durable certificate");
      replacement.finish_block("replacement", *block, 1, 1);
      const auto stats = replacement.stats();
      require(stats.blocks == 3 && stats.certificates == 3 &&
                  stats.vertices == 5 && stats.leases == 0,
              "native crash recovery accounting is inconsistent");
    }

    raw = nullptr;
    require(sqlite3_open(argv[1], &raw) == SQLITE_OK,
            "cannot reopen native test ledger");
    sqlite3_stmt* check = nullptr;
    require(sqlite3_prepare_v2(raw, "PRAGMA quick_check", -1, &check, nullptr) ==
                SQLITE_OK &&
                sqlite3_step(check) == SQLITE_ROW &&
                std::string(reinterpret_cast<const char*>(
                    sqlite3_column_text(check, 0))) == "ok",
            "native SQLite quick_check failed");
    sqlite3_finalize(check);
    require(sqlite3_prepare_v2(raw, "PRAGMA foreign_key_check", -1, &check,
                               nullptr) == SQLITE_OK &&
                sqlite3_step(check) == SQLITE_DONE,
            "native SQLite foreign-key check failed");
    sqlite3_finalize(check);
    sqlite3_close(raw);

    const std::string compact_path = std::string(argv[1]) + ".compact";
    std::remove(compact_path.c_str());
    {
      m23::NativeSqliteLedger preparer(compact_path, config);
    }
    require(sqlite3_open(compact_path.c_str(), &raw) == SQLITE_OK,
            "cannot open native full-cursor ledger");
    require(sqlite3_exec(
                raw,
                "BEGIN;"
                "INSERT INTO meta(key,value) VALUES"
                "('native_work_plan_schema',"
                "'m23-native-full-cursor-plan-v1'),"
                "('native_work_plan_sha256','cursor-plan-sha256'),"
                "('native_work_plan_blocks','100'),"
                "('native_work_plan_shards','2'),"
                "('native_work_plan_ownership','ordinal-modulo-v1');"
                "COMMIT;",
                nullptr, nullptr, nullptr) == SQLITE_OK,
            "cannot seed native full-cursor ledger");
    sqlite3_close(raw);
    {
      m23::NativeSqliteLedger first(compact_path, config);
      m23::NativeSqliteLedger second(compact_path, config);
      const auto first_block = first.claim_block("cursor-first", 60, 2, 1, 2);
      const auto second_block = second.claim_block("cursor-second", 60, 2, 2, 2);
      require(first_block.has_value() && first_block->ordinal == 11,
              "first compact cursor claimed the wrong ordinal");
      require(second_block.has_value() && second_block->ordinal == 10,
              "second compact cursor claimed the wrong ordinal");
      first.finish_block("cursor-first", *first_block, 0, 0);
      second.finish_block("cursor-second", *second_block, 0, 0);
    }
    bool rejected_shards = false;
    try {
      m23::NativeSqliteLedger ledger(compact_path, config);
      static_cast<void>(ledger.claim_block("wrong-shards", 60, 3, 1, 3));
    } catch (const std::runtime_error& error) {
      rejected_shards = std::string(error.what()).find("shard count") !=
                        std::string::npos;
    }
    require(rejected_shards,
            "compact cursor accepted a changed worker shard count");
    std::remove(compact_path.c_str());
    std::cout << "native transactional SQLite ledger verified\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
