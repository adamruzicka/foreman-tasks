module ForemanTasks
  module ExternalPresenters
    class Abstract

      include ActionView::Helpers::TagHelper

      attr_reader :task, :exception

      class RetrievalFailed < ::Exception; end

      HANDLED_EXCEPTIONS = [Errno::ECONNREFUSED, RestClient::NotFound, RetrievalFailed]

      def initialize(task)
        @task = task
      end

      def to_partial_path
        self.class.name.underscore
      end

      def load_external_data!
        with_error_handling do
          load_external_data
        end
      end

      def data_source_name
        self.class.name.to_s
      end

      def locals
        {
          :presenter => self
        }
      end

      def link_to_external_service
      end

      private

      def with_error_handling
        yield if block_given?
        true
      rescue *HANDLED_EXCEPTIONS => e
        @exception = e
        false
      end

      def load_external_data
        raise NotImplementedError
      end

    end
  end
end