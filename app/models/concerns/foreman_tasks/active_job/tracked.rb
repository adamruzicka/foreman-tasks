module ForemanTasks
  module ActiveJob
    module Tracked
      extend ActiveSupport::Concern

      include AdapterSelection
      include TaskTracking
    end
  end
end
