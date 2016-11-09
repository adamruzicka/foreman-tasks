module ForemanTasks
  module ExternalPresenters
    class SmartProxyDynflow < Abstract

      attr_reader :status

      RESULT_ICON_MAP = {
        'pending' => 'fa fa-question-circle-o',
        'success' => 'pf pficon-ok',
        'warning' => 'pf pficon-warning-triangle-o',
        'error'   => 'pf pficon-error-circle-o'
      }

      def locals
        super.merge(:data => @data)
      end

      def data_source_name
        _("Smart Proxy at #{delegated_action.input[:proxy_url]}")
      end

      def link_to_external_task
        url = File.join(delegated_action.input[:proxy_url], 'dynflow/console', external_task_id)
        content_tag(:a, external_task_id, :href => url)
      end

      def state_icon(step)
        RESULT_ICON_MAP[step['state']]
      end

      def result_tag
        content_tag(:i, nil, :class => RESULT_ICON_MAP[@data['result']]) + ' ' + @data['result']
      end

      def action_state(action)
        states = action.values_at('plan_step', 'run_step', 'finalize_step').compact.map { |step| step['state'] }
        if states.all? { |state| state == 'success' }
          'success'
        elsif states.any? { |state| state == 'warning'}
          'warning'
        elsif states.any? { |state| state == 'error' }
          'error'
        else
          'N/A'
        end

      end

      def action_name
        @data['phase']['plan']['action_class']
      end

      def actions
        if @actions.nil?
          @actions = recurse_children(@data['phase']['plan']).flatten.reduce({}) do |cur, action|
            cur.update(action['action_id'] => { 'plan_step' => action })
          end
          @actions = add_steps(@actions)
        end
      end

      def list_item_icon(action)
        states = action.values_at('plan_step', 'run_step', 'finalize_step').compact.map { |step| step['state'] }
        if states.all? { |state| state == 'success' }
          'pficon pficon-ok list-view-pf-icon-md list-view-pf-icon-success'
        elsif states.any? { |state| state == 'warning'}
          'pficon pficon-warning-triangle-o list-view-pf-icon-md list-view-pf-icon-warning'
        elsif states.any? { |state| state == 'error' }
          'pficon pficon-error-circle-o list-view-pf-icon-md list-view-pf-icon-danger'
        else
          'pficon pficon-info list-view-pf-icon-md list-view-pf-icon-info'
        end
      end

      private

      def add_steps(hash)
        %w(run finalize).each do |kind|
          steps = flat_steps(@data['phase'][kind]).flatten
          steps.uniq.each do |step|
            id = step['action_id']
            hash.update(id => hash[id].update("#{kind}_step" => step))
          end
        end
        hash
      end

      def flat_steps(phase)
        if phase['type'] == 'atom'
          phase['step']
        else
          phase['steps'].map { |step| flat_steps(step) }
        end
      end

      def recurse_children(step)
        children = step.delete('children')
        [step] << children.map { |child| recurse_children(child) }
      end

      def load_external_data
        @data = proxy_api.task_export(external_task_id)
      end

      def proxy_api
        @api ||= ::ProxyAPI::ForemanDynflow::DynflowProxy.new(:url => delegated_action.input[:proxy_url])
      end

      def external_task_id
        @external_task_id ||= delegated_action.output[:proxy_task_id]
      end

      def delegated_action
        @delegated_action ||= @task.execution_plan.actions.find do |action|
          action.id == @task.input['delegated_action_id']
        end
      end
    end
  end
end