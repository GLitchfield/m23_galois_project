#pragma once

#include "m23_native_sqlite.hpp"

#include <cstdint>
#include <string>
#include <vector>

struct sqlite3;
struct sqlite3_stmt;

namespace m23 {

struct NativeReplayConfig {
  std::uint32_t target_order{};
  std::uint64_t macroblock_count{};
  std::uint64_t proof_limit{};
  std::uint64_t walk_limit{};
  std::string source_checkpoint_sha256;
};

struct NativeReplayCertificate {
  std::uint64_t id{};
  NativeCertificateData data;
  std::vector<NativeVertexKey> vertices;
};

class NativeReplayLedger {
 public:
  explicit NativeReplayLedger(const std::string& path);
  ~NativeReplayLedger();
  NativeReplayLedger(const NativeReplayLedger&) = delete;
  NativeReplayLedger& operator=(const NativeReplayLedger&) = delete;

  [[nodiscard]] const NativeReplayConfig& config() const { return config_; }
  [[nodiscard]] std::uint64_t certificate_count() const;
  [[nodiscard]] NativeReplayCertificate certificate(std::uint64_t id);
  [[nodiscard]] std::optional<std::uint64_t> lookup_before(
      const NativeVertexKey& vertex, std::uint64_t certificate);

 private:
  sqlite3* database_{};
  sqlite3_stmt* certificate_statement_{};
  sqlite3_stmt* vertices_statement_{};
  sqlite3_stmt* lookup_statement_{};
  NativeReplayConfig config_;
};

}  // namespace m23
