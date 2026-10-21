#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <optional>
#include <span>
#include <string>
#include <unordered_map>
#include <vector>

namespace m23 {

inline constexpr std::size_t degree = 23;

// Images are zero-based internally. Composition follows GAP's right-action
// convention: point^(left*right) = (point^left)^right.
struct Permutation {
  std::array<std::uint8_t, degree> image{};

  [[nodiscard]] static Permutation identity();
  [[nodiscard]] bool valid() const;
  friend bool operator==(const Permutation&, const Permutation&) = default;
};
static_assert(sizeof(Permutation) == degree);

using Tuple4 = std::array<Permutation, 4>;
using Pair2 = std::array<Permutation, 2>;

struct PermutationHash {
  [[nodiscard]] std::size_t operator()(
      const Permutation& permutation) const noexcept;
};

struct Pair2Hash {
  [[nodiscard]] std::size_t operator()(const Pair2& pair) const noexcept;
};

struct Tuple4Hash {
  [[nodiscard]] std::size_t operator()(const Tuple4& tuple) const noexcept;
};

struct PairTwistVertex {
  std::uint64_t block_ordinal{};
  std::uint32_t twist_id{};
  std::uint32_t weight{};

  friend bool operator==(const PairTwistVertex&, const PairTwistVertex&) =
      default;
};

struct ExactCoordinateEntry {
  Tuple4 tuple;
  PairTwistVertex vertex;
};

// A deliberately small exact index used at the GAP/C++ differential-testing
// boundary.  The production checkpoint will replace these enumerated tuple
// keys with compressed pair and relative-double-coset tables.
class ExactCoordinateIndex {
 public:
  explicit ExactCoordinateIndex(std::span<const ExactCoordinateEntry> entries);

  [[nodiscard]] const PairTwistVertex* locate(const Tuple4& tuple) const;

 private:
  std::unordered_map<Tuple4, PairTwistVertex, Tuple4Hash> entries_;
};

struct TargetPairData {
  std::uint32_t class_index{};
  std::uint32_t pair_id{};
  Permutation normalizer;
  Pair2 normalized_pair;
};

struct TargetPairEntry {
  Permutation fixed_second;
  TargetPairData data;
};

struct ClassPairKey {
  std::uint32_t class_index{};
  Pair2 pair;
  friend bool operator==(const ClassPairKey&, const ClassPairKey&) = default;
};

struct ClassPairKeyHash {
  [[nodiscard]] std::size_t operator()(const ClassPairKey& key) const noexcept;
};

struct RightPairData {
  std::uint32_t pair_id{};
  Permutation relative_transporter;
};

struct RightPairEntry {
  ClassPairKey key;
  RightPairData data;
};

struct MacroblockSegmentEntry {
  std::uint32_t class_index{};
  std::uint64_t first_ordinal{};
  std::uint32_t right_pair_count{};
};

struct BlockPermutationKey {
  std::uint64_t block_ordinal{};
  Permutation permutation;
  friend bool operator==(const BlockPermutationKey&,
                         const BlockPermutationKey&) = default;
};

struct BlockPermutationKeyHash {
  [[nodiscard]] std::size_t operator()(
      const BlockPermutationKey& key) const noexcept;
};

struct RelativeEntry {
  BlockPermutationKey key;
  std::uint32_t relative_index{};
};

struct BlockRelativeKey {
  std::uint64_t block_ordinal{};
  std::uint32_t relative_index{};
  friend bool operator==(const BlockRelativeKey&, const BlockRelativeKey&) =
      default;
};

struct BlockRelativeKeyHash {
  [[nodiscard]] std::size_t operator()(
      const BlockRelativeKey& key) const noexcept;
};

struct RefinementEntry {
  BlockRelativeKey key;
  std::uint32_t twist_id{};
  std::uint32_t weight{};
};

struct CoordinateCheckpoint {
  std::uint32_t target_order{};
  std::uint64_t target_class_size{};
  std::string source_checkpoint_sha256;
  std::string source_git_revision;
  std::string gap_version;
  Permutation target;
  std::vector<TargetPairEntry> target_pairs;
  std::vector<RightPairEntry> right_pairs;
  std::vector<MacroblockSegmentEntry> segments;
  std::vector<RelativeEntry> relatives;
  std::vector<RefinementEntry> refinements;
};

struct GenerationMaskCheckpoint {
  std::uint32_t mask_bits{};
  std::uint64_t target_class_size{};
  std::uint64_t target_row_fingerprint{};
  std::string source_checkpoint_sha256;
  std::string source_git_revision;
  std::string gap_version;
  Permutation target;
  std::vector<std::uint16_t> masks;
};

struct BlockCoordinateTables {
  std::vector<RelativeEntry> relatives;
  std::vector<RefinementEntry> refinements;
};

struct PairTwistOrbitData {
  PairTwistVertex vertex;
  Permutation first_transporter;
  std::vector<Tuple4> tuples;
};

enum class BoundedWalkStatus { closed, overflow, linked };

struct BoundedWalkResult {
  BoundedWalkStatus status{};
  std::uint64_t limit{};
  std::uint64_t checked_vertex_count{};
  std::uint64_t discovered_class_count{};
  std::optional<std::uint64_t> linked_certificate;
  std::vector<PairTwistVertex> vertices;
};

// Versioned little-endian checkpoint. Global target/right-pair tables can be
// populated once, while relative/refinement rows may be empty and supplied by
// a later lazy per-block cache.
void write_coordinate_checkpoint(const std::string& path,
                                 const CoordinateCheckpoint& checkpoint);
[[nodiscard]] CoordinateCheckpoint read_coordinate_checkpoint(
    const std::string& path);
[[nodiscard]] GenerationMaskCheckpoint read_generation_mask_checkpoint(
    const std::string& path);

class FixedTargetGenerationMasks {
 public:
  FixedTargetGenerationMasks(
      const GenerationMaskCheckpoint& checkpoint,
      std::span<const TargetPairEntry> target_pairs);

