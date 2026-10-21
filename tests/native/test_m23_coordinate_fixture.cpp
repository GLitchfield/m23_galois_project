#include "m23_kernel.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

struct ImageRecord {
  std::size_t source_position{};
  int generator{};
  m23::Tuple4 tuple;
  m23::PairTwistVertex vertex;
};

struct Fixture {
  std::uint32_t target_order{};
  std::uint64_t target_class_size{};
  std::string source_checkpoint_sha256;
  std::string gap_version;
  bool source_generating{};
  bool saw_source_generating = false;
  m23::Permutation target;
  m23::Permutation first_transporter;
  bool saw_target = false;
  bool saw_first_transporter = false;
  m23::PairTwistVertex source_vertex;
  std::vector<m23::Tuple4> sources;
  std::vector<ImageRecord> images;
  std::vector<m23::PairTwistVertex> neighbors;
  std::vector<m23::TargetPairEntry> target_pairs;
  std::vector<m23::RightPairEntry> right_pairs;
  std::vector<m23::MacroblockSegmentEntry> segments;
  std::vector<m23::RelativeEntry> relatives;
  std::vector<m23::RefinementEntry> refinements;
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

m23::Permutation parse_permutation(const std::string& text) {
  m23::Permutation result;
  std::istringstream input(text);
  std::string value;
  std::size_t position = 0;
  while (std::getline(input, value, ',')) {
    if (position >= m23::degree) {
      throw std::runtime_error("permutation has too many images");
    }
    const auto image = parse_u32(value);
    if (image < 1 || image > m23::degree) {
      throw std::runtime_error("permutation image is outside [1,23]");
    }
    result.image[position++] = static_cast<std::uint8_t>(image - 1);
  }
  if (position != m23::degree || !result.valid()) {
    throw std::runtime_error("invalid degree-23 permutation");
  }
  return result;
}

m23::Tuple4 parse_tuple(const std::vector<std::string>& fields,
                        const std::size_t first) {
  return {parse_permutation(fields.at(first)),
          parse_permutation(fields.at(first + 1)),
          parse_permutation(fields.at(first + 2)),
          parse_permutation(fields.at(first + 3))};
}

m23::PairTwistVertex parse_vertex(const std::vector<std::string>& fields,
                                  const std::size_t first) {
  return {parse_u64(fields.at(first)), parse_u32(fields.at(first + 1)),
          parse_u32(fields.at(first + 2))};
}

Fixture read_fixture(const std::string& path) {
  std::ifstream input(path);
  if (!input) {
    throw std::runtime_error("cannot open fixture: " + path);
  }
  Fixture fixture;
  bool saw_schema = false;
  bool saw_source_vertex = false;
  std::string line;
  while (std::getline(input, line)) {
    if (line.empty()) {
      continue;
    }
    const auto fields = split_tabs(line);
    if (fields[0] == "# schema") {
      if (fields.size() != 2 ||
          fields[1] != "m23-native-coordinate-fixture-v1") {
        throw std::runtime_error("unsupported coordinate fixture schema");
      }
      saw_schema = true;
    } else if (fields[0] == "# target_order") {
      if (fields.size() != 2) {
        throw std::runtime_error("invalid target_order metadata");
      }
      fixture.target_order = parse_u32(fields[1]);
    } else if (fields[0] == "# target_class_size") {
      if (fields.size() != 2) {
        throw std::runtime_error("invalid target_class_size metadata");
      }
      fixture.target_class_size = parse_u64(fields[1]);
    } else if (fields[0] == "# source_checkpoint_sha256") {
      if (fields.size() != 2) {
        throw std::runtime_error("invalid source checkpoint metadata");
      }
      fixture.source_checkpoint_sha256 = fields[1];
    } else if (fields[0] == "# gap_version") {
      if (fields.size() != 2) {
        throw std::runtime_error("invalid GAP version metadata");
      }
      fixture.gap_version = fields[1];
    } else if (fields[0] == "# source_generating") {
      if (fields.size() != 2 || fixture.saw_source_generating ||
          (fields[1] != "true" && fields[1] != "false")) {
        throw std::runtime_error("invalid source_generating metadata");
      }
      fixture.source_generating = fields[1] == "true";
      fixture.saw_source_generating = true;
    } else if (fields[0] == "# source_vertex") {
      if (fields.size() != 4) {
        throw std::runtime_error("invalid source_vertex metadata");
      }
      fixture.source_vertex = parse_vertex(fields, 1);
      saw_source_vertex = true;
    } else if (fields[0].front() == '#') {
      continue;
    } else if (fields[0] == "target") {
      if (fields.size() != 2 || fixture.saw_target) {
        throw std::runtime_error("invalid or repeated target row");
      }
      fixture.target = parse_permutation(fields[1]);
      fixture.saw_target = true;
    } else if (fields[0] == "first_transport") {
      if (fields.size() != 2 || fixture.saw_first_transporter) {
        throw std::runtime_error("invalid or repeated first_transport row");
      }
      fixture.first_transporter = parse_permutation(fields[1]);
      fixture.saw_first_transporter = true;
    } else if (fields[0] == "source") {
      if (fields.size() != 6 ||
          parse_u64(fields[1]) != fixture.sources.size() + 1) {
        throw std::runtime_error("invalid or unordered source row");
      }
      fixture.sources.push_back(parse_tuple(fields, 2));
    } else if (fields[0] == "image") {
      if (fields.size() != 10) {
        throw std::runtime_error("invalid image row");
      }
      fixture.images.push_back(
          {static_cast<std::size_t>(parse_u64(fields[1])),
           static_cast<int>(parse_u32(fields[2])), parse_tuple(fields, 3),
           parse_vertex(fields, 7)});
    } else if (fields[0] == "neighbor") {
      if (fields.size() != 5 ||
          parse_u64(fields[1]) != fixture.neighbors.size() + 1) {
        throw std::runtime_error("invalid or unordered neighbor row");
      }
      fixture.neighbors.push_back(parse_vertex(fields, 2));
    } else if (fields[0] == "target_pair") {
      if (fields.size() != 7) {
        throw std::runtime_error("invalid target_pair row");
      }
      fixture.target_pairs.push_back(
          {parse_permutation(fields[1]),
           {parse_u32(fields[2]), parse_u32(fields[3]),
            parse_permutation(fields[4]),
            {parse_permutation(fields[5]), parse_permutation(fields[6])}}});
    } else if (fields[0] == "right_pair") {
      if (fields.size() != 6) {
        throw std::runtime_error("invalid right_pair row");
      }
      fixture.right_pairs.push_back(
          {{parse_u32(fields[1]),
            {parse_permutation(fields[2]), parse_permutation(fields[3])}},
           {parse_u32(fields[4]), parse_permutation(fields[5])}});
    } else if (fields[0] == "segment") {
      if (fields.size() != 4) {
        throw std::runtime_error("invalid segment row");
      }
      fixture.segments.push_back(
          {parse_u32(fields[1]), parse_u64(fields[2]), parse_u32(fields[3])});
    } else if (fields[0] == "relative") {
      if (fields.size() != 4) {
        throw std::runtime_error("invalid relative row");
      }
      fixture.relatives.push_back(
          {{parse_u64(fields[1]), parse_permutation(fields[2])},
           parse_u32(fields[3])});
    } else if (fields[0] == "refinement") {
      if (fields.size() != 5) {
        throw std::runtime_error("invalid refinement row");
      }
      fixture.refinements.push_back(
          {{parse_u64(fields[1]), parse_u32(fields[2])},
           parse_u32(fields[3]), parse_u32(fields[4])});
    } else {
      throw std::runtime_error("unknown fixture row: " + fields[0]);
    }
  }
  if (!saw_schema || !saw_source_vertex || !fixture.saw_target ||
      !fixture.saw_first_transporter || !fixture.saw_source_generating) {
    throw std::runtime_error("coordinate fixture metadata is incomplete");
  }
  return fixture;
}

void require(const bool condition, const std::string& message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 4) {
      throw std::runtime_error(
          "usage: test_m23_coordinate_fixture FIXTURE.tsv CHECKPOINT.bin "
          "GLOBAL_CHECKPOINT.bin");
    }
    const auto fixture = read_fixture(argv[1]);
    require(fixture.target_order > 0,
            "coordinate fixture has no target class order");
    require(fixture.sources.size() == fixture.source_vertex.weight,
            "source orbit size disagrees with its GAP weight");
    require(fixture.images.size() == fixture.sources.size() * 2,
            "each source tuple must have beta13 and beta14 images");

