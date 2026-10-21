#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

struct sqlite3;
struct sqlite3_stmt;

namespace m23 {

struct NativeLedgerConfig {
  std::uint32_t target_order{};
  std::uint64_t macroblock_count{};
  std::uint64_t start_ordinal{};
  std::uint64_t proof_limit{};
  std::uint64_t walk_limit{};
  std::string source_checkpoint_sha256;
  std::string source_git_revision;
  std::string gap_version;
};

struct NativeVertexKey {
  std::uint64_t ordinal{};
  std::uint32_t twist{};
  friend bool operator==(const NativeVertexKey&, const NativeVertexKey&) =
      default;
};

struct NativeClaimedBlock {
  std::uint64_t ordinal{};
  std::string source;
};

struct NativeCertificateData {
  std::string status;
  std::string walk_status;
  std::optional<std::uint64_t> linked_certificate;
  NativeVertexKey seed;
  std::uint64_t checked_vertices{};
  std::uint64_t discovered_classes{};
};

struct NativeCertificateCommit {
  bool added{};
  std::uint64_t certificate{};
};

struct NativeCertificateRequest {
  std::string worker;
  std::uint64_t leased_ordinal{};
  NativeCertificateData data;
  std::vector<NativeVertexKey> vertices;
};

struct NativeLedgerStats {
  std::uint64_t blocks{};
  std::uint64_t certificates{};
  std::uint64_t vertices{};
  std::uint64_t leases{};
};

class NativeSqliteLedger {
 public:
  NativeSqliteLedger(const std::string& path,
                     const NativeLedgerConfig& config);
  ~NativeSqliteLedger();
  NativeSqliteLedger(const NativeSqliteLedger&) = delete;
  NativeSqliteLedger& operator=(const NativeSqliteLedger&) = delete;

  [[nodiscard]] std::optional<std::uint64_t> lookup(
      const NativeVertexKey& vertex);
  [[nodiscard]] std::optional<NativeClaimedBlock> claim_block(
      const std::string& worker, std::uint64_t lease_seconds,
      std::uint64_t block_target, std::uint32_t shard_index,
      std::uint32_t shard_count);
  void renew_lease(const std::string& worker, std::uint64_t ordinal,
                   std::uint64_t lease_seconds);
  [[nodiscard]] NativeCertificateCommit try_add_certificate(
      const std::string& worker, std::uint64_t leased_ordinal,
      const NativeCertificateData& data,
      const std::vector<NativeVertexKey>& vertices);
  // Apply requests in input order inside one durable transaction. Conflicting
  // requests are rejected against both the committed prefix and earlier
  // accepted requests in this batch.
  [[nodiscard]] std::vector<NativeCertificateCommit> try_add_certificates(
      const std::vector<NativeCertificateRequest>& requests);
  void finish_block(const std::string& worker,
                    const NativeClaimedBlock& block, std::uint64_t refined,
                    std::uint64_t generating);
  [[nodiscard]] NativeLedgerStats stats() const;

 private:
  sqlite3* database_{};
  sqlite3_stmt* lookup_statement_{};
  NativeLedgerConfig config_;
  std::optional<std::uint32_t> planned_shard_count_;
  bool explicit_planned_work_{};

  void initialize();
  [[nodiscard]] std::optional<std::string> metadata(
      const std::string& key) const;
  void set_metadata(const std::string& key, const std::string& value);
  [[nodiscard]] NativeCertificateCommit add_certificate_in_transaction(
      const std::string& worker, std::uint64_t leased_ordinal,
      const NativeCertificateData& data,
      const std::vector<NativeVertexKey>& vertices);
};

}  // namespace m23
