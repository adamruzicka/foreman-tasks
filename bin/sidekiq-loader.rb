rails_root = Dir.pwd

app_file = File.expand_path('./config/application', rails_root)
require app_file

rails_env_file = File.expand_path('./config/environment.rb', rails_root)

::Rails.application.dynflow.config.process_role =
  if Sidekiq.options[:queues].include?("dynflow_orchestrator")
    ::Rails.application.dynflow.executor!
    :orchestrator
  elsif (Sidekiq.options[:queues] - ['dynflow_orchestrator']).any?
    ::Rails.application.dynflow.config.remote = true
    :worker
  end

require rails_env_file
::Rails.application.dynflow.initialize!
world_id = ::Rails.application.dynflow.world.id
STDOUT.puts("Everything ready for world: #{world_id}")
