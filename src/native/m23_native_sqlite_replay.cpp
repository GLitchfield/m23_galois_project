#include "m23_kernel.hpp"
#include "m23_native_replay.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <limits>
#include <optional>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

using Clock = std::chrono::steady_clock;

std::uint64_t parse_u64(const char* text, const std::string& label) {
  std::size_t consumed = 0;
  const std::string value(text);
  const auto result = std::stoull(value, &consumed);
  if (consumed != value.size()) {
    throw std::runtime_error("invalid " + label + ": " + value);
  }
  return result;
}

const char* walk_status(const m23::BoundedWalkStatus status) {
  switch (status) {
    case m23::BoundedWalkStatus::closed:
      return "closed";
    case m23::BoundedWalkStatus::overflow:
      return "overflow";
    case m23::BoundedWalkStatus::linked:
      return "linked";
  }
  throw std::logic_error("unknown native bounded-walk status");
}

m23::NativeVertexKey key(const m23::PairTwistVertex& vertex) {
  return {vertex.block_ordinal, vertex.twist_id};
}

std::uint64_t macroblock_count(const m23::CoordinateCheckpoint& checkpoint) {
  std::unordered_map<std::uint32_t, std::uint32_t> left_pair_counts;
  for (const auto& row : checkpoint.target_pairs) {
    auto& count = left_pair_counts[row.data.class_index];
    count = std::max(count, row.data.pair_id);
  }
  std::uint64_t result = 0;
  for (const auto& segment : checkpoint.segments) {
    const auto count = left_pair_counts.find(segment.class_index);
    if (count == left_pair_counts.end() || count->second == 0 ||
        segment.right_pair_count == 0) {
      throw std::runtime_error("coordinate checkpoint segment is incomplete");
    }
    const auto extent = static_cast<std::uint64_t>(count->second) *
                        segment.right_pair_count;
    result = std::max(result, segment.first_ordinal + extent - 1);
  }
  return result;
}

m23::PairTwistVertex seed_vertex(
    m23::CompressedCoordinateIndex& coordinates,
    const m23::NativeVertexKey& key) {
  const auto vertices = coordinates.block_vertices(key.ordinal);
  const auto found = std::find_if(
      vertices.begin(), vertices.end(),
      [&](const m23::PairTwistVertex& candidate) {
        return candidate.twist_id == key.twist;
      });
  if (found == vertices.end()) {
    throw std::runtime_error("stored replay seed is not a native coordinate");
  }
  return *found;
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 3 && argc != 5) {
      throw std::runtime_error(
          "usage: m23_native_sqlite_replay COORDINATES.bin LEDGER.sqlite3 "
          "[FIRST_CERTIFICATE LAST_CERTIFICATE]");
    }
    const auto checkpoint = m23::read_coordinate_checkpoint(argv[1]);
    m23::NativeReplayLedger ledger(argv[2]);
    const auto& config = ledger.config();
    if (checkpoint.target_order != config.target_order ||
        checkpoint.source_checkpoint_sha256 !=
            config.source_checkpoint_sha256 ||
        macroblock_count(checkpoint) != config.macroblock_count) {
      throw std::runtime_error(
          "coordinate checkpoint and native replay ledger are incompatible");
    }
    const auto total = ledger.certificate_count();
    const auto first = argc == 5 ? parse_u64(argv[3], "first certificate") : 1;
    const auto last = argc == 5 ? parse_u64(argv[4], "last certificate")
                                : total;
    if (first == 0 || last < first || last > total) {
      throw std::runtime_error("native replay certificate range is invalid");
    }
    m23::CompressedCoordinateIndex coordinates(
        checkpoint.target, checkpoint.target_pairs, checkpoint.right_pairs,
        checkpoint.segments, checkpoint.relatives, checkpoint.refinements);
    const auto started = Clock::now();
    std::uint64_t replayed_vertices = 0;
    for (auto id = first; id <= last; ++id) {
      const auto certificate = ledger.certificate(id);
      const auto seed = seed_vertex(coordinates, certificate.data.seed);
      const auto replay = m23::bounded_pair_twist_walk_with_lookup(
          coordinates, seed, config.walk_limit,
          [&](const m23::PairTwistVertex& vertex) {
            return ledger.lookup_before(key(vertex), id);
          });
      const auto expected_status =
          replay.status == m23::BoundedWalkStatus::linked
              ? "linked"
              : (replay.status == m23::BoundedWalkStatus::closed &&
                         replay.discovered_class_count <= config.proof_limit
                     ? "closed"
                     : "overflow");
      std::vector<m23::NativeVertexKey> replay_vertices;
      replay_vertices.reserve(replay.vertices.size());
      for (const auto& vertex : replay.vertices) {
        replay_vertices.push_back(key(vertex));
      }
      if (certificate.data.status != expected_status ||
          certificate.data.walk_status != walk_status(replay.status) ||
          certificate.data.linked_certificate != replay.linked_certificate ||
          certificate.data.checked_vertices != replay.checked_vertex_count ||
          certificate.data.discovered_classes !=
              replay.discovered_class_count ||
          certificate.vertices != replay_vertices) {
        throw std::runtime_error("native prefix replay mismatch at certificate " +
                                 std::to_string(id));
      }
      replayed_vertices += replay_vertices.size();
      coordinates.clear_disposable_block_cache();
      if ((id - first + 1) % 1000 == 0 || id == last) {
        const auto elapsed = std::chrono::duration<double>(Clock::now() - started)
                                 .count();
        std::cout << "progress\t" << id << '\t' << last << '\t'
                  << replayed_vertices << '\t' << elapsed << '\n'
                  << std::flush;
      }
      if (id == std::numeric_limits<std::uint64_t>::max()) {
        break;
      }
    }
    const auto elapsed =
        std::chrono::duration<double>(Clock::now() - started).count();
    std::cout << "complete\t" << first << '\t' << last << '\t'
              << replayed_vertices << '\t' << elapsed << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
