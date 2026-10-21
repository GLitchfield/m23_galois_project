#include "m23_native_replay.hpp"
#include "m23_native_sqlite.hpp"

#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

void require(const bool condition, const std::string& message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 2) {
      throw std::runtime_error("usage: test_m23_native_replay DATABASE");
    }
    const m23::NativeLedgerConfig config{
        5, 100, 10, 10, 20, "checkpoint-sha256", "revision", "4.12.1"};
    {
      m23::NativeSqliteLedger writer(argv[1], config);
      const auto block = writer.claim_block("writer", 60, 1, 1, 1);
      require(block.has_value(), "cannot claim replay fixture block");
      const auto first = writer.try_add_certificate(
          "writer", block->ordinal,
          {"overflow", "overflow", std::nullopt, {block->ordinal, 2},
           3, 30},
          {{block->ordinal, 2}, {50, 3}});
      require(first.added && first.certificate == 1,
              "cannot write replay fixture certificate");
      writer.finish_block("writer", *block, 1, 1);
    }
    m23::NativeReplayLedger replay(argv[1]);
    require(replay.config().target_order == 5 &&
                replay.config().macroblock_count == 100 &&
                replay.config().proof_limit == 10 &&
                replay.config().walk_limit == 20 &&
                replay.config().source_checkpoint_sha256 ==
                    "checkpoint-sha256",
            "replay configuration differs from the writer");
    require(replay.certificate_count() == 1,
            "replay certificate count is wrong");
    const auto certificate = replay.certificate(1);
    require(certificate.id == 1 &&
                certificate.data.status == "overflow" &&
                certificate.data.walk_status == "overflow" &&
                !certificate.data.linked_certificate.has_value() &&
                certificate.data.seed == m23::NativeVertexKey{10, 2} &&
                certificate.data.checked_vertices == 3 &&
                certificate.data.discovered_classes == 30 &&
                certificate.vertices ==
                    std::vector<m23::NativeVertexKey>{{10, 2}, {50, 3}},
            "replay certificate row is wrong");
    require(!replay.lookup_before({10, 2}, 1).has_value() &&
                replay.lookup_before({10, 2}, 2) == 1,
            "replay prefix ownership lookup is wrong");
    std::cout << "native prefix replay ledger verified\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
