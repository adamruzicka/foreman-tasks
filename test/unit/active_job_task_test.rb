require 'foreman_tasks_test_helper'
require_relative '../support/tracked_active_job'

class ActiveJobTaskTest < ActiveSupport::TestCase
  test 'does not expose Dynflow-specific task methods' do
    task = Support::TrackedActiveJob.perform_later.foreman_task

    assert_not_respond_to task, :execution_plan
    assert_not_respond_to task, :main_action
    assert_not_respond_to task, :input_output_running_steps
    assert_not_respond_to task, :uses_dynflow?
  end

  test 'selects the central adapter without changing the application default' do
    assert_respond_to ForemanTasks, :active_job_queue_adapter=, 'Central ActiveJob adapter configuration is missing'
    original = ForemanTasks.active_job_queue_adapter
    ForemanTasks.active_job_queue_adapter = :test
    job_class = Class.new(ApplicationJob) do
      include ForemanTasks::ActiveJob::AdapterSelection
    end

    assert_equal 'test', job_class.queue_adapter_name
    assert_equal 'test', Class.new(job_class).queue_adapter_name
    assert_equal 'dynflow', ApplicationJob.queue_adapter_name
  ensure
    ForemanTasks.active_job_queue_adapter = original if ForemanTasks.respond_to?(:active_job_queue_adapter=)
  end

  test 'requires an explicit central adapter' do
    assert_respond_to ForemanTasks, :active_job_queue_adapter=, 'Central ActiveJob adapter configuration is missing'
    original = ForemanTasks.active_job_queue_adapter
    ForemanTasks.active_job_queue_adapter = nil

    assert_raises(ArgumentError) do
      Class.new(ApplicationJob) { include ForemanTasks::ActiveJob::AdapterSelection }
    end
    assert_equal 'dynflow', ApplicationJob.queue_adapter_name
  ensure
    ForemanTasks.active_job_queue_adapter = original if ForemanTasks.respond_to?(:active_job_queue_adapter=)
  end

  test 'the public concern selects an adapter and tracks the enqueued job' do
    original = ForemanTasks.active_job_queue_adapter
    ForemanTasks.active_job_queue_adapter = :test
    Support::CentrallyTrackedActiveJob.include(ForemanTasks::ActiveJob::Tracked)
    job = Support::CentrallyTrackedActiveJob.perform_later

    assert_kind_of ForemanTasks::Task::ActiveJobTask, job.foreman_task
    assert_equal 1, Support::CentrallyTrackedActiveJob.queue_adapter.enqueued_jobs.size
    assert_equal 'dynflow', ApplicationJob.queue_adapter_name
  ensure
    ForemanTasks.active_job_queue_adapter = original
  end
end

