namespace :foreman_tasks do
  task :ping do
    world = if ENV['DB_CONN_STRING'].nil?
              Rake::Task['environment'].invoke
              ForemanTasks.dynflow.world
            else
              class CustomConfig < ::Dynflow::Config
                def validate(*_args); end
              end
              world_config = CustomConfig.new.tap do |config|
                config.persistence_adapter = ::Dynflow::PersistenceAdapters::Sequel.new(ENV['DB_CONN_STRING'])
                config.delayed_executor = nil
                config.executor = false
                config.connector = Proc.new { |world| ::Dynflow::Connectors::Database.new(world) }
              end
              ::Dynflow::World.new(world_config)
            end

    timeout = 2
    executors = world.coordinator.find_worlds(true)
    if executors.empty?
      fail 'foreman-tasks service not running or is not ready yet'
    end

    checks = executors.map { |executor| world.ping(executor.id, timeout) }
    checks.each(&:wait)
    if checks.any?(&:failed?)
      fail 'some executors are not responding, check %{status_url}' % { :status_url => '/foreman_tasks/dynflow/status' }
    end
    puts 'All %{count} executors are up' % { :count => executors.count }
  end
end
