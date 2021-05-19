module ForemanTasks
  class RemoteTask < ApplicationRecord
    attr_accessor :result

    belongs_to :task, :class_name  => 'ForemanTasks::Task',
                      :primary_key => :external_id,
                      :foreign_key => :execution_plan_id,
                      :inverse_of  => :remote_tasks

    scope :triggered, -> { where(:state => 'triggered') }
    scope :pending,   -> { where(:state => 'new') }
    scope :external,  -> { where(:state => 'external') }

    delegate :proxy_action_name, :to => :action

    # Triggers a task on the proxy "the old way"
    def trigger(proxy_action_name, input)
      response = begin
                   proxy.trigger_task(proxy_action_name, input).merge('result' => 'success')
                 rescue RestClient::Exception => e
                   logger.warn "Could not trigger task on the smart proxy: #{e.message}"
                   {}
                 end
      update_from_batch_trigger(response)
      save!
    end

    def self.batch_trigger(operation, remote_tasks)
      triggered = []
      failed = []
      remote_tasks.group_by(&:proxy_url).values.map do |group|
        input_hash = group.reduce({}) do |acc, remote_task|
          acc.merge(remote_task.execution_plan_id => { :action_input => remote_task.proxy_input,
                                                       :action_class => remote_task.proxy_action_name })
        end
        success, failure = safe_batch_trigger(operation, group, input_hash)
        triggered.concat(success)
        failed.concat(failure)
      end
      [triggered, failed]
    end

    # Attempt to trigger the tasks using the new API and fall back to the old one
    # if it fails
    def self.safe_batch_trigger(operation, remote_tasks, input_hash)
      results = remote_tasks.first.proxy.launch_tasks(operation, input_hash)
      remote_tasks.each { |remote_task| remote_task.update_from_batch_trigger results[remote_task.execution_plan_id] }
      [remote_tasks, []]
    rescue RestClient::NotFound
      fallback_batch_trigger remote_tasks, input_hash
    rescue => e # TODO
      remote_tasks.partition { |task| !task.handle_trigger_failure e }
    end

    # Trigger the tasks one-by-one using the old API
    def self.fallback_batch_trigger(remote_tasks, input_hash)
      triggered = []
      failed = []
      remote_tasks.each do |remote_task|
        task_data = input_hash[remote_task.execution_plan_id]
        begin
          remote_task.trigger(task_data[:action_class], task_data[:action_input])
          triggered << remote_task
        rescue => e # TODO
          acc = remote_task.handle_trigger_failure(e) ? failed : triggered
          acc << remote_task
        end
      end
      [triggered, failed]
    end

    def update_from_batch_trigger(data)
      if data['result'] == 'success'
        self.remote_task_id = data['task_id']
        self.state = 'triggered'
      else
        notify_failed
      end
      save!
    end

    def retry_limit
      5 # TODO
    end

    def handle_trigger_failure(exception)
      if retry_count < retry_limit
        self.retry_count += 1
        save!
        true
      else
        notify_failed exception
        false
      end
    end

    def notify_failed(exception = nil)
      # Tell the action the task on the smart proxy stopped
      event = if exception.nil?
                ::Actions::ProxyAction::ProxyActionStopped.new
              else
                ::Actions::ProxyAction::ProxyActionNotStarted.new(exception)
              end
      ForemanTasks.dynflow.world.event execution_plan_id,
                                       step_id,
                                       event
    end

    def proxy_input
      action.proxy_input(task.id)
    end

    def proxy
      @proxy ||= ::ProxyAPI::ForemanDynflow::DynflowProxy.new(:url => proxy_url)
    end

    private

    def action
      @action ||= ForemanTasks.dynflow.world.persistence.load_action(step)
    end

    def step
      @step ||= task.execution_plan.steps[step_id]
    end
  end
end
