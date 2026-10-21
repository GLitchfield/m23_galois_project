#include "m23_kernel.hpp"

#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <unordered_map>
#include <unordered_set>

int main(int argc, char** argv) {
  try {
    if (argc != 3) {
      throw std::runtime_error(
          "usage: check_m23_generation_masks COORDINATES.bin MASKS.bin");
    }
    const auto coordinates_checkpoint =
        m23::read_coordinate_checkpoint(argv[1]);
    const auto mask_checkpoint =
        m23::read_generation_mask_checkpoint(argv[2]);
    if (coordinates_checkpoint.target_order != 5 ||
        coordinates_checkpoint.target != mask_checkpoint.target ||
        coordinates_checkpoint.target_class_size !=
            mask_checkpoint.target_class_size ||
        coordinates_checkpoint.source_checkpoint_sha256 !=
            mask_checkpoint.source_checkpoint_sha256) {
      throw std::runtime_error(
          "5A coordinate and generation-mask provenance disagree");
    }
    const m23::FixedTargetGenerationMasks masks(
        mask_checkpoint, coordinates_checkpoint.target_pairs);
    std::uint64_t nonzero_masks = 0;
    std::unordered_set<std::uint16_t> distinct_masks;
    for (const auto mask : mask_checkpoint.masks) {
      nonzero_masks += mask != 0;
      distinct_masks.emplace(mask);
    }
    m23::CompressedCoordinateIndex coordinates(
        coordinates_checkpoint.target, coordinates_checkpoint.target_pairs,
        coordinates_checkpoint.right_pairs, coordinates_checkpoint.segments,
        coordinates_checkpoint.relatives,
        coordinates_checkpoint.refinements);
    std::uint64_t tested_tuples = 0;
    std::uint64_t generating_tuples = 0;
    std::uint32_t tested_classes = 0;
    for (const auto& segment : coordinates_checkpoint.segments) {
      if (segment.first_ordinal == 1) {
        continue;
      }
      const auto tables =
          coordinates.build_block_tables(segment.first_ordinal);
      std::unordered_map<std::uint32_t, std::uint32_t> weights;
      for (const auto& row : tables.refinements) {
        const auto [position, inserted] =
            weights.emplace(row.twist_id, row.weight);
        if (!inserted && position->second != row.weight) {
          throw std::runtime_error(
              "one native 5A twist ID has conflicting weights");
        }
      }
      for (const auto& [twist_id, weight] : weights) {
        const auto orbit = coordinates.materialize_vertex(
            {segment.first_ordinal, twist_id, weight});
        for (const auto& tuple : orbit.tuples) {
          ++tested_tuples;
          generating_tuples +=
              masks.generates(tuple, orbit.first_transporter);
        }
      }
      ++tested_classes;
    }
    if (mask_checkpoint.mask_bits != 14 || nonzero_masks != 256284 ||
        distinct_masks.size() != 62 || tested_classes != 16 ||
        tested_tuples != 3089 || generating_tuples != 1626) {
      throw std::runtime_error(
          "native 5A generation-mask census disagrees with GAP certificate: "
          "nonzero=" + std::to_string(nonzero_masks) +
          " distinct=" + std::to_string(distinct_masks.size()) +
          " classes=" + std::to_string(tested_classes) +
          " tuples=" + std::to_string(tested_tuples) +
          " generating=" + std::to_string(generating_tuples));
    }
    std::cout << "native 5A generation masks verified: bits="
              << mask_checkpoint.mask_bits
              << " rows=" << mask_checkpoint.masks.size()
              << " nonzero=" << nonzero_masks
              << " distinct=" << distinct_masks.size()
              << " validation=" << generating_tuples << '/' << tested_tuples
              << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
