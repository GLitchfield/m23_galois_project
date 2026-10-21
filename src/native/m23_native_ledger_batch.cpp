#include "m23_kernel.hpp"

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <cstdint>
#include <fstream>
#include <iomanip>
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

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 8) {
      throw std::runtime_error(
          "usage: m23_native_ledger_batch COORDINATES.bin MASKS.bin "
          "START_BLOCK BLOCK_COUNT PROOF_LIMIT WALK_LIMIT OUTPUT.tsv; or "
          "use --stratified SAMPLES in place of START_BLOCK BLOCK_COUNT");
    }
    const bool stratified = std::string(argv[3]) == "--stratified";
    const auto start_block = stratified ? 0 : parse_u64(argv[3], "start block");
    const auto requested_count = parse_u64(
        argv[4], stratified ? "samples per segment" : "block count");
    const auto proof_limit = parse_u64(argv[5], "proof limit");
    const auto walk_limit = parse_u64(argv[6], "walk limit");
    std::uint64_t cache_reset_certificates = 1;
    if (const auto* value = std::getenv("M23_NATIVE_CACHE_RESET_CERTIFICATES")) {
      cache_reset_certificates =
          parse_u64(value, "native cache reset certificate interval");
    }
    if ((!stratified && start_block == 0) || requested_count == 0 ||
        proof_limit == 0 ||
        walk_limit < proof_limit ||
        (!stratified &&
         start_block > std::numeric_limits<std::uint64_t>::max() -
                           (requested_count - 1))) {
      throw std::runtime_error("native ledger batch bounds are invalid");
    }

    const auto started = Clock::now();
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
    std::vector<std::pair<m23::MacroblockSegmentEntry, std::uint64_t>>
        segment_extents;
    for (const auto& segment : coordinate_checkpoint.segments) {
      const auto count = left_pair_counts.find(segment.class_index);
      if (count == left_pair_counts.end() || count->second == 0 ||
          segment.right_pair_count == 0) {
        throw std::runtime_error("coordinate checkpoint segment is incomplete");
      }
      const auto extent = static_cast<std::uint64_t>(count->second) *
                          segment.right_pair_count;
      segment_extents.emplace_back(segment, extent);
      macroblock_count =
          std::max(macroblock_count, segment.first_ordinal + extent - 1);
    }
    std::sort(segment_extents.begin(), segment_extents.end(),
              [](const auto& left, const auto& right) {
                return left.first.first_ordinal < right.first.first_ordinal;
              });
    std::vector<std::uint64_t> ordinals;
    struct SampleRow {
      std::uint64_t segment{};
      std::uint32_t class_index{};
      std::uint64_t segment_blocks{};
      std::uint64_t sample{};
      std::uint64_t ordinal{};
    };
    std::vector<SampleRow> samples;
    if (stratified) {
      for (std::size_t segment_index = 0;
           segment_index < segment_extents.size(); ++segment_index) {
        const auto& [segment, extent] = segment_extents[segment_index];
        // The identity-product block is a single exceptional block rather than
        // a statistical stratum. Its known component is measured separately;
        // starting an empty sampled ledger there would badly distort the
        // weighted generic-block estimate.
        if (extent == 1) {
          continue;
        }
        const auto sample_count = std::min(requested_count, extent);
        for (std::uint64_t sample = 1; sample <= sample_count; ++sample) {
          const auto offset = ((2 * sample - 1) * extent) / (2 * sample_count);
          const auto ordinal = segment.first_ordinal + offset;
          ordinals.push_back(ordinal);
          samples.push_back({segment_index + 1, segment.class_index, extent,
                             sample, ordinal});
        }
      }
      std::sort(samples.begin(), samples.end(),
                [](const auto& left, const auto& right) {
                  if (left.segment_blocks != right.segment_blocks) {
                    return left.segment_blocks > right.segment_blocks;
                  }
                  if (left.segment != right.segment) {
                    return left.segment < right.segment;
                  }
                  return left.sample < right.sample;
                });
      ordinals.clear();
      for (const auto& sample : samples) {
        ordinals.push_back(sample.ordinal);
      }
    } else {
      ordinals.reserve(requested_count);
      for (std::uint64_t offset = 0; offset < requested_count; ++offset) {
        ordinals.push_back(start_block + offset);
      }
    }
    if (ordinals.empty() ||
        std::ranges::any_of(ordinals, [macroblock_count](const auto ordinal) {
          return ordinal > macroblock_count;
        })) {
      throw std::runtime_error("native ledger batch exceeds macroblock census");
    }
    const auto initialized = Clock::now();

    std::ofstream output(argv[7], std::ios::trunc);
    if (!output) {
      throw std::runtime_error("cannot create native ledger transcript");
    }
    output << "# schema\t"
           << (stratified ? "m23-native-ledger-stratified-v1"
                          : "m23-native-ledger-batch-v1")
           << '\n'
           << "# coordinate_convention\tnative-v1\n"
           << "# target_order\t" << coordinate_checkpoint.target_order << '\n'
           << "# source_checkpoint_sha256\t"
           << coordinate_checkpoint.source_checkpoint_sha256 << '\n'
           << "# source_git_revision\t"
           << coordinate_checkpoint.source_git_revision << '\n'
           << "# gap_version\t" << coordinate_checkpoint.gap_version << '\n'
           << "# start_block\t" << (stratified ? ordinals.front() : start_block)
           << '\n'
           << "# block_count\t" << ordinals.size() << '\n'
           << "# macroblock_count\t" << macroblock_count << '\n'
           << "# proof_limit\t" << proof_limit << '\n'
           << "# walk_limit\t" << walk_limit << '\n';
    if (stratified) {
      output << "# samples_per_segment\t" << requested_count << '\n';
      output << "# identity_block_excluded\t1\n";
      output << "# cache_reset_certificates\t"
             << cache_reset_certificates << '\n';
      for (const auto& sample : samples) {
        output << "S\t" << sample.segment << '\t' << sample.class_index << '\t'
               << sample.segment_blocks << '\t' << sample.sample << '\t'
               << sample.ordinal << '\n';
      }
    }
    const bool plan_only = [] {
      const auto* value = std::getenv("M23_NATIVE_PLAN_ONLY");
      return value && std::string(value) == "1";
    }();
    if (plan_only) {
      if (!stratified) {
        throw std::runtime_error(
            "native plan-only mode requires stratified selection");
      }
      output.flush();
      if (!output) {
        throw std::runtime_error("failed to finish native work plan");
      }
      std::cout << "plan\t" << ordinals.size() << '\t' << macroblock_count
                << '\n';
      return 0;
    }

    std::unordered_map<m23::BlockRelativeKey, std::uint64_t,
                       m23::BlockRelativeKeyHash>
        owners;
    std::uint64_t certificate_id = 0;
    std::uint64_t refined_total = 0;
    std::uint64_t generating_total = 0;
    std::uint64_t hit_total = 0;
    std::uint64_t completed_blocks = 0;
    for (const auto ordinal : ordinals) {
      const auto block_started = Clock::now();
      const auto certificates_before = certificate_id;
      const auto owners_before = owners.size();
      const auto refinement_started = Clock::now();
      const auto block_vertices = coordinates.block_vertices(ordinal);
      const auto refinement_finished = Clock::now();
      double generation_seconds = 0;
      double traversal_seconds = 0;
      const auto refined = static_cast<std::uint64_t>(block_vertices.size());
      std::uint64_t generating = 0;
      std::uint64_t new_certificates = 0;
      std::uint64_t hits = 0;
      for (const auto& seed : block_vertices) {
        const auto generation_started = Clock::now();
        const auto orbit = coordinates.materialize_vertex(seed);
        if (!generation_masks.generates(orbit.tuples.front(),
                                        orbit.first_transporter)) {
          generation_seconds += seconds(generation_started, Clock::now());
          continue;
        }
        generation_seconds += seconds(generation_started, Clock::now());
        ++generating;
        const m23::BlockRelativeKey seed_key{seed.block_ordinal, seed.twist_id};
        if (owners.contains(seed_key)) {
          ++hits;
          continue;
        }
        const auto traversal_started = Clock::now();
        const auto result = m23::bounded_pair_twist_walk_with_lookup(
            coordinates, seed, walk_limit,
            [&](const m23::PairTwistVertex& vertex)
                -> std::optional<std::uint64_t> {
              const auto position = owners.find(
                  {vertex.block_ordinal, vertex.twist_id});
              return position == owners.end()
                         ? std::nullopt
                         : std::optional<std::uint64_t>{position->second};
            });
        ++certificate_id;
        ++new_certificates;
        const auto certificate_status =
            result.status == m23::BoundedWalkStatus::linked
                ? "linked"
                : (result.status == m23::BoundedWalkStatus::closed &&
                           result.discovered_class_count <= proof_limit
                       ? "closed"
                       : "overflow");
        output << "C\t" << certificate_id << '\t' << certificate_status << '\t'
               << walk_status(result.status) << '\t'
               << result.linked_certificate.value_or(0) << '\t'
               << seed.block_ordinal << '\t' << seed.twist_id << '\t'
               << result.checked_vertex_count << '\t' << result.vertices.size()
               << '\t' << result.discovered_class_count << '\n';
        std::uint64_t position = 0;
        for (const auto& vertex : result.vertices) {
          const auto [owner, inserted] = owners.emplace(
              m23::BlockRelativeKey{vertex.block_ordinal, vertex.twist_id},
              certificate_id);
          if (!inserted) {
            throw std::runtime_error(
                "native ownership lookup admitted an overlapping certificate");
          }
          static_cast<void>(owner);
          output << "V\t" << certificate_id << '\t' << ++position << '\t'
                 << vertex.block_ordinal << '\t' << vertex.twist_id << '\n';
        }
        traversal_seconds += seconds(traversal_started, Clock::now());
        if (certificate_id % cache_reset_certificates == 0) {
          coordinates.clear_disposable_block_cache();
        }
      }
      hits += generating - new_certificates - hits;
      output << "B\t" << ordinal << "\tordinal\t" << refined << '\t'
             << generating << '\t' << new_certificates << '\t' << hits
             << '\n';
      refined_total += refined;
      generating_total += generating;
      hit_total += hits;
      ++completed_blocks;
      if (stratified) {
        const auto block_finished = Clock::now();
        output << "T\t" << ordinal << '\t'
               << seconds(block_started, block_finished) << '\t'
               << seconds(refinement_started, refinement_finished) << '\t'
               << generation_seconds << '\t' << traversal_seconds << '\t'
               << certificate_id - certificates_before << '\t'
               << owners.size() - owners_before << '\n';
        output.flush();
        std::cout << "progress\t" << completed_blocks << '\t'
                  << ordinals.size() << '\t' << ordinal << '\t'
                  << seconds(block_started, block_finished) << '\t'
                  << certificate_id << '\t' << owners.size() << '\n'
                  << std::flush;
      }
    }
    output.flush();
    if (!output) {
      throw std::runtime_error("failed to finish native ledger transcript");
    }
    const auto finished = Clock::now();
    std::cout << std::fixed << std::setprecision(3)
              << "schema\tm23-native-ledger-benchmark-v1\n"
              << "selection\t" << (stratified ? "stratified" : "contiguous")
              << '\n'
              << "blocks\t" << ordinals.size() << '\n'
              << "refined_vertices\t" << refined_total << '\n'
              << "generating_vertices\t" << generating_total << '\n'
              << "certificates\t" << certificate_id << '\n'
              << "ledger_hits\t" << hit_total << '\n'
              << "owned_vertices\t" << owners.size() << '\n'
              << "initialization_seconds\t" << seconds(started, initialized)
              << '\n'
              << "batch_seconds\t" << seconds(initialized, finished) << '\n'
              << "blocks_per_second\t"
              << static_cast<double>(ordinals.size()) /
                     seconds(initialized, finished)
              << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