  [[nodiscard]] std::uint16_t mask(const Permutation& element) const;
  [[nodiscard]] bool generates(const Tuple4& tuple,
                               const Permutation& first_transporter) const;

 private:
  Permutation target_;
  std::uint16_t full_mask_{};
  std::unordered_map<Permutation, std::uint16_t, PermutationHash> masks_;
};

// The table shape mirrors M23DirectRelativeCoordinateWithFirstTransport in
// GAP.  The differential fixture contains only rows reached from its selected
// source vertex; the production binary checkpoint will contain complete rows.
class CompressedCoordinateIndex {
 public:
  CompressedCoordinateIndex(
      Permutation target, std::span<const TargetPairEntry> target_pairs,
      std::span<const RightPairEntry> right_pairs,
      std::span<const MacroblockSegmentEntry> segments,
      std::span<const RelativeEntry> relatives,
      std::span<const RefinementEntry> refinements);

  [[nodiscard]] std::optional<PairTwistVertex> locate(
      const Tuple4& tuple, const Permutation& first_transporter) const;
  // Reconstruct the key-v2 relative double-coset partition for one
  // non-identity macroblock from the global pair tables.  The returned rows
  // can be inserted with add_relative_entries and discarded after the block
  // refinement has been consumed.
  [[nodiscard]] std::vector<RelativeEntry> build_relative_entries(
      std::uint64_t block_ordinal) const;
  // Canonical native refinement: beta12 orbits are numbered by increasing
  // least relative index. This is deterministic across GAP/C++ representative
  // choices; callers must treat it as a new durable coordinate convention.
  [[nodiscard]] std::vector<RefinementEntry> build_refinement_entries(
      std::uint64_t block_ordinal) const;
  [[nodiscard]] BlockCoordinateTables build_block_tables(
      std::uint64_t block_ordinal) const;
  // Populate the disposable relative/refinement indexes for one block if this
  // native index has not already built it. The identity-product block retains
  // GAP's separate canonical-inner-tuple path and is deliberately rejected.
  void ensure_block(std::uint64_t block_ordinal);
  [[nodiscard]] PairTwistOrbitData materialize_vertex(
      const PairTwistVertex& vertex);
  // Enumerate one block's stable native pair-twist coordinates in twist-ID
  // order. This is the block/refinement seam used by native ledger workers.
  [[nodiscard]] std::vector<PairTwistVertex> block_vertices(
      std::uint64_t block_ordinal);
  // Drop every lazily constructed nonidentity block table. Stable native
  // vertex IDs and durable ownership remain valid; later access rebuilds the
  // exact same table from the global checkpoint.
  void clear_disposable_block_cache();
  [[nodiscard]] std::optional<PairTwistVertex> locate_or_build(
      const Tuple4& tuple, const Permutation& first_transporter);
  void add_relative_entries(std::span<const RelativeEntry> relatives);
  void add_refinement_entries(std::span<const RefinementEntry> refinements);

