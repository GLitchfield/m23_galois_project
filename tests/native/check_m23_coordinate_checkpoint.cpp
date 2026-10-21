#include "m23_kernel.hpp"

#include <filesystem>
#include <iostream>
#include <stdexcept>

int main(int argc, char** argv) {
  try {
    if (argc != 2) {
      throw std::runtime_error(
          "usage: check_m23_coordinate_checkpoint CHECKPOINT.bin");
    }
    const auto checkpoint = m23::read_coordinate_checkpoint(argv[1]);
    if (checkpoint.target_order == 0 || checkpoint.target_class_size == 0 ||
        checkpoint.source_checkpoint_sha256.size() != 64 ||
        checkpoint.source_git_revision.size() != 40 ||
        checkpoint.gap_version.empty()) {
      throw std::runtime_error("coordinate checkpoint metadata is incomplete");
    }
    const m23::CompressedCoordinateIndex index(
        checkpoint.target, checkpoint.target_pairs, checkpoint.right_pairs,
        checkpoint.segments, checkpoint.relatives, checkpoint.refinements);
    std::uint64_t reconstructed_rows = 0;
    std::uint64_t reconstructed_refinement_rows = 0;
    std::uint32_t reconstructed_classes = 0;
    for (const auto& segment : checkpoint.segments) {
      // The identity-product class is the unique symbolic first block and has
      // a separate canonical-inner-tuple coordinate path in GAP.
      if (segment.first_ordinal == 1) {
        continue;
      }
      const auto tables = index.build_block_tables(segment.first_ordinal);
      if (tables.relatives.empty()) {
        throw std::runtime_error(
            "native relative reconstruction produced an empty class");
      }
      reconstructed_rows += tables.relatives.size();
      reconstructed_refinement_rows += tables.refinements.size();
      ++reconstructed_classes;
    }
    std::cout << "schema\t1\n"
              << "target_order\t" << checkpoint.target_order << '\n'
              << "target_class_size\t" << checkpoint.target_class_size << '\n'
              << "target_pair_rows\t" << checkpoint.target_pairs.size() << '\n'
              << "right_pair_rows\t" << checkpoint.right_pairs.size() << '\n'
              << "segment_rows\t" << checkpoint.segments.size() << '\n'
              << "relative_rows\t" << checkpoint.relatives.size() << '\n'
              << "refinement_rows\t" << checkpoint.refinements.size() << '\n'
              << "reconstructed_classes\t" << reconstructed_classes << '\n'
              << "reconstructed_sample_rows\t" << reconstructed_rows << '\n'
              << "reconstructed_sample_refinements\t"
              << reconstructed_refinement_rows << '\n'
              << "source_checkpoint_sha256\t"
              << checkpoint.source_checkpoint_sha256 << '\n'
              << "source_git_revision\t" << checkpoint.source_git_revision
              << '\n'
              << "gap_version\t" << checkpoint.gap_version << '\n'
              << "bytes\t" << std::filesystem::file_size(argv[1]) << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
