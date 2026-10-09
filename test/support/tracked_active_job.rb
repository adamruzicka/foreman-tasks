module Support
  class TrackedActiveJob < ApplicationJob
    self.queue_adapter = :test
    include ForemanTasks::ActiveJob::TaskTracking

    class_attribute :observed, default: nil

    def perform(value = nil)
      self.class.observed = {
        value: value,
        state: foreman_task.state,
        user: User.current,
        organization: Organization.current,
        location: Location.current,
        request_id: ::Logging.mdc['request'],
      }
      :completed
    end
  end

  class CentrallyTrackedActiveJob < ApplicationJob
    def perform
    end
  end

  class ImmediateActiveJobAdapter < ::ActiveJob::QueueAdapters::InlineAdapter
    def enqueue_at(job, _timestamp)
      enqueue(job)
    end
  end

  class IdentifiedImmediateActiveJobAdapter < ImmediateActiveJobAdapter
    def enqueue(job)
      job.provider_job_id = "provider-#{job.executions + 1}"
      super
    end
  end

  class FailingActiveJobAdapter
    def enqueue(_job)
      raise ::ActiveJob::EnqueueError, 'queue unavailable'
    end

    def enqueue_at(job, _timestamp)
      enqueue(job)
    end
  end

  class FailingTrackedActiveJob < TrackedActiveJob
    def perform(*)
      raise ArgumentError, 'job failed'
    end
  end

  class RetryingTrackedActiveJob < TrackedActiveJob
    retry_on ArgumentError, wait: 60, attempts: 2

    def perform(*)
      raise ArgumentError, 'try again' if executions == 1
      super
    end
  end

  class DiscardingTrackedActiveJob < FailingTrackedActiveJob
    discard_on ArgumentError
  end

  class HandledTrackedActiveJob < FailingTrackedActiveJob
    rescue_from ArgumentError do |_error|
      self.class.observed = :handled
    end
  end

  class ExhaustedTrackedActiveJob < FailingTrackedActiveJob
    retry_on ArgumentError, attempts: 1 do |_job, _error|
      # An exhaustion handler consumes the exception.
    end
  end

  class DeserializationTrackedActiveJob < TrackedActiveJob
    discard_on ::ActiveJob::DeserializationError
  end

  class AbortedTrackedActiveJob < TrackedActiveJob
    before_perform { throw :abort }
  end

  class AbortedEnqueueTrackedActiveJob < TrackedActiveJob
    before_enqueue { throw :abort }
  end

  class PrependedAbortedEnqueueTrackedActiveJob < TrackedActiveJob
    before_enqueue(prepend: true) { throw :abort }
  end

  class HumanizedTrackedActiveJob < TrackedActiveJob
    def humanized_name
      'Humanized cheap job'
    end

    def humanized_input
      arguments.first
    end

    def humanized_output
      @output
    end

    def perform(value)
      @output = "#{value} done"
      super
    end
  end

  class SerializationTrackedActiveJob < TrackedActiveJob
    class_attribute :serialization_calls, default: 0

    def serialize
      self.class.serialization_calls += 1
      super
    end
  end
end
