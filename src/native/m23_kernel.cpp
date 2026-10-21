#include "m23_kernel.hpp"

#include <algorithm>
#include <array>
#include <fstream>
#include <limits>
#include <numeric>
#include <stdexcept>
#include <string_view>
#include <type_traits>
#include <unordered_set>

namespace m23 {

namespace {

constexpr std::uint64_t fnv_offset = 14695981039346656037ULL;
constexpr std::uint64_t fnv_prime = 1099511628211ULL;
constexpr std::array<char, 8> checkpoint_magic{'M', '2', '3', 'C',
                                                'O', 'O', 'R', 'D'};
constexpr std::array<char, 8> mask_checkpoint_magic{'M', '2', '3', '5',
                                                     'A', 'M', 'S', 'K'};
constexpr std::uint32_t checkpoint_schema = 1;
constexpr std::uint32_t endian_marker = 0x01020304U;
constexpr std::size_t sha_field_size = 64;
constexpr std::size_t revision_field_size = 40;
constexpr std::size_t gap_version_field_size = 16;
constexpr std::uint64_t checkpoint_header_bytes = 215;
constexpr std::uint64_t target_pair_bytes = 100;
constexpr std::uint64_t right_pair_bytes = 77;
constexpr std::uint64_t segment_bytes = 16;
constexpr std::uint64_t relative_bytes = 35;
constexpr std::uint64_t refinement_bytes = 20;
constexpr std::uint64_t mask_checkpoint_header_bytes = 175;

void hash_permutation(std::uint64_t& hash,
                      const Permutation& permutation) noexcept {
  for (const auto image_point : permutation.image) {
    hash ^= image_point;
    hash *= fnv_prime;
  }
}

std::size_t finish_hash(const std::uint64_t hash) noexcept {
  if constexpr (sizeof(std::size_t) < sizeof(hash)) {
    return static_cast<std::size_t>(hash ^ (hash >> 32U));
  }
  return static_cast<std::size_t>(hash);
}

void combine_integer(std::uint64_t& hash, std::uint64_t value) noexcept {
  for (std::size_t index = 0; index < sizeof(value); ++index) {
    hash ^= static_cast<std::uint8_t>(value & 0xffU);
    hash *= fnv_prime;
    value >>= 8U;
  }
}

template <typename Integer>
void write_little(std::ostream& output, Integer value) {
  static_assert(std::is_unsigned_v<Integer>);
  for (std::size_t index = 0; index < sizeof(Integer); ++index) {
    output.put(static_cast<char>(value & 0xffU));
    value >>= 8U;
  }
  if (!output) {
    throw std::runtime_error("failed to write coordinate checkpoint");
  }
}

template <typename Integer>
Integer read_little(std::istream& input) {
  static_assert(std::is_unsigned_v<Integer>);
  Integer result = 0;
  for (std::size_t index = 0; index < sizeof(Integer); ++index) {
    const auto byte = input.get();
    if (byte == std::char_traits<char>::eof()) {
      throw std::runtime_error("truncated coordinate checkpoint");
    }
    result |= static_cast<Integer>(static_cast<unsigned char>(byte))
              << (8U * index);
  }
  return result;
}

void write_permutation(std::ostream& output, const Permutation& permutation) {
  if (!permutation.valid()) {
    throw std::invalid_argument("checkpoint contains an invalid permutation");
  }
  output.write(reinterpret_cast<const char*>(permutation.image.data()), degree);
  if (!output) {
    throw std::runtime_error("failed to write checkpoint permutation");
  }
}

Permutation read_permutation(std::istream& input) {
  Permutation result;
  input.read(reinterpret_cast<char*>(result.image.data()), degree);
  if (!input || !result.valid()) {
    throw std::runtime_error("invalid or truncated checkpoint permutation");
  }
  return result;
}

void write_fixed_string(std::ostream& output, const std::string_view value,
                        const std::size_t width) {
  if (value.size() > width || value.find('\0') != std::string_view::npos) {
    throw std::invalid_argument("checkpoint provenance field is invalid");
  }
  output.write(value.data(), static_cast<std::streamsize>(value.size()));
  for (auto index = value.size(); index < width; ++index) {
    output.put('\0');
  }
}

std::string read_fixed_string(std::istream& input, const std::size_t width) {
  std::string value(width, '\0');
  input.read(value.data(), static_cast<std::streamsize>(width));
  if (!input) {
    throw std::runtime_error("truncated checkpoint provenance field");
  }
  const auto end = value.find('\0');
  if (end != std::string::npos) {
    value.resize(end);
  }
  return value;
}

std::uint64_t checked_size_term(const std::uint64_t count,
                                const std::uint64_t width) {
  if (count > std::numeric_limits<std::uint64_t>::max() / width) {
    throw std::runtime_error("coordinate checkpoint size overflows uint64");
  }
  return count * width;
}

std::uint64_t expected_checkpoint_size(
    const std::array<std::uint64_t, 5>& counts) {
  std::uint64_t result = checkpoint_header_bytes;
  const std::array<std::uint64_t, 5> widths{
      target_pair_bytes, right_pair_bytes, segment_bytes, relative_bytes,
      refinement_bytes};
  for (std::size_t index = 0; index < counts.size(); ++index) {
    const auto term = checked_size_term(counts[index], widths[index]);
    if (result > std::numeric_limits<std::uint64_t>::max() - term) {
      throw std::runtime_error("coordinate checkpoint size overflows uint64");
    }
    result += term;
  }
  return result;
}

std::uint64_t class_pair_id_key(const std::uint32_t class_index,
                                const std::uint32_t pair_id) {
  return (static_cast<std::uint64_t>(class_index) << 32U) | pair_id;
}

bool permutation_less(const Permutation& left, const Permutation& right) {
  return left.image < right.image;
}

bool fixes_pair(const Permutation& element, const Pair2& pair) {
  return conjugate(pair[0], element) == pair[0] &&
         conjugate(pair[1], element) == pair[1];
}

std::uint64_t append_row_fingerprint(
    std::uint64_t fingerprint, const Permutation& permutation) {
  for (const auto image_point : permutation.image) {
    fingerprint = fingerprint * fnv_prime +
                  static_cast<std::uint64_t>(image_point) + 1;
  }
  return fingerprint;
}

}  // namespace

void write_coordinate_checkpoint(const std::string& path,
                                 const CoordinateCheckpoint& checkpoint) {
  const std::array<std::uint64_t, 5> counts{
      checkpoint.target_pairs.size(), checkpoint.right_pairs.size(),
      checkpoint.segments.size(), checkpoint.relatives.size(),
      checkpoint.refinements.size()};
  static_cast<void>(expected_checkpoint_size(counts));
  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  if (!output) {
    throw std::runtime_error("cannot create coordinate checkpoint: " + path);
  }
  output.write(checkpoint_magic.data(), checkpoint_magic.size());
  write_little(output, checkpoint_schema);
  write_little(output, endian_marker);
  write_little(output, static_cast<std::uint32_t>(degree));
  write_little(output, checkpoint.target_order);
  write_little(output, checkpoint.target_class_size);
  for (const auto count : counts) {
    write_little(output, count);
  }
  write_permutation(output, checkpoint.target);
  write_fixed_string(output, checkpoint.source_checkpoint_sha256,
                     sha_field_size);
  write_fixed_string(output, checkpoint.source_git_revision,
                     revision_field_size);
  write_fixed_string(output, checkpoint.gap_version, gap_version_field_size);
  for (const auto& entry : checkpoint.target_pairs) {
    write_permutation(output, entry.fixed_second);
    write_little(output, entry.data.class_index);
    write_little(output, entry.data.pair_id);
    write_permutation(output, entry.data.normalizer);
    write_permutation(output, entry.data.normalized_pair[0]);
    write_permutation(output, entry.data.normalized_pair[1]);
  }
  for (const auto& entry : checkpoint.right_pairs) {
    write_little(output, entry.key.class_index);
    write_permutation(output, entry.key.pair[0]);
    write_permutation(output, entry.key.pair[1]);
    write_little(output, entry.data.pair_id);
    write_permutation(output, entry.data.relative_transporter);
  }
  for (const auto& entry : checkpoint.segments) {
    write_little(output, entry.class_index);
    write_little(output, entry.first_ordinal);
    write_little(output, entry.right_pair_count);
  }
  for (const auto& entry : checkpoint.relatives) {
    write_little(output, entry.key.block_ordinal);
    write_permutation(output, entry.key.permutation);
    write_little(output, entry.relative_index);
  }
  for (const auto& entry : checkpoint.refinements) {
    write_little(output, entry.key.block_ordinal);
    write_little(output, entry.key.relative_index);
    write_little(output, entry.twist_id);
    write_little(output, entry.weight);
  }
  output.flush();
  if (!output) {
    throw std::runtime_error("failed to finish coordinate checkpoint");
  }
}

CoordinateCheckpoint read_coordinate_checkpoint(const std::string& path) {
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  if (!input) {
    throw std::runtime_error("cannot open coordinate checkpoint: " + path);
  }
  const auto file_size = input.tellg();
  input.seekg(0);
  std::array<char, checkpoint_magic.size()> magic{};
  input.read(magic.data(), magic.size());
  if (!input || magic != checkpoint_magic ||
      read_little<std::uint32_t>(input) != checkpoint_schema ||
      read_little<std::uint32_t>(input) != endian_marker ||
      read_little<std::uint32_t>(input) != degree) {
    throw std::runtime_error("unsupported coordinate checkpoint header");
  }
  CoordinateCheckpoint result;
  result.target_order = read_little<std::uint32_t>(input);
  result.target_class_size = read_little<std::uint64_t>(input);
  std::array<std::uint64_t, 5> counts{};
  for (auto& count : counts) {
    count = read_little<std::uint64_t>(input);
  }
  if (file_size < 0 ||
      static_cast<std::uint64_t>(file_size) != expected_checkpoint_size(counts)) {
    throw std::runtime_error("coordinate checkpoint byte count is inconsistent");
  }
  result.target = read_permutation(input);
  result.source_checkpoint_sha256 = read_fixed_string(input, sha_field_size);
  result.source_git_revision = read_fixed_string(input, revision_field_size);
  result.gap_version = read_fixed_string(input, gap_version_field_size);
  result.target_pairs.reserve(counts[0]);
  for (std::uint64_t index = 0; index < counts[0]; ++index) {
    TargetPairEntry entry;
    entry.fixed_second = read_permutation(input);
    entry.data.class_index = read_little<std::uint32_t>(input);
    entry.data.pair_id = read_little<std::uint32_t>(input);
    entry.data.normalizer = read_permutation(input);
    entry.data.normalized_pair = {read_permutation(input),
                                  read_permutation(input)};
    result.target_pairs.push_back(entry);
  }
  result.right_pairs.reserve(counts[1]);
  for (std::uint64_t index = 0; index < counts[1]; ++index) {
    RightPairEntry entry;
    entry.key.class_index = read_little<std::uint32_t>(input);
    entry.key.pair = {read_permutation(input), read_permutation(input)};
    entry.data.pair_id = read_little<std::uint32_t>(input);
    entry.data.relative_transporter = read_permutation(input);
    result.right_pairs.push_back(entry);
  }
  result.segments.reserve(counts[2]);
  for (std::uint64_t index = 0; index < counts[2]; ++index) {
    result.segments.push_back({read_little<std::uint32_t>(input),
                               read_little<std::uint64_t>(input),
                               read_little<std::uint32_t>(input)});
  }
  result.relatives.reserve(counts[3]);
  for (std::uint64_t index = 0; index < counts[3]; ++index) {
    result.relatives.push_back(
        {{read_little<std::uint64_t>(input), read_permutation(input)},
         read_little<std::uint32_t>(input)});
  }
  result.refinements.reserve(counts[4]);
  for (std::uint64_t index = 0; index < counts[4]; ++index) {
    result.refinements.push_back(
        {{read_little<std::uint64_t>(input), read_little<std::uint32_t>(input)},
         read_little<std::uint32_t>(input), read_little<std::uint32_t>(input)});
  }
  if (input.peek() != std::char_traits<char>::eof()) {
    throw std::runtime_error("coordinate checkpoint contains trailing bytes");
  }
  return result;
}

GenerationMaskCheckpoint read_generation_mask_checkpoint(
    const std::string& path) {
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  if (!input) {
    throw std::runtime_error("cannot open generation-mask checkpoint: " + path);
  }
  const auto file_size = input.tellg();
  input.seekg(0);
  std::array<char, mask_checkpoint_magic.size()> magic{};
  input.read(magic.data(), magic.size());
  if (!input || magic != mask_checkpoint_magic ||
      read_little<std::uint32_t>(input) != checkpoint_schema ||
      read_little<std::uint32_t>(input) != endian_marker ||
      read_little<std::uint32_t>(input) != degree) {
    throw std::runtime_error("unsupported generation-mask checkpoint header");
  }
  GenerationMaskCheckpoint result;
  result.mask_bits = read_little<std::uint32_t>(input);
  result.target_class_size = read_little<std::uint64_t>(input);
  if (result.mask_bits == 0 || result.mask_bits > 16 ||
      result.target_class_size >
          (std::numeric_limits<std::uint64_t>::max() -
           mask_checkpoint_header_bytes) /
              sizeof(std::uint16_t)) {
    throw std::runtime_error("invalid generation-mask checkpoint dimensions");
  }
  const auto expected_size = mask_checkpoint_header_bytes +
                             result.target_class_size *
                                 sizeof(std::uint16_t) +
                             sizeof(std::uint64_t);
  if (file_size < 0 || static_cast<std::uint64_t>(file_size) != expected_size) {
    throw std::runtime_error(
        "generation-mask checkpoint byte count is inconsistent");
  }
  result.target = read_permutation(input);
  result.source_checkpoint_sha256 = read_fixed_string(input, sha_field_size);
  result.source_git_revision = read_fixed_string(input, revision_field_size);
  result.gap_version = read_fixed_string(input, gap_version_field_size);
  result.masks.reserve(result.target_class_size);
  const auto full_mask = static_cast<std::uint32_t>(
      (std::uint64_t{1} << result.mask_bits) - 1);
  for (std::uint64_t index = 0; index < result.target_class_size; ++index) {
    const auto mask = read_little<std::uint16_t>(input);
    if (mask > full_mask) {
      throw std::runtime_error("generation mask exceeds its declared width");
    }
    result.masks.push_back(mask);
  }
  result.target_row_fingerprint = read_little<std::uint64_t>(input);
  if (input.peek() != std::char_traits<char>::eof()) {
    throw std::runtime_error(
        "generation-mask checkpoint contains trailing bytes");
  }
  return result;
}

Permutation Permutation::identity() {
  Permutation result;
  for (std::size_t point = 0; point < degree; ++point) {
    result.image[point] = static_cast<std::uint8_t>(point);
  }
  return result;
}

bool Permutation::valid() const {
  std::array<bool, degree> seen{};
  for (const auto image_point : image) {
    if (image_point >= degree || seen[image_point]) {
      return false;
    }
    seen[image_point] = true;
  }
  return true;
}

std::size_t Tuple4Hash::operator()(const Tuple4& tuple) const noexcept {
  // FNV-1a is stable across standard-library implementations.  Checkpoint
  // correctness never depends on hash-table iteration order.
  std::uint64_t hash = fnv_offset;
  for (const auto& permutation : tuple) {
    hash_permutation(hash, permutation);
  }
  return finish_hash(hash);
}

std::size_t PermutationHash::operator()(
    const Permutation& permutation) const noexcept {
  std::uint64_t hash = fnv_offset;
  hash_permutation(hash, permutation);
  return finish_hash(hash);
}

std::size_t Pair2Hash::operator()(const Pair2& pair) const noexcept {
  std::uint64_t hash = fnv_offset;
  hash_permutation(hash, pair[0]);
  hash_permutation(hash, pair[1]);
  return finish_hash(hash);
}

std::size_t ClassPairKeyHash::operator()(
    const ClassPairKey& key) const noexcept {
  std::uint64_t hash = fnv_offset;
  combine_integer(hash, key.class_index);
  hash_permutation(hash, key.pair[0]);
  hash_permutation(hash, key.pair[1]);
  return finish_hash(hash);
}

std::size_t BlockPermutationKeyHash::operator()(
    const BlockPermutationKey& key) const noexcept {
  std::uint64_t hash = fnv_offset;
  combine_integer(hash, key.block_ordinal);
  hash_permutation(hash, key.permutation);
  return finish_hash(hash);
}

std::size_t BlockRelativeKeyHash::operator()(
    const BlockRelativeKey& key) const noexcept {
  std::uint64_t hash = fnv_offset;
  combine_integer(hash, key.block_ordinal);
  combine_integer(hash, key.relative_index);
  return finish_hash(hash);
}

ExactCoordinateIndex::ExactCoordinateIndex(
    const std::span<const ExactCoordinateEntry> entries) {
  entries_.reserve(entries.size());
  for (const auto& entry : entries) {
    const auto [position, inserted] = entries_.emplace(entry.tuple, entry.vertex);
    if (!inserted && position->second != entry.vertex) {
      throw std::invalid_argument(
          "one exact tuple has conflicting pair-twist coordinates");
    }
  }
}

const PairTwistVertex* ExactCoordinateIndex::locate(
    const Tuple4& tuple) const {
  const auto position = entries_.find(tuple);
  return position == entries_.end() ? nullptr : &position->second;
}

FixedTargetGenerationMasks::FixedTargetGenerationMasks(
    const GenerationMaskCheckpoint& checkpoint,
    const std::span<const TargetPairEntry> target_pairs)
    : target_(checkpoint.target),
      full_mask_(static_cast<std::uint16_t>(
          (std::uint32_t{1} << checkpoint.mask_bits) - 1)) {
  if (checkpoint.mask_bits == 0 || checkpoint.mask_bits > 16 ||
      checkpoint.target_class_size != target_pairs.size() ||
      checkpoint.masks.size() != target_pairs.size()) {
    throw std::invalid_argument(
        "generation masks and target-pair rows have different dimensions");
  }
  masks_.reserve(target_pairs.size());
  auto row_fingerprint = fnv_offset;
  for (std::size_t index = 0; index < target_pairs.size(); ++index) {
    row_fingerprint =
        append_row_fingerprint(row_fingerprint, target_pairs[index].fixed_second);
    const auto [position, inserted] =
        masks_.emplace(target_pairs[index].fixed_second,
                       checkpoint.masks[index]);
    if (!inserted && position->second != checkpoint.masks[index]) {
      throw std::invalid_argument(
          "one target-class element has conflicting generation masks");
    }
  }
  if (masks_.size() != checkpoint.target_class_size ||
      row_fingerprint != checkpoint.target_row_fingerprint ||
      mask(target_) != full_mask_) {
    throw std::invalid_argument(
        "generation-mask table does not biject the target class");
  }
}

std::uint16_t FixedTargetGenerationMasks::mask(
    const Permutation& element) const {
  const auto position = masks_.find(element);
  if (position == masks_.end()) {
    throw std::invalid_argument(
        "element is absent from the generation-mask target class");
  }
  return position->second;
}

bool FixedTargetGenerationMasks::generates(
    const Tuple4& tuple, const Permutation& first_transporter) const {
  const auto fixed = simultaneous_conjugate(tuple, first_transporter);
  if (fixed[0] != target_) {
    throw std::invalid_argument(
        "generation-mask transporter does not fix the first coordinate");
  }
  auto common = full_mask_;
  for (const auto& element : fixed) {
    common = static_cast<std::uint16_t>(common & mask(element));
  }
  return common == 0;
}

CompressedCoordinateIndex::CompressedCoordinateIndex(
    Permutation target, const std::span<const TargetPairEntry> target_pairs,
    const std::span<const RightPairEntry> right_pairs,
    const std::span<const MacroblockSegmentEntry> segments,
    const std::span<const RelativeEntry> relatives,
    const std::span<const RefinementEntry> refinements)
    : target_(target) {
  std::unordered_map<std::uint32_t, std::unordered_map<std::uint32_t,
                                                       std::size_t>>
      right_pair_row_counts;
  std::unordered_map<std::uint64_t, Permutation> fixed_seconds_by_pair;
  target_pairs_.reserve(target_pairs.size());
  for (const auto& entry : target_pairs) {
    const auto [position, inserted] =
        target_pairs_.emplace(entry.fixed_second, entry.data);
    if (!inserted &&
        (position->second.class_index != entry.data.class_index ||
         position->second.pair_id != entry.data.pair_id ||
         position->second.normalizer != entry.data.normalizer ||
         position->second.normalized_pair != entry.data.normalized_pair)) {
      throw std::invalid_argument("conflicting target-pair checkpoint rows");
    }
    const auto id_key =
        class_pair_id_key(entry.data.class_index, entry.data.pair_id);
    const auto fixed_position = fixed_seconds_by_pair.find(id_key);
    if (fixed_position == fixed_seconds_by_pair.end()) {
      fixed_seconds_by_pair.emplace(id_key, entry.fixed_second);
    } else if (permutation_less(entry.fixed_second, fixed_position->second)) {
      fixed_position->second = entry.fixed_second;
    }
    const auto [pair_position, pair_inserted] =
        normalized_pairs_by_id_.emplace(id_key, entry.data.normalized_pair);
    if (!pair_inserted && pair_position->second != entry.data.normalized_pair) {
      throw std::invalid_argument(
          "one target pair ID has conflicting normalized pairs");
    }
    pair_first_transports_by_id_.try_emplace(
        id_key, inverse(entry.data.normalizer));
    auto& pair_count = left_pair_counts_[entry.data.class_index];
    pair_count = std::max(pair_count, entry.data.pair_id);
  }
  right_pairs_.reserve(right_pairs.size());
  for (const auto& entry : right_pairs) {
    const auto [position, inserted] =
        right_pairs_.emplace(entry.key, entry.data);
    if (!inserted &&
        (position->second.pair_id != entry.data.pair_id ||
         position->second.relative_transporter !=
             entry.data.relative_transporter)) {
      throw std::invalid_argument("conflicting right-pair checkpoint rows");
    }
    ++right_pair_row_counts[entry.key.class_index][entry.data.pair_id];
    if (entry.data.relative_transporter == Permutation::identity()) {
      const auto id_key =
          class_pair_id_key(entry.key.class_index, entry.data.pair_id);
      const auto [base_position, base_inserted] =
          right_pair_bases_by_id_.emplace(id_key, entry.key.pair);
      if (!base_inserted && base_position->second != entry.key.pair) {
        throw std::invalid_argument(
            "one right pair ID has conflicting identity bases");
      }
    }
  }
  std::unordered_map<std::uint32_t, std::uint32_t> free_pair_ids;
  for (const auto& [class_index, counts] : right_pair_row_counts) {
    const auto largest = std::max_element(
        counts.begin(), counts.end(), [](const auto& left, const auto& right) {
          return left.second < right.second;
        });
    if (largest != counts.end()) {
      free_pair_ids.emplace(class_index, largest->first);
    }
  }
  for (const auto& entry : right_pairs) {
    const auto free_position = free_pair_ids.find(entry.key.class_index);
    if (free_position != free_pair_ids.end() &&
        entry.data.pair_id == free_position->second) {
      centralizers_[entry.key.class_index].push_back(
          entry.data.relative_transporter);
    }
  }
  for (auto& [class_index, centralizer] : centralizers_) {
    static_cast<void>(class_index);
    std::sort(centralizer.begin(), centralizer.end(), permutation_less);
    const auto unique_end = std::unique(centralizer.begin(), centralizer.end());
    // Differential fixtures intentionally repeat a small selection of lookup
    // rows.  The complete binary export has one row per orbit member, but
    // accepting consistent repeats keeps the constructor useful at that seam.
    centralizer.erase(unique_end, centralizer.end());
  }
  for (const auto& entry : segments) {
    const auto [position, inserted] = segments_.emplace(entry.class_index, entry);
    if (!inserted &&
        (position->second.first_ordinal != entry.first_ordinal ||
         position->second.right_pair_count != entry.right_pair_count)) {
      throw std::invalid_argument("conflicting macroblock segment rows");
    }
    ordered_segments_.push_back(entry);
  }
  std::sort(ordered_segments_.begin(), ordered_segments_.end(),
            [](const auto& left, const auto& right) {
              return left.first_ordinal < right.first_ordinal;
            });
  std::uint64_t identity_pair_key = 0;
  for (const auto& [key, pair] : normalized_pairs_by_id_) {
    if (compose(pair[0], pair[1]) != Permutation::identity()) {
      continue;
    }
    if (identity_pair_key != 0 && identity_pair_key != key) {
      throw std::invalid_argument(
          "native checkpoint has multiple identity-product pair orbits");
    }
    identity_pair_key = key;
  }
  if (identity_pair_key != 0) {
    identity_class_index_ =
        static_cast<std::uint32_t>(identity_pair_key >> 32U);
    const auto identity_segment = segments_.find(identity_class_index_);
    const auto identity_left_count =
        left_pair_counts_.find(identity_class_index_);
    if (identity_segment == segments_.end() ||
        identity_left_count == left_pair_counts_.end() ||
        identity_segment->second.first_ordinal != 1 ||
        identity_segment->second.right_pair_count != 1 ||
        identity_left_count->second != 1) {
      throw std::invalid_argument(
          "identity-product class is not one symbolic macroblock");
    }
    identity_block_ordinal_ = identity_segment->second.first_ordinal;
    std::vector<std::uint64_t> identity_keys;
    identity_keys.reserve(fixed_seconds_by_pair.size());
    for (const auto& [key, fixed_second] : fixed_seconds_by_pair) {
      static_cast<void>(fixed_second);
      identity_keys.push_back(key);
    }
    std::sort(identity_keys.begin(), identity_keys.end());
    identity_fixed_seconds_.reserve(identity_keys.size());
    for (const auto key : identity_keys) {
      const auto twist_id =
          static_cast<std::uint32_t>(identity_fixed_seconds_.size() + 1);
      identity_twist_ids_.emplace(key, twist_id);
      identity_fixed_seconds_.push_back(fixed_seconds_by_pair.at(key));
    }
  }
  add_relative_entries(relatives);
  add_refinement_entries(refinements);
}

std::vector<RelativeEntry> CompressedCoordinateIndex::build_relative_entries(
    const std::uint64_t block_ordinal) const {
  const auto segment_position = std::find_if(
      ordered_segments_.begin(), ordered_segments_.end(),
      [&](const auto& segment) {
        const auto count_position =
            left_pair_counts_.find(segment.class_index);
        if (count_position == left_pair_counts_.end() ||
            segment.right_pair_count == 0) {
          return false;
        }
        const auto extent =
            static_cast<std::uint64_t>(count_position->second) *
            segment.right_pair_count;
        return block_ordinal >= segment.first_ordinal &&
               block_ordinal - segment.first_ordinal < extent;
      });
  if (segment_position == ordered_segments_.end()) {
    throw std::invalid_argument(
        "macroblock ordinal is outside the native global tables");
  }
  const auto& segment = *segment_position;
  const auto offset = block_ordinal - segment.first_ordinal;
  const auto left_pair_id = static_cast<std::uint32_t>(
      offset / segment.right_pair_count + 1);
  const auto right_pair_id = static_cast<std::uint32_t>(
      offset % segment.right_pair_count + 1);
  const auto left_position = normalized_pairs_by_id_.find(
      class_pair_id_key(segment.class_index, left_pair_id));
  const auto right_position = right_pair_bases_by_id_.find(
      class_pair_id_key(segment.class_index, right_pair_id));
  const auto centralizer_position = centralizers_.find(segment.class_index);
  if (left_position == normalized_pairs_by_id_.end() ||
      right_position == right_pair_bases_by_id_.end() ||
      centralizer_position == centralizers_.end()) {
    throw std::invalid_argument(
        "macroblock requires missing or identity-product global pair data");
  }
  const auto& centralizer = centralizer_position->second;
  if (centralizer.empty() || centralizer.front() != Permutation::identity()) {
    throw std::invalid_argument(
        "right-pair table does not expose a complete free centralizer orbit");
  }
  const auto product_element =
      compose(left_position->second[0], left_position->second[1]);
  std::vector<Permutation> left_stabilizer;
  std::vector<Permutation> right_stabilizer;
  for (const auto& element : centralizer) {
    if (conjugate(product_element, element) != product_element) {
      throw std::invalid_argument(
          "recovered product centralizer contains an invalid element");
    }
    if (fixes_pair(element, left_position->second)) {
      left_stabilizer.push_back(element);
    }
    if (fixes_pair(element, right_position->second)) {
      right_stabilizer.push_back(element);
    }
  }
  std::unordered_set<Permutation, PermutationHash> assigned;
  assigned.reserve(centralizer.size());
  std::vector<RelativeEntry> result;
  result.reserve(centralizer.size());
  std::uint32_t relative_index = 0;
  for (const auto& representative : centralizer) {
    if (assigned.contains(representative)) {
      continue;
    }
    ++relative_index;
    std::vector<Permutation> members;
    members.reserve(left_stabilizer.size() * right_stabilizer.size());
    for (const auto& right : right_stabilizer) {
      for (const auto& left : left_stabilizer) {
        members.push_back(compose(compose(right, representative), left));
      }
    }
    std::sort(members.begin(), members.end(), permutation_less);
    members.erase(std::unique(members.begin(), members.end()), members.end());
    if (members.empty() || members.front() != representative) {
      throw std::invalid_argument(
          "native key-v2 double-coset representative is inconsistent");
    }
    for (const auto& member : members) {
      if (!std::binary_search(centralizer.begin(), centralizer.end(), member,
                              permutation_less) ||
          !assigned.emplace(member).second) {
        throw std::invalid_argument(
            "native relative double cosets overlap or leave the centralizer");
      }
      result.push_back({{block_ordinal, member}, relative_index});
    }
  }
  if (assigned.size() != centralizer.size()) {
    throw std::invalid_argument(
        "native relative double cosets do not partition the centralizer");
  }
  return result;
}

std::vector<RefinementEntry>
CompressedCoordinateIndex::build_refinement_entries(
    const std::uint64_t block_ordinal) const {
  const auto relative_rows = build_relative_entries(block_ordinal);
  return build_refinement_entries(block_ordinal, relative_rows);
}

BlockCoordinateTables CompressedCoordinateIndex::build_block_tables(
    const std::uint64_t block_ordinal) const {
  BlockCoordinateTables result;
  result.relatives = build_relative_entries(block_ordinal);
  result.refinements =
      build_refinement_entries(block_ordinal, result.relatives);
  return result;
}

void CompressedCoordinateIndex::ensure_block(
    const std::uint64_t block_ordinal) {
  if (block_ordinal == identity_block_ordinal_) {
    return;
  }
  if (block_tables_.contains(block_ordinal)) {
    return;
  }
  auto tables = build_block_tables(block_ordinal);
  add_relative_entries(tables.relatives);
  add_refinement_entries(tables.refinements);
  const auto [position, inserted] =
      block_tables_.emplace(block_ordinal, std::move(tables));
  static_cast<void>(position);
  if (!inserted) {
    throw std::logic_error("native block cache insertion failed");
  }
}

PairTwistOrbitData CompressedCoordinateIndex::materialize_vertex(
    const PairTwistVertex& vertex) {
  if (vertex.block_ordinal == identity_block_ordinal_) {
    if (vertex.twist_id == 0 ||
        vertex.twist_id > identity_fixed_seconds_.size() ||
        vertex.weight != 1) {
      throw std::invalid_argument(
          "native identity-block vertex is outside its stable coordinates");
    }
    const auto& third = identity_fixed_seconds_[vertex.twist_id - 1];
    PairTwistOrbitData result;
    result.vertex = vertex;
    result.first_transporter = Permutation::identity();
    result.tuples.push_back(
        {target_, inverse(target_), third, inverse(third)});
    return result;
  }
  ensure_block(vertex.block_ordinal);
  const auto table_position = block_tables_.find(vertex.block_ordinal);
  if (table_position == block_tables_.end()) {
    throw std::logic_error("ensured native block is absent from its cache");
  }
  const auto& tables = table_position->second;
  std::uint32_t relative_count = 0;
  for (const auto& row : tables.relatives) {
    relative_count = std::max(relative_count, row.relative_index);
  }
  std::vector<Permutation> representatives(
      static_cast<std::size_t>(relative_count) + 1);
  std::vector<bool> has_representative(representatives.size());
  for (const auto& row : tables.relatives) {
    auto& representative = representatives[row.relative_index];
    if (!has_representative[row.relative_index] ||
        permutation_less(row.key.permutation, representative)) {
      representative = row.key.permutation;
      has_representative[row.relative_index] = true;
    }
  }
  const auto segment_position = std::find_if(
      ordered_segments_.begin(), ordered_segments_.end(),
      [&](const auto& segment) {
        const auto count_position = left_pair_counts_.find(segment.class_index);
        if (count_position == left_pair_counts_.end()) {
          return false;
        }
        const auto extent =
            static_cast<std::uint64_t>(count_position->second) *
            segment.right_pair_count;
        return vertex.block_ordinal >= segment.first_ordinal &&
               vertex.block_ordinal - segment.first_ordinal < extent;
      });
  if (segment_position == ordered_segments_.end()) {
    throw std::invalid_argument("cannot decode native pair-twist vertex");
  }
  const auto& segment = *segment_position;
  const auto offset = vertex.block_ordinal - segment.first_ordinal;
  const auto left_pair_id = static_cast<std::uint32_t>(
      offset / segment.right_pair_count + 1);
  const auto right_pair_id = static_cast<std::uint32_t>(
      offset % segment.right_pair_count + 1);
  const auto left_key = class_pair_id_key(segment.class_index, left_pair_id);
  const auto right_key = class_pair_id_key(segment.class_index, right_pair_id);
  const auto left_position = normalized_pairs_by_id_.find(left_key);
  const auto right_position = right_pair_bases_by_id_.find(right_key);
  const auto transport_position = pair_first_transports_by_id_.find(left_key);
  if (left_position == normalized_pairs_by_id_.end() ||
      right_position == right_pair_bases_by_id_.end() ||
      transport_position == pair_first_transports_by_id_.end()) {
    throw std::invalid_argument(
        "native pair-twist vertex is missing global pair bases");
  }
  PairTwistOrbitData result;
  result.first_transporter = transport_position->second;
  for (const auto& row : tables.refinements) {
    if (row.twist_id != vertex.twist_id) {
      continue;
    }
    if (row.key.relative_index == 0 ||
        row.key.relative_index > relative_count ||
        !has_representative[row.key.relative_index]) {
      throw std::invalid_argument(
          "native refinement references an invalid relative index");
    }
    if (result.tuples.empty()) {
      result.vertex = {vertex.block_ordinal, row.twist_id, row.weight};
    } else if (result.vertex.weight != row.weight) {
      throw std::invalid_argument(
          "native pair-twist orbit has conflicting weights");
    }
    const auto& representative = representatives[row.key.relative_index];
    Tuple4 tuple{
        left_position->second[0], left_position->second[1],
        conjugate(right_position->second[0], representative),
        conjugate(right_position->second[1], representative)};
    if (product(tuple) != Permutation::identity()) {
      throw std::invalid_argument(
          "materialized native pair-twist tuple is not product one");
    }
    result.tuples.push_back(tuple);
  }
  if (result.tuples.empty()) {
    throw std::invalid_argument(
        "native twist ID is outside its macroblock refinement");
  }
  if (result.tuples.size() != result.vertex.weight ||
      vertex.weight != result.vertex.weight) {
    throw std::invalid_argument(
        "native pair-twist vertex weight is inconsistent");
  }
  return result;
}

std::vector<PairTwistVertex> CompressedCoordinateIndex::block_vertices(
    const std::uint64_t block_ordinal) {
  if (block_ordinal == identity_block_ordinal_) {
    std::vector<PairTwistVertex> result;
    result.reserve(identity_fixed_seconds_.size());
    for (std::size_t index = 0; index < identity_fixed_seconds_.size();
         ++index) {
      result.push_back({block_ordinal, static_cast<std::uint32_t>(index + 1),
                        1});
    }
    return result;
  }
  ensure_block(block_ordinal);
  const auto table_position = block_tables_.find(block_ordinal);
  if (table_position == block_tables_.end()) {
    throw std::logic_error("ensured native block is absent from its cache");
  }
  std::unordered_map<std::uint32_t, std::uint32_t> weights;
  for (const auto& row : table_position->second.refinements) {
    const auto [position, inserted] = weights.emplace(row.twist_id, row.weight);
    if (!inserted && position->second != row.weight) {
      throw std::invalid_argument(
          "native block has conflicting pair-twist weights");
    }
  }
  std::vector<PairTwistVertex> result;
  result.reserve(weights.size());
  for (const auto& [twist_id, weight] : weights) {
    result.push_back({block_ordinal, twist_id, weight});
  }
  std::sort(result.begin(), result.end(),
            [](const auto& left, const auto& right) {
              return left.twist_id < right.twist_id;
            });
  if (!result.empty() && result.back().twist_id != result.size()) {
    throw std::invalid_argument("native block twist IDs are not contiguous");
  }
  return result;
}

void CompressedCoordinateIndex::clear_disposable_block_cache() {
  for (const auto& [block_ordinal, tables] : block_tables_) {
    for (const auto& row : tables.relatives) {
      relatives_.erase(BlockPermutationKey{block_ordinal,
                                            row.key.permutation});
    }
    for (const auto& row : tables.refinements) {
      refinements_.erase(
          BlockRelativeKey{block_ordinal, row.key.relative_index});
    }
  }
  block_tables_.clear();
}

std::optional<PairTwistVertex> CompressedCoordinateIndex::locate_or_build(
    const Tuple4& tuple, const Permutation& first_transporter) {
  const auto relative_key = locate_relative_key(tuple, first_transporter);
  if (!relative_key.has_value()) {
    return std::nullopt;
  }
  if (relative_key->block_ordinal == identity_block_ordinal_) {
    return locate_identity_vertex(relative_key->permutation);
  }
  ensure_block(relative_key->block_ordinal);
  const auto relative_position = relatives_.find(*relative_key);
  if (relative_position == relatives_.end()) {
    throw std::invalid_argument(
        "built native block omits a destination relative coordinate");
  }
  const BlockRelativeKey refinement_key{relative_key->block_ordinal,
                                        relative_position->second};
  const auto refinement_position = refinements_.find(refinement_key);
  if (refinement_position == refinements_.end()) {
    throw std::invalid_argument(
        "built native block omits a destination refinement coordinate");
  }
  return refinement_position->second;
}

std::vector<RefinementEntry>
CompressedCoordinateIndex::build_refinement_entries(
    const std::uint64_t block_ordinal,
    const std::span<const RelativeEntry> relative_rows) const {
  if (relative_rows.empty()) {
    throw std::invalid_argument("cannot refine an empty relative map");
  }
  std::uint32_t relative_count = 0;
  std::unordered_map<Permutation, std::uint32_t, PermutationHash>
      relative_index;
  relative_index.reserve(relative_rows.size());
  for (const auto& row : relative_rows) {
    relative_count = std::max(relative_count, row.relative_index);
    relative_index.emplace(row.key.permutation, row.relative_index);
  }
  std::vector<Permutation> representatives(
      static_cast<std::size_t>(relative_count) + 1);
  std::vector<bool> has_representative(representatives.size());
  for (const auto& row : relative_rows) {
    auto& representative = representatives[row.relative_index];
    if (!has_representative[row.relative_index] ||
        permutation_less(row.key.permutation, representative)) {
      representative = row.key.permutation;
      has_representative[row.relative_index] = true;
    }
  }
  const auto segment_position = std::find_if(
      ordered_segments_.begin(), ordered_segments_.end(),
      [&](const auto& segment) {
        const auto count_position =
            left_pair_counts_.find(segment.class_index);
        if (count_position == left_pair_counts_.end()) {
          return false;
        }
        const auto extent =
            static_cast<std::uint64_t>(count_position->second) *
            segment.right_pair_count;
        return block_ordinal >= segment.first_ordinal &&
               block_ordinal - segment.first_ordinal < extent;
      });
  if (segment_position == ordered_segments_.end()) {
    throw std::invalid_argument("cannot decode refinement macroblock");
  }
  const auto& segment = *segment_position;
  const auto offset = block_ordinal - segment.first_ordinal;
  const auto left_pair_id = static_cast<std::uint32_t>(
      offset / segment.right_pair_count + 1);
  const auto right_pair_id = static_cast<std::uint32_t>(
      offset % segment.right_pair_count + 1);
  const auto left_key = class_pair_id_key(segment.class_index, left_pair_id);
  const auto right_key = class_pair_id_key(segment.class_index, right_pair_id);
  const auto left_position = normalized_pairs_by_id_.find(left_key);
  const auto right_position = right_pair_bases_by_id_.find(right_key);
  const auto transport_position = pair_first_transports_by_id_.find(left_key);
  if (left_position == normalized_pairs_by_id_.end() ||
      right_position == right_pair_bases_by_id_.end() ||
      transport_position == pair_first_transports_by_id_.end()) {
    throw std::invalid_argument("refinement is missing global pair bases");
  }
  std::vector<std::uint32_t> beta12(relative_count + 1);
  std::vector<std::uint32_t> beta34(relative_count + 1);
  for (std::uint32_t index = 1; index <= relative_count; ++index) {
    if (!has_representative[index]) {
      throw std::invalid_argument("relative indices are not contiguous");
    }
    const auto& representative = representatives[index];
    const Tuple4 tuple{
        left_position->second[0], left_position->second[1],
        conjugate(right_position->second[0], representative),
        conjugate(right_position->second[1], representative)};
    if (product(tuple) != Permutation::identity()) {
      throw std::invalid_argument(
          "native relative representative is not product one");
    }
    const auto conjugator = compose(tuple[2], tuple[3]);
    const auto moved12 = pure_braid_move(tuple, 12);
    const auto key12 = locate_relative_key(
        moved12,
        compose(inverse(conjugator), transport_position->second));
    auto moved34 = hurwitz_move(tuple, 4);
    moved34 = hurwitz_move(moved34, 4);
    const auto key34 =
        locate_relative_key(moved34, transport_position->second);
    if (!key12.has_value() || !key34.has_value() ||
        key12->block_ordinal != block_ordinal ||
        key34->block_ordinal != block_ordinal) {
      throw std::invalid_argument("native pair twist left its macroblock");
    }
    const auto position12 = relative_index.find(key12->permutation);
    const auto position34 = relative_index.find(key34->permutation);
    if (position12 == relative_index.end() ||
        position34 == relative_index.end()) {
      throw std::invalid_argument(
          "native pair twist is absent from its relative partition");
    }
    beta12[index] = position12->second;
    beta34[index] = position34->second;
  }
  std::vector<std::uint32_t> twist_ids(relative_count + 1);
  std::vector<std::uint32_t> weights(1, 0);
  std::uint32_t twist_id = 0;
  for (std::uint32_t start = 1; start <= relative_count; ++start) {
    if (twist_ids[start] != 0) {
      continue;
    }
    ++twist_id;
    std::vector<std::uint32_t> orbit;
    auto point = start;
    do {
      if (point < 1 || point > relative_count || twist_ids[point] != 0) {
        throw std::invalid_argument("beta12 rows do not define disjoint cycles");
      }
      twist_ids[point] = twist_id;
      orbit.push_back(point);
      point = beta12[point];
    } while (point != start);
    weights.push_back(static_cast<std::uint32_t>(orbit.size()));
  }
  for (std::uint32_t index = 1; index <= relative_count; ++index) {
    if (twist_ids[beta34[index]] != twist_ids[index]) {
      throw std::invalid_argument(
          "beta34 enlarges the native beta12 pair-twist orbit");
    }
  }
  std::vector<RefinementEntry> result;
  result.reserve(relative_count);
  for (std::uint32_t index = 1; index <= relative_count; ++index) {
    result.push_back({{block_ordinal, index}, twist_ids[index],
                      weights[twist_ids[index]]});
  }
  return result;
}

void CompressedCoordinateIndex::add_relative_entries(
    const std::span<const RelativeEntry> relatives) {
  relatives_.reserve(relatives_.size() + relatives.size());
  for (const auto& entry : relatives) {
    const auto [position, inserted] =
        relatives_.emplace(entry.key, entry.relative_index);
    if (!inserted && position->second != entry.relative_index) {
      throw std::invalid_argument("conflicting relative-coordinate rows");
    }
  }
}

void CompressedCoordinateIndex::add_refinement_entries(
    const std::span<const RefinementEntry> refinements) {
  refinements_.reserve(refinements_.size() + refinements.size());
  for (const auto& entry : refinements) {
    const PairTwistVertex vertex{entry.key.block_ordinal, entry.twist_id,
                                 entry.weight};
    const auto [position, inserted] = refinements_.emplace(entry.key, vertex);
    if (!inserted && position->second != vertex) {
      throw std::invalid_argument("conflicting refinement rows");
    }
  }
}

std::optional<PairTwistVertex> CompressedCoordinateIndex::locate(
    const Tuple4& tuple, const Permutation& first_transporter) const {
  const auto relative_key = locate_relative_key(tuple, first_transporter);
  if (!relative_key.has_value()) {
    return std::nullopt;
  }
  if (relative_key->block_ordinal == identity_block_ordinal_) {
    return locate_identity_vertex(relative_key->permutation);
  }
  const auto relative_position = relatives_.find(*relative_key);
  if (relative_position == relatives_.end()) {
    return std::nullopt;
  }
  const BlockRelativeKey refinement_key{relative_key->block_ordinal,
                                        relative_position->second};
  const auto refinement_position = refinements_.find(refinement_key);
  if (refinement_position == refinements_.end()) {
    return std::nullopt;
  }
  return refinement_position->second;
}

std::optional<BlockPermutationKey>
CompressedCoordinateIndex::locate_relative_key(
    const Tuple4& tuple, const Permutation& first_transporter) const {
  const auto fixed = simultaneous_conjugate(tuple, first_transporter);
  if (fixed[0] != target_) {
    return std::nullopt;
  }
  const auto target_position = target_pairs_.find(fixed[1]);
  if (target_position == target_pairs_.end()) {
    return std::nullopt;
  }
  const auto& target_entry = target_position->second;
  if (target_entry.class_index == identity_class_index_) {
    if (fixed[3] != inverse(fixed[2])) {
      throw std::invalid_argument(
          "identity-product destination does not contain an inverse pair");
    }
    return BlockPermutationKey{identity_block_ordinal_, fixed[2]};
  }
  const auto normalized = simultaneous_conjugate(fixed, target_entry.normalizer);
  if (Pair2{normalized[0], normalized[1]} != target_entry.normalized_pair) {
    throw std::invalid_argument(
        "target-pair checkpoint row does not reproduce its normalized pair");
  }
  const ClassPairKey right_key{target_entry.class_index,
                               {normalized[2], normalized[3]}};
  const auto right_position = right_pairs_.find(right_key);
  if (right_position == right_pairs_.end()) {
    return std::nullopt;
  }
  const auto segment_position = segments_.find(target_entry.class_index);
  if (segment_position == segments_.end()) {
    return std::nullopt;
  }
  const auto& segment = segment_position->second;
  if (target_entry.pair_id < 1 || right_position->second.pair_id < 1 ||
      segment.right_pair_count < right_position->second.pair_id) {
    throw std::invalid_argument("invalid pair ID in coordinate checkpoint");
  }
  const auto block_ordinal =
      segment.first_ordinal +
      static_cast<std::uint64_t>(target_entry.pair_id - 1) *
          segment.right_pair_count +
      right_position->second.pair_id - 1;
  return BlockPermutationKey{block_ordinal,
                             right_position->second.relative_transporter};
}

std::optional<PairTwistVertex>
CompressedCoordinateIndex::locate_identity_vertex(
    const Permutation& fixed_third) const {
  const auto target_position = target_pairs_.find(fixed_third);
  if (target_position == target_pairs_.end()) {
    return std::nullopt;
  }
  const auto key = class_pair_id_key(target_position->second.class_index,
                                     target_position->second.pair_id);
  const auto twist_position = identity_twist_ids_.find(key);
  if (twist_position == identity_twist_ids_.end()) {
    throw std::invalid_argument(
        "identity-product target pair has no stable native twist ID");
  }
  return PairTwistVertex{identity_block_ordinal_, twist_position->second, 1};
}

Permutation compose(const Permutation& left, const Permutation& right) {
  Permutation result;
  for (std::size_t point = 0; point < degree; ++point) {
    result.image[point] = right.image[left.image[point]];
  }
  return result;
}

Permutation inverse(const Permutation& permutation) {
  Permutation result;
  for (std::size_t point = 0; point < degree; ++point) {
    result.image[permutation.image[point]] = static_cast<std::uint8_t>(point);
  }
  return result;
}

std::uint32_t order(const Permutation& permutation) {
  std::array<bool, degree> seen{};
  std::uint32_t result = 1;
  for (std::size_t point = 0; point < degree; ++point) {
    if (seen[point]) {
      continue;
    }
    std::uint32_t length = 0;
    auto current = point;
    do {
      if (current >= degree || seen[current]) {
        throw std::invalid_argument("cannot compute order of invalid permutation");
      }
      seen[current] = true;
      current = permutation.image[current];
      ++length;
    } while (current != point);
    result = std::lcm(result, length);
  }
  return result;
}

Permutation conjugate(const Permutation& value, const Permutation& by) {
  return compose(compose(inverse(by), value), by);
}

Tuple4 simultaneous_conjugate(const Tuple4& tuple, const Permutation& by) {
  Tuple4 result;
  for (std::size_t index = 0; index < tuple.size(); ++index) {
    result[index] = conjugate(tuple[index], by);
  }
  return result;
}

Permutation product(const Tuple4& tuple) {
  auto result = Permutation::identity();
  for (const auto& entry : tuple) {
    result = compose(result, entry);
  }
  return result;
}

Tuple4 hurwitz_move(const Tuple4& tuple, const int gap_index) {
  if (gap_index < 2 || gap_index > 4) {
    throw std::invalid_argument("Hurwitz generator index must lie in [2,4]");
  }
  const auto right_index = static_cast<std::size_t>(gap_index - 1);
  const auto left_index = right_index - 1;
  Tuple4 result = tuple;
  result[left_index] = conjugate(tuple[right_index], inverse(tuple[left_index]));
  result[right_index] = tuple[left_index];
  return result;
}

Tuple4 inverse_hurwitz_move(const Tuple4& tuple, const int gap_index) {
  if (gap_index < 2 || gap_index > 4) {
    throw std::invalid_argument("Hurwitz generator index must lie in [2,4]");
  }
  const auto right_index = static_cast<std::size_t>(gap_index - 1);
  const auto left_index = right_index - 1;
  Tuple4 result = tuple;
  result[left_index] = tuple[right_index];
  result[right_index] = conjugate(tuple[left_index], tuple[right_index]);
  return result;
}

Tuple4 pure_braid_move(const Tuple4& tuple, const int generator) {
  const auto& [s1, s2, s3, s4] = tuple;
  if (generator == 12) {
    const auto by = compose(s3, s4);
    return {conjugate(s1, by), conjugate(s2, by), s3, s4};
  }
  if (generator == 13) {
    return {conjugate(s1, compose(s2, s4)), s2,
            conjugate(s3, compose(s4, s2)), s4};
  }
  if (generator == 14) {
    const auto by = compose(s2, s3);
    return {conjugate(s1, by), s2, s3, conjugate(s4, by)};
  }
  throw std::invalid_argument("supported pure B4 generators are 12, 13, and 14");
}

std::vector<PairTwistVertex> pair_twist_neighbors(
    const std::span<const Tuple4> source_orbit,
    const ExactCoordinateIndex& coordinates) {
  std::vector<PairTwistVertex> neighbors;
  std::unordered_map<BlockRelativeKey, std::uint32_t, BlockRelativeKeyHash>
      seen;
  seen.reserve(source_orbit.size() * 2);
  for (const auto& tuple : source_orbit) {
    for (const int generator : {13, 14}) {
      const auto moved = pure_braid_move(tuple, generator);
      const auto* coordinate = coordinates.locate(moved);
      if (coordinate == nullptr) {
        throw std::invalid_argument(
            "moved tuple is absent from the exact coordinate index");
      }
      const BlockRelativeKey key{coordinate->block_ordinal,
                                 coordinate->twist_id};
      const auto [position, inserted] = seen.emplace(key, coordinate->weight);
      if (inserted) {
        neighbors.push_back(*coordinate);
      } else if (position->second != coordinate->weight) {
        throw std::invalid_argument(
            "one pair-twist key has conflicting coordinate weights");
      }
    }
  }
  std::sort(neighbors.begin(), neighbors.end(),
            [](const PairTwistVertex& left, const PairTwistVertex& right) {
              return left.block_ordinal < right.block_ordinal ||
                     (left.block_ordinal == right.block_ordinal &&
                      left.twist_id < right.twist_id);
            });
  return neighbors;
}

std::vector<PairTwistVertex> pair_twist_neighbors(
    const std::span<const Tuple4> source_orbit,
    const Permutation& first_transporter,
    const CompressedCoordinateIndex& coordinates) {
  std::vector<PairTwistVertex> neighbors;
  std::unordered_map<BlockRelativeKey, std::uint32_t, BlockRelativeKeyHash>
      seen;
  seen.reserve(source_orbit.size() * 2);
  for (const auto& tuple : source_orbit) {
    for (const int generator : {13, 14}) {
      const auto conjugator =
          generator == 13 ? compose(tuple[1], tuple[3])
                          : compose(tuple[1], tuple[2]);
      const auto moved = pure_braid_move(tuple, generator);
      const auto moved_first_transporter =
          compose(inverse(conjugator), first_transporter);
      const auto coordinate =
          coordinates.locate(moved, moved_first_transporter);
      if (!coordinate.has_value()) {
        throw std::invalid_argument(
            "moved tuple is absent from the compressed coordinate index");
      }
      const BlockRelativeKey key{coordinate->block_ordinal,
                                 coordinate->twist_id};
      const auto [position, inserted] = seen.emplace(key, coordinate->weight);
      if (inserted) {
        neighbors.push_back(*coordinate);
      } else if (position->second != coordinate->weight) {
        throw std::invalid_argument(
            "one pair-twist key has conflicting coordinate weights");
      }
    }
  }
  std::sort(neighbors.begin(), neighbors.end(),
            [](const PairTwistVertex& left, const PairTwistVertex& right) {
              return left.block_ordinal < right.block_ordinal ||
                     (left.block_ordinal == right.block_ordinal &&
                      left.twist_id < right.twist_id);
            });
  return neighbors;
}

std::vector<PairTwistVertex> pair_twist_neighbors(
    const PairTwistVertex& source, CompressedCoordinateIndex& coordinates) {
  const auto orbit = coordinates.materialize_vertex(source);
  std::vector<PairTwistVertex> neighbors;
  std::unordered_map<BlockRelativeKey, std::uint32_t, BlockRelativeKeyHash>
      seen;
  seen.reserve(orbit.tuples.size() * 2);
  for (const auto& tuple : orbit.tuples) {
    for (const int generator : {13, 14}) {
      const auto conjugator =
          generator == 13 ? compose(tuple[1], tuple[3])
                          : compose(tuple[1], tuple[2]);
      const auto moved = pure_braid_move(tuple, generator);
      const auto moved_first_transporter =
          compose(inverse(conjugator), orbit.first_transporter);
      const auto coordinate =
          coordinates.locate_or_build(moved, moved_first_transporter);
      if (!coordinate.has_value()) {
        throw std::invalid_argument(
            "moved tuple is absent from the lazy native coordinate index");
      }
      const BlockRelativeKey key{coordinate->block_ordinal,
                                 coordinate->twist_id};
      const auto [position, inserted] = seen.emplace(key, coordinate->weight);
      if (inserted) {
        neighbors.push_back(*coordinate);
      } else if (position->second != coordinate->weight) {
        throw std::invalid_argument(
            "one lazy pair-twist key has conflicting coordinate weights");
      }
    }
  }
  std::sort(neighbors.begin(), neighbors.end(),
            [](const PairTwistVertex& left, const PairTwistVertex& right) {
              return left.block_ordinal < right.block_ordinal ||
                     (left.block_ordinal == right.block_ordinal &&
                      left.twist_id < right.twist_id);
            });
  return neighbors;
}

BoundedWalkResult bounded_pair_twist_walk(
    CompressedCoordinateIndex& coordinates, const PairTwistVertex& seed,
    const std::uint64_t limit) {
  return bounded_pair_twist_walk_with_lookup(
      coordinates, seed, limit,
      [](const PairTwistVertex&) -> std::optional<std::uint64_t> {
        return std::nullopt;
      });
}

BoundedWalkResult bounded_pair_twist_walk_with_lookup(
    CompressedCoordinateIndex& coordinates, const PairTwistVertex& seed,
    const std::uint64_t limit, const OwnershipLookup& lookup) {
  if (limit == 0) {
    throw std::invalid_argument("native bounded walk limit must be positive");
  }
  if (!lookup) {
    throw std::invalid_argument("native bounded walk lookup is empty");
  }
  // Materializing the seed validates its stable ID and weight before any
  // durable-looking result is returned.
  static_cast<void>(coordinates.materialize_vertex(seed));
  BoundedWalkResult result;
  result.limit = limit;
  result.vertices.push_back(seed);
  result.discovered_class_count = seed.weight;
  std::unordered_set<BlockRelativeKey, BlockRelativeKeyHash> seen;
  seen.emplace(BlockRelativeKey{seed.block_ordinal, seed.twist_id});
  std::size_t position = 0;
  while (position < result.vertices.size() &&
         result.discovered_class_count <= limit &&
         !result.linked_certificate.has_value()) {
    const auto neighbors =
        pair_twist_neighbors(result.vertices[position], coordinates);
    for (const auto& neighbor : neighbors) {
      const BlockRelativeKey key{neighbor.block_ordinal, neighbor.twist_id};
      if (!seen.emplace(key).second) {
        continue;
      }
      result.linked_certificate = lookup(neighbor);
      if (result.linked_certificate.has_value()) {
        break;
      }
      result.vertices.push_back(neighbor);
      if (result.discovered_class_count >
          std::numeric_limits<std::uint64_t>::max() - neighbor.weight) {
        throw std::overflow_error("native bounded walk class count overflows");
      }
      result.discovered_class_count += neighbor.weight;
      if (result.discovered_class_count > limit) {
        break;
      }
    }
    ++position;
  }
  result.checked_vertex_count = position;
  if (result.linked_certificate.has_value()) {
    result.status = BoundedWalkStatus::linked;
  } else if (position >= result.vertices.size()) {
    result.status = BoundedWalkStatus::closed;
  } else {
    result.status = BoundedWalkStatus::overflow;
  }
  return result;
}

}  // namespace m23
