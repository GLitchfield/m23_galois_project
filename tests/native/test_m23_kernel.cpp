#include "m23_kernel.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

m23::Permutation parse_permutation(const std::string& text) {
  m23::Permutation result;
  std::istringstream input(text);
  std::string value;
  std::size_t position = 0;
  while (std::getline(input, value, ',')) {
    if (position >= m23::degree) {
      throw std::runtime_error("permutation has too many images");
    }
    const auto image = std::stoi(value);
    if (image < 1 || image > static_cast<int>(m23::degree)) {
      throw std::runtime_error("permutation image is outside [1,23]");
    }
    result.image[position++] = static_cast<std::uint8_t>(image - 1);
  }
  if (position != m23::degree || !result.valid()) {
    throw std::runtime_error("invalid degree-23 permutation");
  }
  return result;
}

std::vector<std::string> split_tabs(const std::string& line) {
  std::vector<std::string> fields;
  std::istringstream input(line);
  std::string field;
  while (std::getline(input, field, '\t')) {
    fields.push_back(field);
  }
  return fields;
}

std::unordered_map<std::string, m23::Tuple4> read_fixture(const std::string& path) {
  std::ifstream input(path);
  if (!input) {
    throw std::runtime_error("cannot open fixture: " + path);
  }
  std::unordered_map<std::string, m23::Tuple4> rows;
  std::string line;
  while (std::getline(input, line)) {
    if (line.empty() || line.front() == '#' || line.starts_with("name\t")) {
      continue;
    }
    const auto fields = split_tabs(line);
    if (fields.size() != 5) {
      throw std::runtime_error("fixture row must have five fields");
    }
    rows.emplace(fields[0], m23::Tuple4{parse_permutation(fields[1]),
                                        parse_permutation(fields[2]),
                                        parse_permutation(fields[3]),
                                        parse_permutation(fields[4])});
  }
  return rows;
}

m23::Tuple4 apply_word(m23::Tuple4 tuple, const std::vector<int>& word) {
  for (const auto letter : word) {
    tuple = letter > 0 ? m23::hurwitz_move(tuple, letter)
                       : m23::inverse_hurwitz_move(tuple, -letter);
  }
  return tuple;
}

void require(const bool condition, const std::string& message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

void verify_pure_case(
    const std::unordered_map<std::string, m23::Tuple4>& rows,
    const std::string& prefix) {
  const auto& input = rows.at(prefix + "input");
  const auto identity = m23::Permutation::identity();
  require(m23::product(input) == identity,
          prefix + "input tuple is not product one");
  const std::array<int, 3> generators{12, 13, 14};
  const std::array<std::string, 3> names{"beta12", "beta13", "beta14"};
  const std::array<std::vector<int>, 3> words{
      std::vector<int>{2, 2}, std::vector<int>{-2, 3, 3, 2},
      std::vector<int>{-2, -3, 4, 4, 3, 2}};
  for (std::size_t index = 0; index < generators.size(); ++index) {
    const auto direct = m23::pure_braid_move(input, generators[index]);
    require(direct == rows.at(prefix + names[index]),
            prefix + names[index] + " disagrees with GAP");
    require(direct == apply_word(input, words[index]),
            prefix + names[index] +
                " direct formula disagrees with Hurwitz word");
    require(m23::product(direct) == identity,
            prefix + names[index] + " failed to preserve product one");
  }
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 2) {
      throw std::runtime_error("usage: test_m23_kernel FIXTURE.tsv");
    }
    const auto rows = read_fixture(argv[1]);
    const auto& input = rows.at("input");
    require(std::all_of(input.begin(), input.end(), [](const auto& entry) {
              return m23::order(entry) == 3;
            }),
            "Seguin fixture has the wrong native permutation orders");
    require(m23::hurwitz_move(input, 3) == rows.at("hurwitz3"),
            "Hurwitz move disagrees with GAP");
    require(m23::inverse_hurwitz_move(input, 3) == rows.at("inverse_hurwitz3"),
            "inverse Hurwitz move disagrees with GAP");
    require(m23::inverse_hurwitz_move(m23::hurwitz_move(input, 3), 3) == input,
            "Hurwitz move and inverse do not cancel");

    verify_pure_case(rows, "");
    verify_pure_case(rows, "4a_");
    const std::array<std::uint32_t, 4> expected_4a_orders{4, 4, 2, 2};
    const auto& input_4a = rows.at("4a_input");
    for (std::size_t index = 0; index < input_4a.size(); ++index) {
      require(m23::order(input_4a[index]) == expected_4a_orders[index],
              "4A bridge fixture has the wrong native permutation orders");
    }
    const auto probe = m23::hurwitz_move(input, 3);
    require(m23::pure_braid_move(probe, 12) == rows.at("probe_beta12"),
            "nontrivial beta12 probe disagrees with GAP");
    std::cout << "native M23 permutation/Hurwitz kernel verified\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
