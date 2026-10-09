# ActiveJob Task Tracking Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Track opted-in ActiveJob jobs as Foreman tasks with centrally selected adapters.

**Architecture:** A public `Tracked` concern composes independent adapter selection and lifecycle tracking concerns. An STI task subclass stores serialized job information and errors. Tracking uses ActiveJob methods and notifications; presentation uses provider capabilities.

**Tech Stack:** Ruby, Rails 7.0 ActiveJob/ActiveRecord, JSON, Minitest.

**Spec:** `docs/superpowers/specs/2026-10-09-active-job-task-tracking-design.md`

## Global constraints

- Support Foreman's Rails 7.0 ActiveJob API and Ruby >= 3.0.
- Add no Sidekiq dependency, middleware, or provider-specific hooks.
- Preserve existing Dynflow actions and the global ActiveJob adapter.
- Track one logical job using ActiveJob's `job_id`; treat `provider_job_id` as optional.
- Use vanilla ActiveJob retries and discards without changing their behavior.
- Do not introduce cancellation or manual retry controls for ActiveJob tasks.

## Task 1: Central adapter selection

Files: `lib/foreman_tasks.rb`, `app/models/concerns/foreman_tasks/active_job/adapter_selection.rb`, `test/unit/active_job_task_test.rb`.

Interface: `ForemanTasks.active_job_queue_adapter` accepts the same symbols, strings,
or adapter instances as ActiveJob. `AdapterSelection` selects that value at class load.

- [x] Write failing tests that set the central value to `:test`, include the concern
  in an ActiveJob subclass, enqueue it, and assert the Rails test adapter receives
  the job while `ApplicationJob.queue_adapter_name` remains `dynflow`. Check that
  missing configuration raises `ArgumentError` and subclasses inherit selection.
- [x] Run the focused tests through the adjacent Foreman checkout and inspect failure.
- [x] Add `mattr_accessor :active_job_queue_adapter` and the selection concern:

```ruby
included do
  adapter = ForemanTasks.active_job_queue_adapter
  raise ArgumentError, 'Configure ForemanTasks.active_job_queue_adapter before including AdapterSelection' unless adapter
  self.queue_adapter = adapter
end
```

- [x] Run focused tests and inspect success.

## Task 2: Task persistence and lifecycle

Files: `app/models/foreman_tasks/task/active_job_task.rb`,
`app/models/concerns/foreman_tasks/active_job/{task_tracking,tracked}.rb`,
`db/migrate/20261009190000_add_active_job_task_data.foreman_tasks.rb`,
`lib/foreman_tasks/active_job/subscriber.rb`, `lib/foreman_tasks/engine.rb`,
`test/unit/active_job_task_test.rb`, `test/support/tracked_active_job.rb`.

Interfaces: `job.foreman_task` looks up the STI task by `job_id`. The task exposes
`input`, `output`, `humanized`, and error details without loading a Dynflow plan.
`TaskTracking#enqueue` and `#perform_now` call `super` and preserve its result.
`Tracked` includes selection before tracking. The subscriber marks observed retry,
discard, and exhausted-retry outcomes on tracked job instances.

- [x] Write failing behavior tests for immediate, delayed, and inline execution;
  same-row retries; discarded and exhausted jobs; deserialization failure; enqueue
  failure and aborted callbacks; context serialization and restoration.
- [x] Run focused tests and inspect failures.
- [x] Add the migration:

```ruby
column_type = connection.adapter_name.casecmp('postgresql').zero? ? :jsonb : :json
add_column :foreman_tasks_tasks, :job_data, column_type
add_column :foreman_tasks_tasks, :job_error, column_type
```

- [x] Implement the concerns and subclass around the specified state transitions;
  keep original ownership across retries and guard enqueue completion against inline
  execution. Serialize context under `foreman_tasks_context` and restore thread
  context with `ensure`. Store error class, message, and backtrace as JSON.
- [x] Register one ActiveSupport notification subscriber for `enqueue_retry.active_job`,
  `retry_stopped.active_job`, and `discard.active_job`, filtering by tracking concern.
- [x] Run focused tests and inspect success, including a JSON payload round trip.

## Task 3: Mixed-provider presentation and controls

Files: `app/models/foreman_tasks/task.rb`, `app/models/foreman_tasks/task/dynflow_task.rb`,
`app/views/foreman_tasks/api/tasks/{show,details}.json.rabl`,
`app/controllers/foreman_tasks/api/tasks_controller.rb`,
`app/models/foreman_tasks/task/summarizer.rb`,
`webpack/ForemanTasks/Components/TaskDetails/ExecutionDetails.js`,
`test/controllers/api/tasks_controller_test.rb`, relevant JavaScript tests, `README.md`.

Interface: generic tasks default to unsupported cancellation/stopping and absent
execution plans. Dynflow reports its existing capabilities. API details can render
either provider; bulk stop skips unsupported tasks.

- [x] Write failing API tests for ActiveJob task show/details, mixed bulk stop, and
  pending-state summaries. Verify existing Dynflow API tests continue to pass.
- [x] Add capability defaults and preserve Dynflow stopping support. Render nullable
  execution-plan information without querying Dynflow for ActiveJob tasks. Render
  ActiveJob execution errors without pretending a Dynflow plan exists.
- [x] Document central adapter configuration, one-include usage, and ActiveJob's
  provider boundary.
- [x] Run focused Ruby/JavaScript tests, the existing task and API test suites, and
  formatting checks. Review the complete diff and record any environment limitations.

## Implementation notes

The existing summarizer already supports pending states through its default state
records; a regression verifies that behavior without changing it. Execution aborts
are detected from the native `perform.active_job` aborted payload, preserving custom
exception-handler semantics. Review regressions cover direct unserializable
arguments, serializer call counts, humanized presentation after deserialization,
prepended enqueue aborts, context restoration after failure, and inline retry IDs.

## Validation results

- Rails 7.0.10 non-browser plugin suite: 244 tests, 762 assertions, zero failures,
  errors, or skips. This includes existing Dynflow task, controller, cleanup,
  summary, and action tests.
- TaskDetails and ShowTaskDetails UI suites: 15 suites, 130 tests passed. Jest used
  the adjacent Foreman's module aliases and shared dependencies through a temporary
  configuration; no dependency files or test tooling were changed.
- RuboCop: all 14 changed/new Ruby files passed. ESLint: all eight changed JavaScript
  files passed using the adjacent Foreman's dependency path. Prettier and
  `git diff --check` passed.
- Review fixes were checked by the original reviewer, with no remaining Critical
  or Important findings.
- The browser integration test fails its existing expected `h5` assertion. The
  identical failure was reproduced with the original plugin at `7a683dc` in a
  temporary archive. Ruby 3.3.10 was used for this comparison because the installed
  Selenium driver has a syntax incompatibility with Ruby 3.3.0.
