module ForemanTasksCore
  module TaskLauncher
    class Batch < Abstract
      class ParentAction < ::Dynflow::Action
        include Dynflow::Action::WithSubPlans
        include Dynflow::Action::WithPollingSubPlans

        # { task_id => { :action_class => Klass, :input => input } }
        def plan(launcher, input_hash)
          launcher.launch_children(self, input_hash)
          plan_self
        end

        def initiate
          ping suspended_action
          wait_for_sub_plans sub_plans
        end
      end

      def launch!(input)
        trigger(nil, ParentAction, self, input)
      end

      def launch_children(parent, input_hash)
        input_hash.each do |task_id, input|
          launcher = child_launcher(parent)
          launcher.launch!(input)
          results[task_id] = launcher.results
        end
      end

      private

      def child_launcher(parent)
        Single.new(world, callback, :parent => parent)
      end
    end
  end
end
