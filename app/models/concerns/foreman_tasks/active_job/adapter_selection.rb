module ForemanTasks
  module ActiveJob
    module AdapterSelection
      extend ActiveSupport::Concern

      included do
        adapter = ForemanTasks.active_job_queue_adapter
        unless adapter
          raise ArgumentError, 'Configure ForemanTasks.active_job_queue_adapter before including AdapterSelection'
        end
        self.queue_adapter = adapter
      end
    end
  end
end