    std::vector<m23::ExactCoordinateEntry> entries;
    entries.reserve(fixture.images.size());
    for (const auto& image : fixture.images) {
      require(image.source_position >= 1 &&
                  image.source_position <= fixture.sources.size(),
              "image source position is outside the source orbit");
      require(image.generator == 13 || image.generator == 14,
              "fixture contains an unsupported neighbor generator");
      const auto& source = fixture.sources[image.source_position - 1];
      require(std::all_of(source.begin(), source.end(), [&](const auto& entry) {
                return m23::order(entry) == fixture.target_order;
              }),
              "source tuple leaves the target conjugacy-class order");
      require(m23::product(source) == m23::Permutation::identity(),
              "source fixture tuple is not product one");
      require(m23::pure_braid_move(source, image.generator) == image.tuple,
              "native pure braid image disagrees with GAP");
      require(m23::product(image.tuple) == m23::Permutation::identity(),
              "native pure braid image is not product one");
      entries.push_back({image.tuple, image.vertex});
    }

    const m23::ExactCoordinateIndex coordinates(entries);
    const auto actual = m23::pair_twist_neighbors(fixture.sources, coordinates);
    require(actual == fixture.neighbors,
            "native coordinate lookup/deduplication disagrees with GAP");
    const m23::CompressedCoordinateIndex compressed_coordinates(
        fixture.target, fixture.target_pairs, fixture.right_pairs,
        fixture.segments, fixture.relatives, fixture.refinements);
    const auto compressed_actual = m23::pair_twist_neighbors(
        fixture.sources, fixture.first_transporter, compressed_coordinates);
    require(compressed_actual == fixture.neighbors,
            "native compressed coordinate pipeline disagrees with GAP");
    const auto global_checkpoint = m23::read_coordinate_checkpoint(argv[3]);
    m23::CompressedCoordinateIndex lazy_coordinates(
        global_checkpoint.target, global_checkpoint.target_pairs,
        global_checkpoint.right_pairs, global_checkpoint.segments,
        global_checkpoint.relatives, global_checkpoint.refinements);
    std::vector<std::uint64_t> destination_blocks;
    std::vector<std::pair<m23::PairTwistVertex, m23::PairTwistVertex>>
        stable_twist_translation;
    for (const auto& expected : fixture.relatives) {
      if (std::find(destination_blocks.begin(), destination_blocks.end(),
                    expected.key.block_ordinal) == destination_blocks.end()) {
        destination_blocks.push_back(expected.key.block_ordinal);
        const auto generated = lazy_coordinates.build_block_tables(
            expected.key.block_ordinal);
        lazy_coordinates.add_relative_entries(generated.relatives);
        lazy_coordinates.add_refinement_entries(generated.refinements);
        for (const auto& gap_row : fixture.refinements) {
          if (gap_row.key.block_ordinal != expected.key.block_ordinal) {
            continue;
          }
          const auto native_row = std::find_if(
              generated.refinements.begin(), generated.refinements.end(),
              [&](const auto& row) { return row.key == gap_row.key; });
          require(native_row != generated.refinements.end() &&
                      native_row->weight == gap_row.weight,
                  "native stable refinement changes a GAP orbit weight");
          const m23::PairTwistVertex gap_vertex{
              gap_row.key.block_ordinal, gap_row.twist_id, gap_row.weight};
          const m23::PairTwistVertex native_vertex{
              native_row->key.block_ordinal, native_row->twist_id,
              native_row->weight};
          const auto known = std::find_if(
              stable_twist_translation.begin(),
              stable_twist_translation.end(), [&](const auto& item) {
                return item.first == gap_vertex;
              });
          if (known == stable_twist_translation.end()) {
            stable_twist_translation.emplace_back(gap_vertex, native_vertex);
          } else {
            require(known->second == native_vertex,
                    "one GAP twist orbit maps to multiple stable native IDs");
          }
        }
      }
    }
    for (const auto& expected : fixture.relatives) {
      const auto generated = lazy_coordinates.build_relative_entries(
          expected.key.block_ordinal);
      const auto position = std::find_if(
          generated.begin(), generated.end(), [&](const auto& row) {
            return row.key == expected.key;
          });
      require(position != generated.end() &&
                  position->relative_index == expected.relative_index,
              "native lazy relative map disagrees with GAP key-v2 indexing");
    }
    std::vector<m23::PairTwistVertex> stable_expected;
    for (const auto& gap_neighbor : fixture.neighbors) {
      const auto translation = std::find_if(
          stable_twist_translation.begin(), stable_twist_translation.end(),
          [&](const auto& item) { return item.first == gap_neighbor; });
      require(translation != stable_twist_translation.end(),
              "fixture does not expose a stable ID for one GAP neighbor");
      stable_expected.push_back(translation->second);
    }
    std::sort(stable_expected.begin(), stable_expected.end(),
              [](const auto& left, const auto& right) {
                return left.block_ordinal < right.block_ordinal ||
                       (left.block_ordinal == right.block_ordinal &&
                        left.twist_id < right.twist_id);
              });
    require(m23::pair_twist_neighbors(fixture.sources,
                                      fixture.first_transporter,
                                      lazy_coordinates) == stable_expected,
            "native lazy relative maps change the compressed pipeline");
    m23::CoordinateCheckpoint checkpoint{
        fixture.target_order,
        fixture.target_class_size,
        fixture.source_checkpoint_sha256,
        "0000000000000000000000000000000000000000",
        fixture.gap_version,
        fixture.target,
        fixture.target_pairs,
        fixture.right_pairs,
        fixture.segments,
        {},
        {}};
    m23::write_coordinate_checkpoint(argv[2], checkpoint);
    const auto loaded = m23::read_coordinate_checkpoint(argv[2]);
    require(loaded.target_order == checkpoint.target_order &&
                loaded.target_class_size == checkpoint.target_class_size &&
                loaded.source_checkpoint_sha256 ==
                    checkpoint.source_checkpoint_sha256 &&
                loaded.source_git_revision == checkpoint.source_git_revision &&
                loaded.gap_version == checkpoint.gap_version &&
                loaded.target_pairs.size() == checkpoint.target_pairs.size() &&
                loaded.right_pairs.size() == checkpoint.right_pairs.size() &&
                loaded.segments.size() == checkpoint.segments.size() &&
                loaded.relatives.size() == checkpoint.relatives.size() &&
                loaded.refinements.size() == checkpoint.refinements.size(),
            "binary coordinate checkpoint metadata or counts changed");
    m23::CompressedCoordinateIndex loaded_coordinates(
        loaded.target, loaded.target_pairs, loaded.right_pairs, loaded.segments,
        loaded.relatives, loaded.refinements);
    loaded_coordinates.add_relative_entries(fixture.relatives);
    loaded_coordinates.add_refinement_entries(fixture.refinements);
    require(m23::pair_twist_neighbors(fixture.sources,
                                      fixture.first_transporter,
                                      loaded_coordinates) == fixture.neighbors,
            "binary coordinate checkpoint changes the native pipeline");
    auto repeated_sources = fixture.sources;
    repeated_sources.insert(repeated_sources.end(), fixture.sources.begin(),
                            fixture.sources.end());
    require(m23::pair_twist_neighbors(repeated_sources, coordinates) == actual,
            "native first-seen duplicate removal is not stable");
    require(m23::pair_twist_neighbors(repeated_sources,
                                      fixture.first_transporter,
                                      compressed_coordinates) == actual,
            "compressed first-seen duplicate removal is not stable");
    std::cout << "native order-" << fixture.target_order
              << " coordinate micro-checkpoint verified: source_weight="
              << fixture.source_vertex.weight
              << " neighbors=" << actual.size() << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
