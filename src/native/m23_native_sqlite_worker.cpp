#include "m23_kernel.hpp"
#include "m23_native_sqlite.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <limits>
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

double seconds(const Clock::time_point start, const Clock::time_point finish) {
  return std::chrono::duration<double>(finish - start).count();
}

m23::NativeVertexKey key(const m23::PairTwistVertex& vertex) {
  return {vertex.block_ordinal, vertex.twist_id};
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 12) {
      throw std::runtime_error(
          "usage: m23_native_sqlite_worker COORDINATES.bin MASKS.bin "
          "LEDGER.sqlite3 WORKER SHARD_INDEX SHARD_COUNT BLOCK_TARGET "
          "START_BLOCK PROOF_LIMIT WALK_LIMIT LEASE_SECONDS");
    }
    const std::string worker(argv[4]);
    const auto shard_index = parse_u64(argv[5], "shard index");
    const auto shard_count = parse_u64(argv[6], "shard count");
    const auto block_target = parse_u64(argv[7], "block target");
    const auto start_block = parse_u64(argv[8], "start block");
    const auto proof_limit = parse_u64(argv[9], "proof limit");
    const auto walk_limit = parse_u64(argv[10], "walk limit");
    const auto lease_seconds = parse_u64(argv[11], "lease seconds");
    if (worker.empty() || shard_index == 0 || shard_index > shard_count ||
        shard_count > std::numeric_limits<std::uint32_t>::max() ||
        block_target == 0 || proof_limit == 0 || walk_limit < proof_limit ||
        lease_seconds == 0) {
      throw std::runtime_error("invalid native SQLite worker parameters");
    }

    const auto coordinate_checkpoint =
        m23::read_coordinate_checkpoint(argv[1]);
    const auto mask_checkpoint = m23::read_generation_mask_checkpoint(argv[2]);
    if (coordinate_checkpoint.target != mask_checkpoint.target ||
        coordinate_checkpoint.target_class_size !=
            mask_checkpoint.target_class_size ||
        coordinate_checkpoint.source_checkpoint_sha256 !=
            mask_checkpoint.source_checkpoint_sha256) {
      throw std::runtime_error(
          "coordinate and generation-mask checkpoints are incompatible");
    }
    m23::CompressedCoordinateIndex coordinates(
        coordinate_checkpoint.target, coordinate_checkpoint.target_pairs,
        coordinate_checkpoint.right_pairs, coordinate_checkpoint.segments,
        coordinate_checkpoint.relatives, coordinate_checkpoint.refinements);
    const m23::FixedTargetGenerationMasks generation_masks(
        mask_checkpoint, coordinate_checkpoint.target_pairs);

    std::unordered_map<std::uint32_t, std::uint32_t> left_pair_counts;
    for (const auto& row : coordinate_checkpoint.target_pairs) {
      auto& count = left_pair_counts[row.data.class_index];
      count = std::max(count, row.data.pair_id);
    }
    std::uint64_t macroblock_count = 0;
    for (const auto& segment : coordinate_checkpoint.segments) {
      const auto count = left_pair_counts.find(segment.class_index);
      if (count == left_pair_counts.end() || count->second == 0 ||
          segment.right_pair_count == 0) {
        throw std::runtime_error("coordinate checkpoint segment is incomplete");
      }
      const auto extent = static_cast<std::uint64_t>(count->second) *
                          segment.right_pair_count;
      macroblock_count =
          std::max(macroblock_count, segment.first_ordinal + extent - 1);
    }
    if (start_block == 0 || start_block > macroblock_count) {
      throw std::runtime_error("native SQLite start block is out of range");
    }
    m23::NativeSqliteLedger ledger(
        argv[3],
        {coordinate_checkpoint.target_order, macroblock_count, start_block,
         proof_limit, walk_limit,
         coordinate_checkpoint.source_checkpoint_sha256,
         coordinate_checkpoint.source_git_revision,
         coordinate_checkpoint.gap_version});
    if (const auto* prepare = std::getenv("M23_NATIVE_PREPARE_ONLY");
        prepare && std::string(prepare) == "1") {
      const auto stats = ledger.stats();
      std::cout << "prepared\t" << stats.blocks << '\t' << stats.certificates
                << '\t' << stats.vertices << '\n';
      return 0;
    }
    const bool exit_after_certificate = [] {
      const auto* value = std::getenv("M23_NATIVE_EXIT_AFTER_CERTIFICATE");
      return value && std::string(value) == "1";
    }();

    while (true) {
      const auto block = ledger.claim_block(
          worker, lease_seconds, block_target,
          static_cast<std::uint32_t>(shard_index),
          static_cast<std::uint32_t>(shard_count));
      if (!block.has_value()) {
        break;
      }
      const auto block_started = Clock::now();
      const auto block_vertices = coordinates.block_vertices(block->ordinal);
      std::uint64_t generating = 0;
      std::uint64_t added = 0;
      std::uint64_t hits = 0;
      for (const auto& seed : block_vertices) {
        const auto orbit = coordinates.materialize_vertex(seed);
        if (!generation_masks.generates(orbit.tuples.front(),
                                        orbit.first_transporter)) {
          continue;
        }
        ++generating;
        if (ledger.lookup(key(seed)).has_value()) {
          ++hits;
          continue;
        }
        ledger.renew_lease(worker, block->ordinal, lease_seconds);
        const auto result = m23::bounded_pair_twist_walk_with_lookup(
            coordinates, seed, walk_limit,
            [&](const m23::PairTwistVertex& vertex) {
              return ledger.lookup(key(vertex));
            });
        const auto certificate_status =
            result.status == m23::BoundedWalkStatus::linked
                ? "linked"
                : (result.status == m23::BoundedWalkStatus::closed &&
                           result.discovered_class_count <= proof_limit
                       ? "closed"
                       : "overflow");
        std::vector<m23::NativeVertexKey> vertices;
        vertices.reserve(result.vertices.size());
        for (const auto& vertex : result.vertices) {
          vertices.push_back(key(vertex));
        }
        const auto commit = ledger.try_add_certificate(
            worker, block->ordinal,
            {certificate_status, walk_status(result.status),
             result.linked_certificate, key(seed), result.checked_vertex_count,
             result.discovered_class_count},
            vertices);
        if (commit.added) {
          ++added;
          if (exit_after_certificate) {
            std::cerr << "intentional exit after durable native certificate\n"
                      << std::flush;
            std::_Exit(86);
          }
        } else {
          ++hits;
        }
        coordinates.clear_disposable_block_cache();
      }
      ledger.finish_block(worker, *block, block_vertices.size(), generating);
      const auto stats = ledger.stats();
      std::cout << "progress\t" << stats.blocks << '\t' << block_target << '\t'
                << block->ordinal << '\t'
                << seconds(block_started, Clock::now()) << '\t'
                << stats.certificates << '\t' << stats.vertices << '\t'
                << "added=" << added << ",hits=" << hits << '\n'
                << std::flush;
    }
    const auto stats = ledger.stats();
    std::cout << "complete\t" << worker << '\t' << stats.blocks << '\t'
              << stats.certificates << '\t' << stats.vertices << '\t'
              << stats.leases << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