 private:
  Permutation target_;
  std::unordered_map<Permutation, TargetPairData, PermutationHash>
      target_pairs_;
  std::unordered_map<ClassPairKey, RightPairData, ClassPairKeyHash>
      right_pairs_;
  std::unordered_map<std::uint32_t, MacroblockSegmentEntry> segments_;
  std::vector<MacroblockSegmentEntry> ordered_segments_;
  std::unordered_map<std::uint64_t, Pair2> normalized_pairs_by_id_;
  std::unordered_map<std::uint64_t, Permutation> pair_first_transports_by_id_;
  std::unordered_map<std::uint64_t, Pair2> right_pair_bases_by_id_;
  std::uint32_t identity_class_index_{};
  std::uint64_t identity_block_ordinal_{};
  std::unordered_map<std::uint64_t, std::uint32_t> identity_twist_ids_;
  std::vector<Permutation> identity_fixed_seconds_;
  std::unordered_map<std::uint32_t, std::uint32_t> left_pair_counts_;
  std::unordered_map<std::uint32_t, std::vector<Permutation>> centralizers_;
  std::unordered_map<BlockPermutationKey, std::uint32_t,
                     BlockPermutationKeyHash>
      relatives_;
  std::unordered_map<BlockRelativeKey, PairTwistVertex,
                     BlockRelativeKeyHash>
      refinements_;
  std::unordered_map<std::uint64_t, BlockCoordinateTables> block_tables_;

  [[nodiscard]] std::optional<BlockPermutationKey> locate_relative_key(
      const Tuple4& tuple, const Permutation& first_transporter) const;
  [[nodiscard]] std::optional<PairTwistVertex> locate_identity_vertex(
      const Permutation& fixed_third) const;
  [[nodiscard]] std::vector<RefinementEntry> build_refinement_entries(
      std::uint64_t block_ordinal,
      std::span<const RelativeEntry> relative_rows) const;
};

[[nodiscard]] Permutation compose(const Permutation& left,
                                  const Permutation& right);
[[nodiscard]] Permutation inverse(const Permutation& permutation);
[[nodiscard]] std::uint32_t order(const Permutation& permutation);
[[nodiscard]] Permutation conjugate(const Permutation& value,
                                    const Permutation& by);
[[nodiscard]] Tuple4 simultaneous_conjugate(const Tuple4& tuple,
                                            const Permutation& by);
[[nodiscard]] Permutation product(const Tuple4& tuple);
[[nodiscard]] Tuple4 hurwitz_move(const Tuple4& tuple, int gap_index);
[[nodiscard]] Tuple4 inverse_hurwitz_move(const Tuple4& tuple, int gap_index);
[[nodiscard]] Tuple4 pure_braid_move(const Tuple4& tuple, int generator);
[[nodiscard]] std::vector<PairTwistVertex> pair_twist_neighbors(
    std::span<const Tuple4> source_orbit,
    const ExactCoordinateIndex& coordinates);
[[nodiscard]] std::vector<PairTwistVertex> pair_twist_neighbors(
    std::span<const Tuple4> source_orbit,
    const Permutation& first_transporter,
    const CompressedCoordinateIndex& coordinates);
[[nodiscard]] std::vector<PairTwistVertex> pair_twist_neighbors(
    const PairTwistVertex& source, CompressedCoordinateIndex& coordinates);
[[nodiscard]] BoundedWalkResult bounded_pair_twist_walk(
    CompressedCoordinateIndex& coordinates, const PairTwistVertex& seed,
    std::uint64_t limit);
using OwnershipLookup = std::function<std::optional<std::uint64_t>(
    const PairTwistVertex&)>;
[[nodiscard]] BoundedWalkResult bounded_pair_twist_walk_with_lookup(
    CompressedCoordinateIndex& coordinates, const PairTwistVertex& seed,
    std::uint64_t limit, const OwnershipLookup& lookup);

}  // namespace m23
