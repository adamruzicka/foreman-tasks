module ForemanTasks
  class Task
    class ActiveJobTask < ForemanTasks::Task
      def self.model_name
        superclass.model_name
      end

      def input
        job_data&.fetch('arguments', []) || []
      end

      def humanized
        {
          action: action,
          input: job_data&.dig('foreman_tasks_humanized', 'input'),
          output: job_data&.dig('foreman_tasks_humanized', 'output'),
          errors: job_error ? ["#{job_error['message']} (#{job_error['exception_class']})"] : [],
        }
      end

      def input_output_failed_steps
        return [] unless job_error
        [{ error: job_error, action_class: label, state: 'error', input: input.pretty_inspect, output: output.pretty_inspect }]
      end

      def prepare_enqueue(job)
        with_lock do
          self.job_data = serialized_job(job)
          self.external_id = job.provider_job_id
          self.state = job.scheduled_at ? 'scheduled' : 'pending'
          self.result = 'pending'
          self.start_at = job.scheduled_at ? Time.zone.at(job.scheduled_at) : nil
          self.ended_at = nil
          self.action = humanized_value(job, :humanized_name) || job.class.name
          save!
        end
      end

      def start_execution(job, attempt)
        with_lock do
          presentation = job_data&.fetch('foreman_tasks_humanized', {}) || {}
          self.job_data = job.foreman_tasks_job_data.merge('executions' => attempt, 'foreman_tasks_humanized' => presentation)
          self.external_id = job.provider_job_id
          self.started_at ||= Time.current
          self.start_at ||= started_at
          self.ended_at = nil
          self.state = 'running'
          self.result = 'pending'
          save!
        end
      end

      def complete_enqueue(job)
        with_lock do
          return if job_data && job_data['executions'].to_i > job.executions.to_i
          update!(job_data: serialized_job(job), external_id: job.provider_job_id)
        end
      end

      def finish_execution(job, attempt, result, error = nil)
        with_lock do
          # A retry may already have run, especially with an inline adapter.
          return if job_data && job_data['executions'].to_i > attempt
          if result == 'success'
            self.job_data = serialized_job(job).merge('executions' => attempt)
            self.action = humanized_value(job, :humanized_name) || job.class.name
          end
          finish(result, error)
        end
      end

      def finish(result, error = nil)
        update!(state: 'stopped', result: result, ended_at: Time.current,
                job_error: error && { exception_class: error.class.name, message: error.message, backtrace: error.backtrace })
      end

      private

      def serialized_job(job)
        presentation = {
          input: humanized_value(job, :humanized_input),
          output: humanized_value(job, :humanized_output),
        }
        job.foreman_tasks_job_data.merge('foreman_tasks_humanized' => presentation)
      end

      def humanized_value(job, method)
        job.public_send(method) if job.respond_to?(method)
      rescue StandardError => error
        Foreman::Logging.exception("Failed to humanize ActiveJob task #{id}", error, logger: 'foreman-tasks')
        nil
      end
    end
  end
end
