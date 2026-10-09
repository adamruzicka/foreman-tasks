module ForemanTasks
  module ActiveJob
    class Subscriber
      def self.subscribe
        ActiveSupport::Notifications.subscribe(/\A(perform|enqueue_retry|retry_stopped|discard)\.active_job\z/) do |event|
          job = event.payload[:job]
          next unless job.is_a?(ForemanTasks::ActiveJob::TaskTracking)

          if event.name == 'perform.active_job'
            job.foreman_tasks_outcome = :cancelled if event.payload[:aborted]
            next
          end

          job.foreman_tasks_error = event.payload[:error]
          job.foreman_tasks_outcome = if event.name == 'enqueue_retry.active_job' && job.successfully_enqueued?
                                        :retry
                                      else
                                        :error
                                      end
        end
      end
    end
  end
end
