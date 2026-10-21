#include <cuda_runtime.h>

#include <chrono>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

constexpr int degree = 23;

struct Permutation {
  std::uint8_t image[degree];
};

struct Tuple4 {
  Permutation entries[4];
};

struct InputRow {
  Tuple4 tuple;
  Permutation first_transporter;
};

struct FixedDestination {
  Permutation entries[3];
};

static_assert(sizeof(Permutation) == degree);
static_assert(sizeof(Tuple4) == 4 * degree);
static_assert(sizeof(InputRow) == 5 * degree);
static_assert(sizeof(FixedDestination) == 3 * degree);

#define M23_HD __host__ __device__

M23_HD Permutation compose(const Permutation& left,
                           const Permutation& right) {
  Permutation result{};
  for (int point = 0; point < degree; ++point) {
    result.image[point] = right.image[left.image[point]];
  }
  return result;
}

M23_HD Permutation inverse(const Permutation& value) {
  Permutation result{};
  for (int point = 0; point < degree; ++point) {
    result.image[value.image[point]] = static_cast<std::uint8_t>(point);
  }
  return result;
}

M23_HD Permutation conjugate(const Permutation& value,
                             const Permutation& by) {
  return compose(compose(inverse(by), value), by);
}

M23_HD Tuple4 beta13(const Tuple4& tuple) {
  Tuple4 result = tuple;
  result.entries[0] = conjugate(
      tuple.entries[0], compose(tuple.entries[1], tuple.entries[3]));
  result.entries[2] = conjugate(
      tuple.entries[2], compose(tuple.entries[3], tuple.entries[1]));
  return result;
}

M23_HD Tuple4 beta14(const Tuple4& tuple) {
  Tuple4 result = tuple;
  const auto by = compose(tuple.entries[1], tuple.entries[2]);
  result.entries[0] = conjugate(tuple.entries[0], by);
  result.entries[3] = conjugate(tuple.entries[3], by);
  return result;
}

M23_HD FixedDestination fixed_destination(const InputRow& input,
                                          const int generator) {
  const auto conjugator = generator == 13
      ? compose(input.tuple.entries[1], input.tuple.entries[3])
      : compose(input.tuple.entries[1], input.tuple.entries[2]);
  const auto moved = generator == 13 ? beta13(input.tuple) : beta14(input.tuple);
  const auto moved_transporter =
      compose(inverse(conjugator), input.first_transporter);
  FixedDestination result{};
  for (int entry = 1; entry < 4; ++entry) {
    result.entries[entry - 1] =
        conjugate(moved.entries[entry], moved_transporter);
  }
  return result;
}

__global__ void destination_images(const InputRow* input,
                                   FixedDestination* output13,
                                   FixedDestination* output14,
                                   const std::uint64_t count) {
  const auto index = static_cast<std::uint64_t>(blockIdx.x) * blockDim.x +
                     threadIdx.x;
  if (index < count) {
    output13[index] = fixed_destination(input[index], 13);
    output14[index] = fixed_destination(input[index], 14);
  }
}

void cuda_check(const cudaError_t status, const char* operation) {
  if (status != cudaSuccess) {
    throw std::runtime_error(std::string(operation) + ": " +
                             cudaGetErrorString(status));
  }
}

std::vector<std::string> split(const std::string& value, const char separator) {
  std::vector<std::string> result;
  std::istringstream input(value);
  std::string field;
  while (std::getline(input, field, separator)) {
    result.push_back(field);
  }
  return result;
}

Permutation parse_permutation(const std::string& value) {
  const auto fields = split(value, ',');
  if (fields.size() != degree) {
    throw std::runtime_error("fixture permutation has the wrong degree");
  }
  Permutation result{};
  std::uint32_t seen = 0;
  for (int point = 0; point < degree; ++point) {
    const auto image = std::stoul(fields[point]);
    if (image < 1 || image > degree ||
        (seen & (std::uint32_t{1} << (image - 1))) != 0) {
      throw std::runtime_error("fixture permutation is invalid");
    }
    seen |= std::uint32_t{1} << (image - 1);
    result.image[point] = static_cast<std::uint8_t>(image - 1);
  }
  return result;
}

