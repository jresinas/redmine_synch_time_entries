module SynchTimeEntries
  module IssuePatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        has_one :synch_relation, :as => :target, :dependent => :destroy
      end
    end

    module ClassMethods
    end

    module InstanceMethods
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  Issue.send(:include, SynchTimeEntries::IssuePatch)
end
