# Run with:
#
#   ITERATIONS=5 WORK_UNITS=500000 rails runner script/benchmark_active_job.rb
#
# The base class inherits the application's Dynflow ActiveJob adapter. The
# subclass switches to the tracked, non-Dynflow ActiveJob path.

require 'timeout'

module ActiveJobProviderBenchmark
  class BenchmarkJob < ApplicationJob
    def perform(work_units = 100_000)
      value = 0
      work_units.times do
        value = (value * 1_664_525 + 1_013_904_223) & 0xffffffff
      end
      value
    end
  end

  # Set this before including Tracked: adapter selection happens when the
  # concern is included, not when perform_later is called.
  ForemanTasks.active_job_queue_adapter = :inline

  class TrackedBenchmarkJob < BenchmarkJob
    include ForemanTasks::ActiveJob::Tracked
  end
end

iterations = Integer(ENV.fetch('ITERATIONS', '3'))
work_units = Integer(ENV.fetch('WORK_UNITS', '100000'))
timeout_seconds = Integer(ENV.fetch('TIMEOUT', '120'))

raise ArgumentError, 'ITERATIONS must be positive' unless iterations.positive?
raise ArgumentError, 'WORK_UNITS must be positive' unless work_units.positive?

def wait_for_task(task, timeout_seconds)
  Timeout.timeout(timeout_seconds) do
    loop do
      task.reload
      return task if task.state == 'stopped'

      sleep 0.05
    end
  end
end

def run_case(label, job_class, iterations, work_units, timeout_seconds)
  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  tasks = []

  iterations.times do
    job = job_class.perform_later(work_units)
    task = if job.respond_to?(:foreman_task)
             job.foreman_task
           else
             ForemanTasks::Task.find_by!(external_id: job.provider_job_id)
           end
    tasks << wait_for_task(task, timeout_seconds)
  end

  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  failures = tasks.reject { |task| task.result == 'success' }

  puts format(
    '%-10s adapter=%-8s task=%-18s iterations=%d work_units=%d elapsed=%.3fs avg=%.3fs failures=%d',
    label,
    job_class.queue_adapter_name,
    tasks.first.class.name.demodulize,
    iterations,
    work_units,
    elapsed,
    elapsed / iterations,
    failures.size
  )

  failures.each do |task|
    warn "#{label} task #{task.id} finished with #{task.result}: #{task.job_error.inspect}"
  end
end

puts "Benchmarking #{iterations} iteration(s) with #{work_units} work units each"
run_case('dynflow', ActiveJobProviderBenchmark::BenchmarkJob, iterations, work_units, timeout_seconds)
run_case('tracked', ActiveJobProviderBenchmark::TrackedBenchmarkJob, iterations, work_units, timeout_seconds)
