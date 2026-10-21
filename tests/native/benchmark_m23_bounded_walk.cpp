#include "m23_kernel.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
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

double milliseconds(const Clock::time_point start,
                    const Clock::time_point finish) {
  return std::chrono::duration<double, std::milli>(finish - start).count();
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 7) {
      throw std::runtime_error(
          "usage: benchmark_m23_bounded_walk CHECKPOINT BLOCK TWIST WEIGHT "
          "LIMIT REPEATS");
    }
    const auto block = parse_u64(argv[2], "block ordinal");
    const auto twist = parse_u64(argv[3], "twist ID");
    const auto weight = parse_u64(argv[4], "weight");
    const auto limit = parse_u64(argv[5], "walk limit");
    const auto repeats = parse_u64(argv[6], "repeat count");
    if (block == 0 || twist == 0 || weight == 0 || limit == 0 ||
        repeats == 0 || twist > std::numeric_limits<std::uint32_t>::max() ||
        weight > std::numeric_limits<std::uint32_t>::max() ||
        repeats > std::numeric_limits<std::size_t>::max()) {
      throw std::runtime_error("benchmark arguments are out of range");
    }

    const auto load_start = Clock::now();
    const auto checkpoint = m23::read_coordinate_checkpoint(argv[1]);
    const auto load_finish = Clock::now();
    const auto index_start = Clock::now();
    m23::CompressedCoordinateIndex coordinates(
        checkpoint.target, checkpoint.target_pairs, checkpoint.right_pairs,
        checkpoint.segments, checkpoint.relatives, checkpoint.refinements);
    const auto index_finish = Clock::now();

    const m23::PairTwistVertex seed{
        block, static_cast<std::uint32_t>(twist),
        static_cast<std::uint32_t>(weight)};
    std::vector<double> walk_ms;
    walk_ms.reserve(static_cast<std::size_t>(repeats));
    m23::BoundedWalkResult reference;
    for (std::uint64_t repetition = 0; repetition < repeats; ++repetition) {
      const auto walk_start = Clock::now();
      const auto result =
          m23::bounded_pair_twist_walk(coordinates, seed, limit);
      const auto walk_finish = Clock::now();
      if (repetition == 0) {
        reference = result;
      } else if (result.status != reference.status ||
                 result.checked_vertex_count !=
                     reference.checked_vertex_count ||
                 result.discovered_class_count !=
                     reference.discovered_class_count ||
                 result.vertices != reference.vertices) {
        throw std::runtime_error("repeated native walks disagree");
      }
      walk_ms.push_back(milliseconds(walk_start, walk_finish));
    }
    const auto sorted_ms = [&walk_ms] {
      auto values = walk_ms;
      std::sort(values.begin(), values.end());
      return values;
    }();
    const auto median_ms = sorted_ms[sorted_ms.size() / 2];
    const auto warm_begin = walk_ms.size() > 1 ? walk_ms.begin() + 1
                                               : walk_ms.begin();
    const auto warm_min = *std::min_element(warm_begin, walk_ms.end());

    std::cout << std::fixed << std::setprecision(3)
              << "schema\tm23-native-bounded-walk-benchmark-v1\n"
              << "target_order\t" << checkpoint.target_order << '\n'
              << "source_checkpoint_sha256\t"
              << checkpoint.source_checkpoint_sha256 << '\n'
              << "source_git_revision\t" << checkpoint.source_git_revision
              << '\n'
              << "gap_version\t" << checkpoint.gap_version << '\n'
              << "seed\t" << block << '\t' << twist << '\t' << weight
              << '\n'
              << "limit\t" << limit << '\n'
              << "repeats\t" << repeats << '\n'
              << "load_ms\t" << milliseconds(load_start, load_finish) << '\n'
              << "index_ms\t" << milliseconds(index_start, index_finish)
              << '\n'
              << "cold_walk_ms\t" << walk_ms.front() << '\n'
              << "median_walk_ms\t" << median_ms << '\n'
              << "warm_min_walk_ms\t" << warm_min << '\n'
              << "status\t"
              << (reference.status == m23::BoundedWalkStatus::closed
                      ? "closed"
                      : "overflow")
              << '\n'
              << "checked_vertices\t" << reference.checked_vertex_count
              << '\n'
              << "discovered_vertices\t" << reference.vertices.size()
              << '\n'
              << "discovered_classes\t"
              << reference.discovered_class_count << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