class ActiveJobTaskLifecycleTest < ActiveSupport::TestCase
  setup do
    Support::TrackedActiveJob.queue_adapter = :test
    Support::TrackedActiveJob.queue_adapter.enqueued_jobs.clear
    @original_context = [User.current, Organization.current, Location.current, ::Logging.mdc['request']]
  end

  teardown do
    User.current, Organization.current, Location.current, ::Logging.mdc['request'] = @original_context if @original_context
    Support::TrackedActiveJob.queue_adapter = :test
  end

  test 'creates one task with serialized inputs and ownership before enqueue' do
    User.current = FactoryBot.create(:user)
    job = Support::TrackedActiveJob.perform_later('hello')
    task = job.foreman_task

    assert_kind_of ForemanTasks::Task::ActiveJobTask, task
    assert_equal job.job_id, task.id
    assert_equal 'Support::TrackedActiveJob', task.label
    assert_equal 'Support::TrackedActiveJob', task.action
    assert_equal ['hello'], task.input
    assert_equal 'pending', task.state
    assert_equal 'pending', task.result
    assert_equal User.current, task.user
    assert_nil task.started_at
    assert_nil task.ended_at
    assert_equal 1, Support::TrackedActiveJob.queue_adapter.enqueued_jobs.size
  end

  test 'records a delayed start' do
    start = 2.hours.from_now.change(usec: 0)
    job = Support::TrackedActiveJob.set(wait_until: start).perform_later

    assert_equal 'scheduled', job.foreman_task.state
    assert_equal start, job.foreman_task.start_at
  end

  test 'inline completion is not overwritten by enqueue completion' do
    Support::TrackedActiveJob.queue_adapter = :inline
    job = Support::TrackedActiveJob.perform_later('inline')

    assert_equal 'running', Support::TrackedActiveJob.observed[:state]
    assert_equal 'stopped', job.foreman_task.state
    assert_equal 'success', job.foreman_task.result
    assert_not_nil job.foreman_task.started_at
    assert_not_nil job.foreman_task.ended_at
  end

  test 'direct execution preserves the return value and tracks success' do
    job = Support::TrackedActiveJob.new('now')

    assert_equal :completed, job.perform_now
    assert_equal 'success', job.foreman_task.result
    assert_equal 'stopped', job.foreman_task.state
  end

  test 'unhandled failure records the original error and propagates it' do
    job = Support::FailingTrackedActiveJob.new

    error = assert_raises(ArgumentError) { job.perform_now }
    assert_equal 'job failed', error.message
    assert_equal 'stopped', job.foreman_task.state
    assert_equal 'error', job.foreman_task.result
    assert_equal 'ArgumentError', job.foreman_task.job_error['exception_class']
    assert_equal 'job failed', job.foreman_task.job_error['message']
    assert_not_empty job.foreman_task.job_error['backtrace']
  end

  test 'an ActiveJob retry updates the same task and stays scheduled' do
    job = Support::RetryingTrackedActiveJob.perform_later
    id = job.foreman_task.id
    original_user = job.foreman_task.user_id
    payload = queued_payload
    ::ActiveJob::Base.execute(JSON.parse(JSON.generate(payload)))
    task = ForemanTasks::Task.find(id)

    assert_equal 'scheduled', task.state
    assert_equal 'pending', task.result
    assert_nil task.ended_at
    assert_equal 1, ForemanTasks::Task.where(id: id).count
    assert_equal original_user, task.user_id

    payload = queued_payload
    ::ActiveJob::Base.execute(JSON.parse(JSON.generate(payload)))
    assert_equal 'success', task.reload.result
    assert_equal 'stopped', task.state
    assert_nil task.job_error
  end

  test 'discarding a failure is not recorded as success' do
    job = Support::DiscardingTrackedActiveJob.new
    job.perform_now

    assert_equal 'error', job.foreman_task.result
    assert_equal 'stopped', job.foreman_task.state
    assert_equal 'job failed', job.foreman_task.job_error['message']
  end

  test 'a custom exception handler is not mistaken for an aborted execution' do
    job = Support::HandledTrackedActiveJob.new
    job.perform_now

    assert_equal :handled, Support::HandledTrackedActiveJob.observed
    assert_equal 'success', job.foreman_task.result
  end

  test 'retry exhaustion with a handler is not recorded as success' do
    job = Support::ExhaustedTrackedActiveJob.new
    job.perform_now

    assert_equal 'error', job.foreman_task.result
    assert_equal 'job failed', job.foreman_task.job_error['message']
  end

  test 'captures deserialization failure before perform callbacks' do
    user = FactoryBot.create(:user)
    job = Support::DeserializationTrackedActiveJob.perform_later(user)
    user.destroy!
    payload = queued_payload
    ::ActiveJob::Base.execute(JSON.parse(JSON.generate(payload)))

    assert_equal 'stopped', job.foreman_task.state
    assert_equal 'error', job.foreman_task.result
    assert_equal 'ActiveJob::DeserializationError', job.foreman_task.job_error['exception_class']
  end

  test 'aborted execution is recorded as cancelled' do
    job = Support::AbortedTrackedActiveJob.new
    job.perform_now

    assert_equal 'stopped', job.foreman_task.state
    assert_equal 'cancelled', job.foreman_task.result
  end

  test 'aborted enqueue preserves the false return value' do
    job = Support::AbortedEnqueueTrackedActiveJob.new

    assert_same false, job.enqueue
    assert_equal 'stopped', job.foreman_task.state
    assert_equal 'cancelled', job.foreman_task.result
    assert_empty Support::TrackedActiveJob.queue_adapter.enqueued_jobs
  end

  test 'restores initiating context after a JSON payload round trip and clears it afterwards' do
    owner = FactoryBot.create(:user)
    organization = FactoryBot.create(:organization)
    location = FactoryBot.create(:location)
    worker_user = FactoryBot.create(:user)
    User.current = owner
    Organization.current = organization
    Location.current = location
    ::Logging.mdc['request'] = 'initiating-request'
    job = Support::TrackedActiveJob.perform_later('context')
    User.current = worker_user
    Organization.current = nil
    Location.current = nil
    ::Logging.mdc['request'] = 'worker-request'

    payload = queued_payload
    ::ActiveJob::Base.execute(JSON.parse(JSON.generate(payload)))

    assert_equal owner, Support::TrackedActiveJob.observed[:user]
    assert_equal organization, Support::TrackedActiveJob.observed[:organization]
    assert_equal location, Support::TrackedActiveJob.observed[:location]
    assert_equal 'initiating-request', Support::TrackedActiveJob.observed[:request_id]
    assert_equal worker_user, User.current
    assert_nil Organization.current
    assert_nil Location.current
    assert_equal 'worker-request', ::Logging.mdc['request']
    assert_equal owner, job.foreman_task.user
  end

  test 'an inline retry cannot be overwritten by completion of the first attempt' do
    Support::TrackedActiveJob.queue_adapter = Support::ImmediateActiveJobAdapter.new
    job = Support::RetryingTrackedActiveJob.perform_later

    assert_equal 'stopped', job.foreman_task.state
    assert_equal 'success', job.foreman_task.result
    assert_equal 2, job.foreman_task.job_data['executions']
    assert_equal 1, ForemanTasks::Task.where(id: job.job_id).count
  end

  test 'failed enqueue records the error and preserves ActiveJob failure semantics' do
    Support::TrackedActiveJob.queue_adapter = Support::FailingActiveJobAdapter.new
    job = Support::TrackedActiveJob.new

    assert_same false, job.enqueue
    assert_kind_of ::ActiveJob::EnqueueError, job.enqueue_error
    assert_equal 'stopped', job.foreman_task.state
    assert_equal 'error', job.foreman_task.result
    assert_equal 'queue unavailable', job.foreman_task.job_error['message']
  end

  test 'pending tasks participate in task summaries and distinct queries' do
    task = Support::TrackedActiveJob.perform_later.foreman_task
    summary = ForemanTasks::Task::Summarizer.new(ForemanTasks::Task.where(id: task.id)).summary

    assert_equal 1, summary['pending'][:total]
    assert_equal 1, ForemanTasks::Task.where(id: task.id).select('foreman_tasks_tasks.*').distinct.count
  end

  test 'direct execution accepts arguments that cannot be serialized for a queue' do
    value = Object.new
    job = Support::TrackedActiveJob.new(value)

    assert_equal :completed, job.perform_now
    assert_same value, Support::TrackedActiveJob.observed[:value]
    assert_equal 'success', job.foreman_task.result
  end

  test 'prepended enqueue aborts still create a cancelled task' do
    job = Support::PrependedAbortedEnqueueTrackedActiveJob.new

    assert_same false, job.enqueue
    assert_not_nil job.foreman_task
    assert_equal 'cancelled', job.foreman_task.result
  end

  test 'humanized presentation survives deserialization and captures completed output' do
    job = Support::HumanizedTrackedActiveJob.perform_later('input')
    assert_equal 'input', job.foreman_task.humanized[:input]
    ::ActiveJob::Base.execute(JSON.parse(JSON.generate(queued_payload)))

    assert_equal 'Humanized cheap job', job.foreman_task.action
    assert_equal 'input', job.foreman_task.humanized[:input]
    assert_equal 'input done', job.foreman_task.humanized[:output]
  end

  test 'direct execution records the humanized job name' do
    job = Support::HumanizedTrackedActiveJob.new('direct')
    job.perform_now

    assert_equal 'Humanized cheap job', job.foreman_task.action
  end

  test 'tracking does not add calls to a job serializer' do
    Support::SerializationTrackedActiveJob.serialization_calls = 0
    Support::SerializationTrackedActiveJob.perform_later('input')
    assert_equal 1, Support::SerializationTrackedActiveJob.serialization_calls
    ::ActiveJob::Base.execute(JSON.parse(JSON.generate(queued_payload)))
    assert_equal 1, Support::SerializationTrackedActiveJob.serialization_calls
  end

  test 'an earlier enqueue does not overwrite a completed retry provider ID' do
    Support::TrackedActiveJob.queue_adapter = Support::IdentifiedImmediateActiveJobAdapter.new
    job = Support::RetryingTrackedActiveJob.perform_later

    assert_equal 'success', job.foreman_task.result
    assert_equal 'provider-2', job.foreman_task.external_id
  end

  test 'a queued immediate job remains immediate after waiting for a worker' do
    job = Support::TrackedActiveJob.perform_later
    payload = queued_payload
    travel 2.seconds do
      ::ActiveJob::Base.execute(JSON.parse(JSON.generate(payload)))
    end

    assert_not_predicate job.foreman_task, :delayed?
  end

  test 'restores worker context when execution raises' do
    owner = FactoryBot.create(:user)
    worker = User.current
    User.current = owner
    job = Support::FailingTrackedActiveJob.perform_later
    User.current = worker

    assert_raises(ArgumentError) { ::ActiveJob::Base.execute(JSON.parse(JSON.generate(queued_payload))) }
    assert_equal worker, User.current
    assert_equal owner, job.foreman_task.user
    assert_equal 'error', job.foreman_task.result
  end

  private

  def queued_payload
    Support::TrackedActiveJob.queue_adapter.enqueued_jobs.shift.select { |key, _value| key.is_a?(String) }
  end
end
