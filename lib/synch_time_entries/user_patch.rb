module SynchTimeEntries
  module UserPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        has_many :synch_relations, :as => :target, :foreign_type => :data_type, :dependent => :destroy
      end
    end

    module ClassMethods
    end

    module InstanceMethods
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  User.send(:include, SynchTimeEntries::UserPatch)
end
