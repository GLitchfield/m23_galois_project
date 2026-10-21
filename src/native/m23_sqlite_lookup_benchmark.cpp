#include <sqlite3.h>

#include <chrono>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {

using Clock = std::chrono::steady_clock;

void check(const int status, sqlite3* database, const char* operation) {
  if (status != SQLITE_OK) {
    throw std::runtime_error(std::string(operation) + ": " +
                             (database ? sqlite3_errmsg(database)
                                       : sqlite3_errstr(status)));
  }
}

std::vector<std::pair<std::int64_t, std::int64_t>> read_vertices(
    const std::string& path) {
  std::ifstream input(path);
  if (!input) {
    throw std::runtime_error("cannot open native transcript");
  }
  std::vector<std::pair<std::int64_t, std::int64_t>> result;
  std::string line;
  while (std::getline(input, line)) {
    if (line.rfind("V\t", 0) != 0) {
      continue;
    }
    std::istringstream fields(line);
    std::string field;
    std::vector<std::string> values;
    while (std::getline(fields, field, '\t')) {
      values.push_back(field);
    }
    if (values.size() != 5) {
      throw std::runtime_error("invalid native vertex row");
    }
    result.emplace_back(std::stoll(values[3]), std::stoll(values[4]));
  }
  if (result.empty()) {
    throw std::runtime_error("native transcript contains no vertices");
  }
  return result;
}

double seconds(const Clock::time_point start, const Clock::time_point finish) {
  return std::chrono::duration<double>(finish - start).count();
}

std::pair<double, std::uint64_t> lookup_pass(
    sqlite3* database, sqlite3_stmt* statement,
    const std::vector<std::pair<std::int64_t, std::int64_t>>& vertices,
    const bool misses) {
  std::uint64_t hits = 0;
  const auto started = Clock::now();
  for (const auto& [ordinal, twist] : vertices) {
    sqlite3_reset(statement);
    sqlite3_clear_bindings(statement);
    check(sqlite3_bind_int64(statement, 1, ordinal), database,
          "bind ownership ordinal");
    check(sqlite3_bind_int64(statement, 2,
                             misses ? twist + 1000000000 : twist),
          database, "bind ownership twist");
    const auto status = sqlite3_step(statement);
    if (status == SQLITE_ROW) {
      ++hits;
    } else if (status != SQLITE_DONE) {
      throw std::runtime_error(std::string("ownership lookup: ") +
                               sqlite3_errmsg(database));
    }
  }
  return {seconds(started, Clock::now()), hits};
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 3) {
      throw std::runtime_error(
          "usage: m23_sqlite_lookup_benchmark LEDGER.sqlite3 TRANSCRIPT.tsv");
    }
    const auto vertices = read_vertices(argv[2]);
    sqlite3* database = nullptr;
    check(sqlite3_open_v2(argv[1], &database, SQLITE_OPEN_READONLY, nullptr),
          database, "open SQLite ledger");
    sqlite3_stmt* statement = nullptr;
    check(sqlite3_prepare_v2(
              database,
              "SELECT certificate FROM vertices WHERE ordinal=? AND twist=?",
              -1, &statement, nullptr),
          database, "prepare ownership lookup");
    const auto cold = lookup_pass(database, statement, vertices, false);
    const auto warm = lookup_pass(database, statement, vertices, false);
    const auto miss = lookup_pass(database, statement, vertices, true);
    sqlite3_finalize(statement);
    sqlite3_close(database);
    if (cold.second != vertices.size() || warm.second != vertices.size() ||
        miss.second != 0) {
      throw std::runtime_error("SQLite ownership lookup counts disagree");
    }
    std::cout << std::fixed << std::setprecision(3)
              << "schema\tm23-native-sqlite-lookup-benchmark-v1\n"
              << "vertices\t" << vertices.size() << '\n'
              << "cold_hit_seconds\t" << cold.first << '\n'
              << "warm_hit_seconds\t" << warm.first << '\n'
              << "warm_miss_seconds\t" << miss.first << '\n'
              << "cold_hit_lookups_per_second\t"
              << vertices.size() / cold.first << '\n'
              << "warm_hit_lookups_per_second\t"
              << vertices.size() / warm.first << '\n'
              << "warm_miss_lookups_per_second\t"
              << vertices.size() / miss.first << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
