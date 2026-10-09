# ActiveJob task tracking

## Goal and approved API

Opted-in ActiveJob classes create `ForemanTasks::Task::ActiveJobTask` records without
creating Dynflow execution plans. Existing Dynflow actions and the application's
default adapter remain unchanged.

```ruby
# Configure once, before loading opted-in job classes.
ForemanTasks.active_job_queue_adapter = :sidekiq

class CheapJob < ApplicationJob
  include ForemanTasks::ActiveJob::Tracked
end
```

The adapter value is an explicit deployment choice, not a Sidekiq dependency.
`Tracked` composes `AdapterSelection` and `TaskTracking`. Adapter selection reads
the central configuration when the job class loads. A configuration change takes
effect on application restart. Tracking alone can be included when the caller
already selects a non-Dynflow adapter. Missing central configuration fails clearly.

## Constraints

- Support Foreman's Rails 7.0 ActiveJob API and Ruby >= 3.0.
- Add no Sidekiq dependency, middleware, or provider-specific hooks.
- Preserve existing Dynflow actions and the global ActiveJob adapter.
- Track one logical job using ActiveJob's `job_id`; treat `provider_job_id` as optional.
- Use vanilla ActiveJob retries and discards without changing their behavior.
- Do not introduce cancellation or manual retry controls for ActiveJob tasks.

## Persistence and lifecycle

Add nullable JSON columns for serialized job data and the latest error to the task
table, using JSONB on PostgreSQL so existing distinct queries remain valid. The new
STI subclass uses the ActiveJob job ID as its primary key. It exposes
the normal task presentation and permissions and uses existing coarse progress.

Create tracking at enqueue entry before callbacks so inline execution can find its
task and prepended aborted callbacks remain observable. Record
`pending/pending` for an immediate enqueue and `scheduled/pending` for a delayed
enqueue. Record `running/pending` during execution, `stopped/success` on normal
completion, and `stopped/error` on unhandled failure, discard, or retry exhaustion.
Successful re-enqueue keeps the same record and clears its completion timestamp.
Enqueue completion must not overwrite a job that already ran. An aborted execution
is recorded as cancelled; failed enqueue attempts are recorded as errors.

Wrap the public `enqueue` and `perform_now` methods while calling `super`, preserving
return values and exceptions. This captures failed/aborted enqueue and argument
deserialization failures. Subscribe to ActiveJob retry/discard notifications only
for opted-in job instances so handled failures are not mistaken for success. Each
execution keeps its outcome on its job instance, preventing nested inline jobs from
sharing outcome state. A retry enqueued during execution must not be overwritten by
completion of its preceding attempt.

Capture the framework's actual serialize/deserialize payload without adding calls to
a job serializer. Direct execution may accept unserializable in-memory arguments;
represent these as inspected strings without changing execution semantics. Preserve
enqueue humanization through deserialization and refresh it after successful
execution within restored context.

Carry the initiating user, organization, location, and request ID in normal ActiveJob
serialization. Restore these for execution and restore worker-local values in an
ensure block. Rails already carries locale and timezone. Preserve original task
ownership across retries.

## Provider boundary

Tracking describes the most recent lifecycle observed by ActiveJob. Independent
backend retries, worker termination, queue deletion, and cancellation are outside
the generic interface. A later invocation updates the same task again. There is no
claim that an escaped exception means the backend will never retry it.

## Presentation and verification

Replace API assumptions about execution plans with task capabilities. Dynflow
details remain intact. ActiveJob task details show stored inputs/errors and no
execution plan, dependencies, console link, or unsupported controls. Bulk stop
skips tasks that cannot be stopped. Summaries accept the new pending state.

Test with Rails' test and inline adapters, including a JSON serialization round
trip, delayed enqueue, retry, discard, retry exhaustion, aborted callbacks,
deserialization failure, context restoration, adapter inheritance, task API details,
mixed-provider bulk operations, and existing Dynflow behavior.