std::unordered_map<std::string, Tuple4> read_fixture(const std::string& path) {
  std::ifstream input(path);
  if (!input) {
    throw std::runtime_error("cannot open native kernel fixture");
  }
  std::unordered_map<std::string, Tuple4> result;
  std::string line;
  while (std::getline(input, line)) {
    if (line.empty() || line.front() == '#' || line.rfind("name\t", 0) == 0) {
      continue;
    }
    const auto fields = split(line, '\t');
    if (fields.size() != 5) {
      throw std::runtime_error("invalid native kernel fixture row");
    }
    Tuple4 tuple{};
    for (int index = 0; index < 4; ++index) {
      tuple.entries[index] = parse_permutation(fields[index + 1]);
    }
    result.emplace(fields[0], tuple);
  }
  return result;
}

bool equal(const Tuple4& left, const Tuple4& right) {
  for (int entry = 0; entry < 4; ++entry) {
    for (int point = 0; point < degree; ++point) {
      if (left.entries[entry].image[point] !=
          right.entries[entry].image[point]) {
        return false;
      }
    }
  }
  return true;
}

bool equal(const FixedDestination& left, const FixedDestination& right) {
  for (int entry = 0; entry < 3; ++entry) {
    for (int point = 0; point < degree; ++point) {
      if (left.entries[entry].image[point] !=
          right.entries[entry].image[point]) {
        return false;
      }
    }
  }
  return true;
}

