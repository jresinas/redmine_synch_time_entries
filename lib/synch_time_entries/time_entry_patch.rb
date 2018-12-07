module SynchTimeEntries
  module TimeEntryPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        has_one :synch_time_entry_relation, :foreign_key => :target_id, :dependent => :destroy
      end
    end

    module ClassMethods
    end

    module InstanceMethods
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  TimeEntry.send(:include, SynchTimeEntries::TimeEntryPatch)
end
