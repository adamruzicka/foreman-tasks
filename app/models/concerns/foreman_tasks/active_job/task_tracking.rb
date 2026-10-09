module ForemanTasks
  module ActiveJob
    module TaskTracking
      extend ActiveSupport::Concern

      included do
        before_enqueue :prepare_foreman_task, prepend: true
      end

      attr_accessor :foreman_tasks_outcome, :foreman_tasks_error

      def foreman_task
        ForemanTasks::Task::ActiveJobTask.find_by(id: job_id)
      end

      def serialize
        @foreman_tasks_job_data = super.merge('foreman_tasks_context' => foreman_tasks_context)
      end

      def deserialize(data)
        super
        @foreman_tasks_context = data['foreman_tasks_context'] || {}
        @foreman_tasks_job_data = data
      end

      def foreman_tasks_job_data
        @foreman_tasks_job_data || {
          'job_class' => self.class.name, 'job_id' => job_id,
          'provider_job_id' => provider_job_id, 'arguments' => foreman_tasks_arguments,
          'executions' => executions.to_i, 'foreman_tasks_context' => foreman_tasks_context
        }
      end

      def enqueue(options = {})
        self.foreman_tasks_outcome = :retry if @foreman_tasks_performing
        ensure_foreman_task
        result = super
        task = foreman_task
        if successfully_enqueued?
          task.complete_enqueue(self)
        elsif task
          self.foreman_tasks_outcome = :error
          task.finish(enqueue_error ? 'error' : 'cancelled', enqueue_error)
        end
        result
      rescue StandardError => error
        self.foreman_tasks_outcome = :error
        foreman_task&.finish('error', error)
        raise
      end

      def perform_now
        attempt = executions.to_i + 1
        @foreman_tasks_performing = true
        self.foreman_tasks_outcome = nil
        self.foreman_tasks_error = nil
        task = ensure_foreman_task
        with_foreman_tasks_context do
          task.start_execution(self, attempt)
          result = super
          unless foreman_tasks_outcome == :retry
            outcome = case foreman_tasks_outcome
                      when :error
                        'error'
                      when :cancelled
                        'cancelled'
                      else
                        'success'
                      end
            task.finish_execution(self, attempt, outcome, foreman_tasks_error)
          end
          result
        end
      rescue StandardError => error
        task&.finish_execution(self, attempt, 'error', error)
        raise
      ensure
        @foreman_tasks_performing = false
      end

      private

      def prepare_foreman_task
        ensure_foreman_task.prepare_enqueue(self)
      end

      def ensure_foreman_task
        foreman_task || ForemanTasks::Task::ActiveJobTask.create_or_find_by!(id: job_id) do |task|
          task.assign_attributes(label: self.class.name, action: self.class.name,
                                 state: 'pending', result: 'pending', user_id: foreman_tasks_context['user_id'])
        end
      end

      def foreman_tasks_arguments
        ::ActiveJob::Arguments.serialize(arguments)
      rescue ::ActiveJob::SerializationError
        # perform_now permits objects that cannot be sent to a queue.
        arguments.map(&:inspect)
      end

      def foreman_tasks_context
        @foreman_tasks_context ||= {
          'user_id' => User.current&.id,
          'organization_id' => Organization.current&.id,
          'location_id' => Location.current&.id,
          'request_id' => ::Logging.mdc['request'],
        }
      end

      def with_foreman_tasks_context
        previous = [User.current, Organization.current, Location.current, ::Logging.mdc['request']]
        context = foreman_tasks_context
        User.current = context['user_id'] && User.unscoped.find(context['user_id'])
        Organization.current = context['organization_id'] && Organization.unscoped.find(context['organization_id'])
        Location.current = context['location_id'] && Location.unscoped.find(context['location_id'])
        ::Logging.mdc['request'] = context['request_id']
        yield
      ensure
        User.current, Organization.current, Location.current, ::Logging.mdc['request'] = previous
      end
    end
  end
end