double milliseconds(const std::chrono::steady_clock::time_point start,
                    const std::chrono::steady_clock::time_point finish) {
  return std::chrono::duration<double, std::milli>(finish - start).count();
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 4) {
      throw std::runtime_error(
          "usage: m23_permutation_batch FIXTURE.tsv BATCH_SIZE REPEATS");
    }
    const auto fixture = read_fixture(argv[1]);
    const auto count = std::stoull(argv[2]);
    const auto repeats = std::stoull(argv[3]);
    if (count == 0 || count > UINT32_MAX * std::uint64_t{256}) {
      throw std::runtime_error("invalid CUDA batch size");
    }
    if (repeats == 0 || repeats > UINT32_MAX) {
      throw std::runtime_error("invalid CUDA repeat count");
    }
    if (repeats > UINT64_MAX / (2 * count)) {
      throw std::runtime_error("CUDA edge-attempt count overflows");
    }
    for (const auto* required : {"input", "beta13", "beta14", "4a_input",
                                 "4a_beta13", "4a_beta14"}) {
      if (fixture.find(required) == fixture.end()) {
        throw std::runtime_error("native kernel fixture is incomplete");
      }
    }
    if (!equal(beta13(fixture.at("input")), fixture.at("beta13")) ||
        !equal(beta14(fixture.at("input")), fixture.at("beta14")) ||
        !equal(beta13(fixture.at("4a_input")), fixture.at("4a_beta13")) ||
        !equal(beta14(fixture.at("4a_input")), fixture.at("4a_beta14"))) {
      throw std::runtime_error("host CUDA formulas disagree with GAP fixture");
    }

    std::vector<InputRow> input(count);
    std::vector<FixedDestination> cpu13(count), cpu14(count), gpu13(count),
        gpu14(count);
    for (std::uint64_t index = 0; index < count; ++index) {
      input[index].tuple =
          fixture.at(index % 2 == 0 ? "input" : "4a_input");
      for (int point = 0; point < degree; ++point) {
        input[index].first_transporter.image[point] =
            static_cast<std::uint8_t>(point);
      }
    }
    const auto cpu_start = std::chrono::steady_clock::now();
    for (std::uint64_t index = 0; index < count; ++index) {
      cpu13[index] = fixed_destination(input[index], 13);
      cpu14[index] = fixed_destination(input[index], 14);
    }
    const auto cpu_finish = std::chrono::steady_clock::now();

    InputRow* device_input = nullptr;
    FixedDestination *device13 = nullptr, *device14 = nullptr;
    const auto input_bytes = count * sizeof(InputRow);
    const auto output_bytes = count * sizeof(FixedDestination);
    const auto allocation_start = std::chrono::steady_clock::now();
    cuda_check(cudaMalloc(&device_input, input_bytes), "cudaMalloc input");
    cuda_check(cudaMalloc(&device13, output_bytes), "cudaMalloc beta13");
    cuda_check(cudaMalloc(&device14, output_bytes), "cudaMalloc beta14");
    const auto allocation_finish = std::chrono::steady_clock::now();
    const auto blocks = static_cast<unsigned int>((count + 255) / 256);
    double h2d_ms = 0;
    double kernel_ms = 0;
    double d2h_ms = 0;
    const auto inclusive_start = std::chrono::steady_clock::now();
    for (std::uint64_t repeat = 0; repeat < repeats; ++repeat) {
      const auto transfer_in_start = std::chrono::steady_clock::now();
      cuda_check(cudaMemcpy(device_input, input.data(), input_bytes,
                            cudaMemcpyHostToDevice),
                 "copy input to device");
      const auto transfer_in_finish = std::chrono::steady_clock::now();
      const auto kernel_start = std::chrono::steady_clock::now();
      destination_images<<<blocks, 256>>>(device_input, device13, device14,
                                          count);
      cuda_check(cudaGetLastError(), "launch braid image kernel");
      cuda_check(cudaDeviceSynchronize(), "synchronize braid image kernel");
      const auto kernel_finish = std::chrono::steady_clock::now();
      const auto transfer_out_start = std::chrono::steady_clock::now();
      cuda_check(cudaMemcpy(gpu13.data(), device13, output_bytes,
                            cudaMemcpyDeviceToHost),
                 "copy beta13 from device");
      cuda_check(cudaMemcpy(gpu14.data(), device14, output_bytes,
                            cudaMemcpyDeviceToHost),
                 "copy beta14 from device");
      const auto transfer_out_finish = std::chrono::steady_clock::now();
      h2d_ms += milliseconds(transfer_in_start, transfer_in_finish);
      kernel_ms += milliseconds(kernel_start, kernel_finish);
      d2h_ms += milliseconds(transfer_out_start, transfer_out_finish);
    }
    const auto inclusive_finish = std::chrono::steady_clock::now();
    cuda_check(cudaFree(device_input), "cudaFree input");
    cuda_check(cudaFree(device13), "cudaFree beta13");
    cuda_check(cudaFree(device14), "cudaFree beta14");
    for (std::uint64_t index = 0; index < count; ++index) {
      if (!equal(cpu13[index], gpu13[index]) ||
          !equal(cpu14[index], gpu14[index])) {
        throw std::runtime_error("CPU and GPU braid images disagree");
      }
    }

    const auto cpu_ms = milliseconds(cpu_start, cpu_finish);
    const auto allocation_ms = milliseconds(allocation_start, allocation_finish);
    const auto inclusive_ms = milliseconds(inclusive_start, inclusive_finish);
    const auto gpu_edge_attempts = 2 * count * repeats;
    std::cout << std::fixed << std::setprecision(3)
              << "schema\tm23-cuda-fixed-destination-batch-v1\n"
              << "batch_tuples\t" << count << '\n'
              << "repeats\t" << repeats << '\n'
              << "cpu_edge_attempts\t" << 2 * count << '\n'
              << "gpu_edge_attempts\t" << gpu_edge_attempts << '\n'
              << "input_bytes_per_tuple\t" << sizeof(InputRow) << '\n'
              << "output_bytes_per_destination\t"
              << sizeof(FixedDestination) << '\n'
              << "destination_stage\tfixed_last_three_permutations\n"
              << "gap_fixture_match\ttrue\n"
              << "cpu_gpu_match\ttrue\n"
              << "cpu_single_core_ms\t" << cpu_ms << '\n'
              << "gpu_allocation_ms\t" << allocation_ms << '\n'
              << "gpu_h2d_ms\t" << h2d_ms << '\n'
              << "gpu_kernel_ms\t" << kernel_ms << '\n'
              << "gpu_d2h_ms\t" << d2h_ms << '\n'
              << "gpu_inclusive_ms\t" << inclusive_ms << '\n'
              << "cpu_edge_attempts_per_second\t"
              << 2000.0 * count / cpu_ms << '\n'
              << "gpu_kernel_edge_attempts_per_second\t"
              << 1000.0 * gpu_edge_attempts / kernel_ms << '\n'
              << "gpu_inclusive_edge_attempts_per_second\t"
              << 1000.0 * gpu_edge_attempts / inclusive_ms << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
