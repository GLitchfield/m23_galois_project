#include "m23_kernel.hpp"
#include "m23_native_sqlite.hpp"

#include <sqlite3.h>

#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <exception>
#include <future>
#include <iostream>
#include <limits>
#include <memory>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <syncstream>
#include <thread>
#include <unordered_map>
#include <utility>
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

double seconds(const Clock::time_point start, const Clock::time_point finish) {
  return std::chrono::duration<double>(finish - start).count();
}

m23::NativeVertexKey key(const m23::PairTwistVertex& vertex) {
  return {vertex.block_ordinal, vertex.twist_id};
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

void check_sqlite(const int status, sqlite3* database,
                  const char* operation) {
  if (status != SQLITE_OK && status != SQLITE_DONE && status != SQLITE_ROW) {
    throw std::runtime_error(std::string(operation) + ": " +
                             sqlite3_errmsg(database));
  }
}

class ReadonlyOwnership {
 public:
  explicit ReadonlyOwnership(const std::string& path) {
    const auto status = sqlite3_open_v2(
        path.c_str(), &database_, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
        nullptr);
    if (status != SQLITE_OK) {
      const std::string detail = database_ ? sqlite3_errmsg(database_)
                                           : sqlite3_errstr(status);
      if (database_) {
        sqlite3_close(database_);
        database_ = nullptr;
      }
      throw std::runtime_error("open queued native ownership reader: " +
                               detail);
    }
    try {
      check_sqlite(sqlite3_busy_timeout(database_, 300000), database_,
                   "set queued ownership busy timeout");
      check_sqlite(sqlite3_prepare_v2(
                       database_,
                       "SELECT certificate FROM vertices "
                       "WHERE ordinal=? AND twist=?",
                       -1, &lookup_, nullptr),
                   database_, "prepare queued ownership lookup");
    } catch (...) {
      sqlite3_finalize(lookup_);
      sqlite3_close(database_);
      database_ = nullptr;
      throw;
    }
  }

  ~ReadonlyOwnership() {
    sqlite3_finalize(lookup_);
    if (database_) {
      sqlite3_close(database_);
    }
  }

  ReadonlyOwnership(const ReadonlyOwnership&) = delete;
  ReadonlyOwnership& operator=(const ReadonlyOwnership&) = delete;

  std::optional<std::uint64_t> lookup(const m23::NativeVertexKey& vertex) {
    if (vertex.ordinal >
            static_cast<std::uint64_t>(
                std::numeric_limits<sqlite3_int64>::max()) ||
        vertex.twist >
            static_cast<std::uint64_t>(
                std::numeric_limits<sqlite3_int64>::max())) {
      throw std::runtime_error("queued ownership key exceeds signed range");
    }
    sqlite3_reset(lookup_);
    sqlite3_clear_bindings(lookup_);
    check_sqlite(sqlite3_bind_int64(
                     lookup_, 1, static_cast<sqlite3_int64>(vertex.ordinal)),
                 database_, "bind queued ownership ordinal");
    check_sqlite(sqlite3_bind_int64(
                     lookup_, 2, static_cast<sqlite3_int64>(vertex.twist)),
                 database_, "bind queued ownership twist");
    const auto status = sqlite3_step(lookup_);
    if (status == SQLITE_DONE) {
      sqlite3_reset(lookup_);
      return std::nullopt;
    }
    check_sqlite(status, database_, "query queued ownership");
    const auto value = sqlite3_column_int64(lookup_, 0);
    sqlite3_reset(lookup_);
    if (value < 0) {
      throw std::runtime_error("queued ownership row is negative");
    }
    return static_cast<std::uint64_t>(value);
  }

 private:
  sqlite3* database_{};
  sqlite3_stmt* lookup_{};
};

struct BatchWriterStats {
  std::uint64_t batches{};
  std::uint64_t requests{};
  std::uint64_t added{};
  std::uint64_t conflicts{};
  std::uint64_t maximum_batch{};
};

class CertificateBatchWriter {
 public:
  CertificateBatchWriter(m23::NativeSqliteLedger& ledger,
                         std::mutex& database_mutex,
                         const std::size_t maximum_batch,
                         const std::chrono::microseconds batch_wait)
      : ledger_(ledger),
        database_mutex_(database_mutex),
        maximum_batch_(maximum_batch),
        batch_wait_(batch_wait),
        thread_([this] { run(); }) {}

  ~CertificateBatchWriter() { stop(); }
  CertificateBatchWriter(const CertificateBatchWriter&) = delete;
  CertificateBatchWriter& operator=(const CertificateBatchWriter&) = delete;

  m23::NativeCertificateCommit submit(m23::NativeCertificateRequest request) {
    auto pending = std::make_shared<Pending>(std::move(request));
    auto future = pending->result.get_future();
    {
      std::lock_guard lock(queue_mutex_);
      if (stopping_) {
        throw std::runtime_error("native certificate writer is stopping");
      }
      queue_.push_back(std::move(pending));
    }
    available_.notify_one();
    return future.get();
  }

  void stop() {
    {
      std::lock_guard lock(queue_mutex_);
      if (stopping_) {
        if (thread_.joinable()) {
          thread_.join();
        }
        return;
      }
      stopping_ = true;
    }
    available_.notify_all();
    if (thread_.joinable()) {
      thread_.join();
    }
  }

  BatchWriterStats stats() const { return stats_; }

 private:
  struct Pending {
    explicit Pending(m23::NativeCertificateRequest value)
        : request(std::move(value)) {}
    m23::NativeCertificateRequest request;
    std::promise<m23::NativeCertificateCommit> result;
  };

  void run() {
    while (true) {
      std::vector<std::shared_ptr<Pending>> pending;
      {
        std::unique_lock lock(queue_mutex_);
        available_.wait(lock, [this] { return stopping_ || !queue_.empty(); });
        if (queue_.empty() && stopping_) {
          return;
        }
        if (!stopping_ && queue_.size() < maximum_batch_ &&
            batch_wait_.count() != 0) {
          available_.wait_for(lock, batch_wait_, [this] {
            return stopping_ || queue_.size() >= maximum_batch_;
          });
        }
        const auto count = std::min(maximum_batch_, queue_.size());
        pending.reserve(count);
        for (std::size_t index = 0; index < count; ++index) {
          pending.push_back(std::move(queue_.front()));
          queue_.pop_front();
        }
      }

      std::vector<m23::NativeCertificateRequest> requests;
      requests.reserve(pending.size());
      for (auto& item : pending) {
        requests.push_back(std::move(item->request));
      }
      try {
        std::vector<m23::NativeCertificateCommit> results;
        {
          std::lock_guard lock(database_mutex_);
          results = ledger_.try_add_certificates(requests);
        }
        if (results.size() != pending.size()) {
          throw std::logic_error("native certificate batch result mismatch");
        }
        ++stats_.batches;
        stats_.requests += results.size();
        stats_.maximum_batch = std::max<std::uint64_t>(
            stats_.maximum_batch, results.size());
        for (std::size_t index = 0; index < results.size(); ++index) {
          if (results[index].added) {
            ++stats_.added;
          } else {
            ++stats_.conflicts;
          }
          pending[index]->result.set_value(results[index]);
        }
      } catch (...) {
        const auto failure = std::current_exception();
        for (auto& item : pending) {
          item->result.set_exception(failure);
        }
      }
    }
  }

  m23::NativeSqliteLedger& ledger_;
  std::mutex& database_mutex_;
  std::size_t maximum_batch_{};
  std::chrono::microseconds batch_wait_{};
  std::mutex queue_mutex_;
  std::condition_variable available_;
  std::deque<std::shared_ptr<Pending>> queue_;
  bool stopping_{};
  std::thread thread_;
  BatchWriterStats stats_;
};

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 12) {
      throw std::runtime_error(
          "usage: m23_native_sqlite_queued_worker COORDINATES.bin MASKS.bin "
          "LEDGER.sqlite3 WORKERS BLOCK_TARGET START_BLOCK PROOF_LIMIT "
          "WALK_LIMIT LEASE_SECONDS BATCH_MAX BATCH_WAIT_US");
    }
    const auto worker_count = parse_u64(argv[4], "worker count");
    const auto block_target = parse_u64(argv[5], "block target");
    const auto start_block = parse_u64(argv[6], "start block");
    const auto proof_limit = parse_u64(argv[7], "proof limit");
    const auto walk_limit = parse_u64(argv[8], "walk limit");
    const auto lease_seconds = parse_u64(argv[9], "lease seconds");
    const auto maximum_batch = parse_u64(argv[10], "maximum batch");
    const auto batch_wait_us = parse_u64(argv[11], "batch wait");
    if (worker_count == 0 ||
        worker_count > std::numeric_limits<std::uint32_t>::max() ||
        block_target == 0 || start_block == 0 || proof_limit == 0 ||
        walk_limit < proof_limit || lease_seconds == 0 || maximum_batch == 0 ||
        maximum_batch > std::numeric_limits<std::size_t>::max()) {
      throw std::runtime_error("invalid queued native worker parameters");
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
    if (start_block > macroblock_count) {
      throw std::runtime_error("queued native start block is out of range");
    }

    m23::NativeSqliteLedger ledger(
        argv[3],
        {coordinate_checkpoint.target_order, macroblock_count, start_block,
         proof_limit, walk_limit,
         coordinate_checkpoint.source_checkpoint_sha256,
         coordinate_checkpoint.source_git_revision,
         coordinate_checkpoint.gap_version});
    std::mutex database_mutex;
    CertificateBatchWriter writer(
        ledger, database_mutex, static_cast<std::size_t>(maximum_batch),
        std::chrono::microseconds(batch_wait_us));

    std::mutex failure_mutex;
    std::exception_ptr failure;
    std::vector<std::thread> workers;
    workers.reserve(worker_count);
    for (std::uint32_t shard = 1; shard <= worker_count; ++shard) {
      workers.emplace_back([&, shard] {
        try {
          const std::string worker = "native-" + std::to_string(shard) +
                                     "-of-" + std::to_string(worker_count);
          m23::CompressedCoordinateIndex coordinates(
              coordinate_checkpoint.target,
              coordinate_checkpoint.target_pairs,
              coordinate_checkpoint.right_pairs,
              coordinate_checkpoint.segments,
              coordinate_checkpoint.relatives,
              coordinate_checkpoint.refinements);
          const m23::FixedTargetGenerationMasks generation_masks(
              mask_checkpoint, coordinate_checkpoint.target_pairs);
          ReadonlyOwnership ownership(argv[3]);

          while (true) {
            std::optional<m23::NativeClaimedBlock> block;
            {
              std::lock_guard lock(database_mutex);
              block = ledger.claim_block(
                  worker, lease_seconds, block_target, shard,
                  static_cast<std::uint32_t>(worker_count));
            }
            if (!block.has_value()) {
              break;
            }
            const auto block_started = Clock::now();
            const auto block_vertices =
                coordinates.block_vertices(block->ordinal);
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
              if (ownership.lookup(key(seed)).has_value()) {
                ++hits;
                continue;
              }
              {
                std::lock_guard lock(database_mutex);
                ledger.renew_lease(worker, block->ordinal, lease_seconds);
              }
              const auto result = m23::bounded_pair_twist_walk_with_lookup(
                  coordinates, seed, walk_limit,
                  [&](const m23::PairTwistVertex& vertex) {
                    return ownership.lookup(key(vertex));
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
              const auto commit = writer.submit(
                  {worker,
                   block->ordinal,
                   {certificate_status, walk_status(result.status),
                    result.linked_certificate, key(seed),
                    result.checked_vertex_count,
                    result.discovered_class_count},
                   std::move(vertices)});
              if (commit.added) {
                ++added;
              } else {
                ++hits;
              }
              coordinates.clear_disposable_block_cache();
            }
            {
              std::lock_guard lock(database_mutex);
              ledger.finish_block(worker, *block, block_vertices.size(),
                                  generating);
            }
            m23::NativeLedgerStats current;
            {
              std::lock_guard lock(database_mutex);
              current = ledger.stats();
            }
            std::osyncstream(std::cout)
                << "progress\t" << current.blocks << '\t' << block_target
                << '\t' << block->ordinal << '\t'
                << seconds(block_started, Clock::now()) << '\t'
                << current.certificates << '\t' << current.vertices << '\t'
                << "added=" << added << ",hits=" << hits << '\n';
          }
          m23::NativeLedgerStats current;
          {
            std::lock_guard lock(database_mutex);
            current = ledger.stats();
          }
          std::osyncstream(std::cout)
              << "complete\t" << worker << '\t' << current.blocks << '\t'
              << current.certificates << '\t' << current.vertices << '\t'
              << current.leases << '\n';
        } catch (...) {
          std::lock_guard lock(failure_mutex);
          if (!failure) {
            failure = std::current_exception();
          }
        }
      });
    }
    for (auto& worker : workers) {
      worker.join();
    }
    writer.stop();
    if (failure) {
      std::rethrow_exception(failure);
    }
    const auto writer_stats = writer.stats();
    std::cout << "writer\tbatches=" << writer_stats.batches
              << ",requests=" << writer_stats.requests
              << ",added=" << writer_stats.added
              << ",conflicts=" << writer_stats.conflicts
              << ",maximum_batch=" << writer_stats.maximum_batch << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
