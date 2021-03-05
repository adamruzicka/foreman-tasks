module ForemanTasksCore
  module TaskLauncher
    class AdaptiveBatch < Abstract
      def launch!(input)
        if input.count == 1
          launch_single input
        else
          launch_batch input
        end
      end

      private

      def launch_single(input)
        launcher = Single.new(@world, @callback, @options)
        launcher.launch!(input.values.first)
        results[input.keys.first] = launcher.results
      end

      def launch_batch(input)
        launcher = Batch.new(@world, @callback, @options)
        launcher.launch!(input)
        @results = launcher.results
      end
    end
  end
end
