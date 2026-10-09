class AddActiveJobTaskData < ActiveRecord::Migration[7.0]
  def change
    # PostgreSQL's json type cannot participate in the distinct task queries.
    column_type = connection.adapter_name.casecmp('postgresql').zero? ? :jsonb : :json
    add_column :foreman_tasks_tasks, :job_data, column_type
    add_column :foreman_tasks_tasks, :job_error, column_type
  end
end
