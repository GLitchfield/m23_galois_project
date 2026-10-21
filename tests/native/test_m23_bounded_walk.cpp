#include "m23_kernel.hpp"

#include <algorithm>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

struct Fixture {
  std::uint64_t limit{};
  std::uint64_t checked_vertex_count{};
  std::uint64_t discovered_vertex_count{};
  std::uint64_t discovered_class_count{};
  m23::BoundedWalkStatus status{};
  std::vector<m23::PairTwistVertex> vertices;
  bool saw_schema = false;
  bool saw_limit = false;
  bool saw_status = false;
  bool saw_checked = false;
  bool saw_class_count = false;
  bool saw_vertex_count = false;
};

std::vector<std::string> split_tabs(const std::string& line) {
  std::vector<std::string> fields;
  std::istringstream input(line);
  std::string field;
  while (std::getline(input, field, '\t')) {
    fields.push_back(field);
  }
  return fields;
}

std::uint64_t parse_u64(const std::string& text) {
  std::size_t consumed = 0;
  const auto result = std::stoull(text, &consumed);
  if (consumed != text.size()) {
    throw std::runtime_error("invalid unsigned integer: " + text);
  }
  return result;
}

std::uint32_t parse_u32(const std::string& text) {
  const auto result = parse_u64(text);
  if (result > UINT32_MAX) {
    throw std::runtime_error("integer exceeds uint32 range: " + text);
  }
  return static_cast<std::uint32_t>(result);
}

Fixture read_fixture(const std::string& path) {
  std::ifstream input(path);
  if (!input) {
    throw std::runtime_error("cannot open bounded-walk fixture: " + path);
  }
  Fixture result;
  std::string line;
  while (std::getline(input, line)) {
    if (line.empty()) {
      continue;
    }
    const auto fields = split_tabs(line);
    if (fields[0] == "# schema") {
      if (fields.size() != 2 || result.saw_schema ||
          fields[1] != "m23-native-bounded-walk-fixture-v1") {
        throw std::runtime_error("unsupported bounded-walk fixture schema");
      }
      result.saw_schema = true;
    } else if (fields[0] == "# limit") {
      if (fields.size() != 2 || result.saw_limit) {
        throw std::runtime_error("invalid bounded-walk limit metadata");
      }
      result.limit = parse_u64(fields[1]);
      result.saw_limit = true;
    } else if (fields[0] == "# status") {
      if (fields.size() != 2 || result.saw_status ||
          (fields[1] != "closed" && fields[1] != "overflow")) {
        throw std::runtime_error("invalid bounded-walk status metadata");
      }
      result.status = fields[1] == "closed"
                          ? m23::BoundedWalkStatus::closed
                          : m23::BoundedWalkStatus::overflow;
      result.saw_status = true;
    } else if (fields[0] == "# checked_vertex_count") {
      if (fields.size() != 2 || result.saw_checked) {
        throw std::runtime_error("invalid checked-vertex metadata");
      }
      result.checked_vertex_count = parse_u64(fields[1]);
      result.saw_checked = true;
    } else if (fields[0] == "# discovered_vertex_count") {
      if (fields.size() != 2 || result.saw_vertex_count ||
          parse_u64(fields[1]) > SIZE_MAX) {
        throw std::runtime_error("invalid discovered-vertex metadata");
      }
      result.discovered_vertex_count = parse_u64(fields[1]);
      result.vertices.reserve(
          static_cast<std::size_t>(result.discovered_vertex_count));
      result.saw_vertex_count = true;
    } else if (fields[0] == "# discovered_class_count") {
      if (fields.size() != 2 || result.saw_class_count) {
        throw std::runtime_error("invalid discovered-class metadata");
      }
      result.discovered_class_count = parse_u64(fields[1]);
      result.saw_class_count = true;
    } else if (fields[0].front() == '#') {
      continue;
    } else if (fields[0] == "vertex") {
      if (fields.size() != 5 ||
          parse_u64(fields[1]) != result.vertices.size() + 1) {
        throw std::runtime_error("invalid or unordered bounded-walk vertex");
      }
      result.vertices.push_back({parse_u64(fields[2]), parse_u32(fields[3]),
                                 parse_u32(fields[4])});
    } else {
      throw std::runtime_error("unknown bounded-walk fixture row");
    }
  }
  if (!result.saw_schema || !result.saw_limit || !result.saw_status ||
      !result.saw_checked || !result.saw_vertex_count ||
      !result.saw_class_count || result.vertices.empty() ||
      result.vertices.size() != result.discovered_vertex_count) {
    throw std::runtime_error("bounded-walk fixture metadata is incomplete");
  }
  return result;
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 3) {
      throw std::runtime_error(
          "usage: test_m23_bounded_walk FIXTURE.tsv CHECKPOINT.bin");
    }
    const auto fixture = read_fixture(argv[1]);
    const auto checkpoint = m23::read_coordinate_checkpoint(argv[2]);
    m23::CompressedCoordinateIndex coordinates(
        checkpoint.target, checkpoint.target_pairs, checkpoint.right_pairs,
        checkpoint.segments, checkpoint.relatives, checkpoint.refinements);
    const auto actual = m23::bounded_pair_twist_walk(
        coordinates, fixture.vertices.front(), fixture.limit);
    if (actual.status != fixture.status ||
        actual.checked_vertex_count != fixture.checked_vertex_count ||
        actual.discovered_class_count != fixture.discovered_class_count ||
        actual.vertices != fixture.vertices) {
      throw std::runtime_error(
          "native bounded quotient walk disagrees with GAP orbit membership");
    }
    const auto block_vertices =
        coordinates.block_vertices(fixture.vertices.front().block_ordinal);
    const auto source_position = std::find(
        block_vertices.begin(), block_vertices.end(), fixture.vertices.front());
    if (source_position == block_vertices.end()) {
      throw std::runtime_error(
          "native block enumeration omits the bounded-walk seed");
    }
    if (fixture.vertices.size() > 1) {
      const auto linked = m23::bounded_pair_twist_walk_with_lookup(
          coordinates, fixture.vertices.front(), fixture.limit,
          [&](const m23::PairTwistVertex& vertex)
              -> std::optional<std::uint64_t> {
            return vertex == fixture.vertices[1]
                       ? std::optional<std::uint64_t>{7}
                       : std::nullopt;
          });
      if (linked.status != m23::BoundedWalkStatus::linked ||
          linked.linked_certificate != 7 || linked.checked_vertex_count != 1 ||
          linked.vertices.size() != 1 ||
          linked.vertices.front() != fixture.vertices.front()) {
        throw std::runtime_error(
            "native external ownership lookup disagrees with GAP semantics");
      }
    }
    coordinates.clear_disposable_block_cache();
    const auto rebuilt_vertices =
        coordinates.block_vertices(fixture.vertices.front().block_ordinal);
    if (rebuilt_vertices != block_vertices) {
      throw std::runtime_error(
          "native block cache reset changed stable refinement coordinates");
    }
    std::cout << "native bounded quotient walk verified: checked="
              << actual.checked_vertex_count
              << " vertices=" << actual.vertices.size()
              << " classes=" << actual.discovered_class_count << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
