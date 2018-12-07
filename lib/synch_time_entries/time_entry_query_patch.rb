module SynchTimeEntries
  module TimeEntryQueryPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        self.available_columns << QueryColumn.new(:updated_on, :sortable => "#{TimeEntry.table_name}.updated_on", :default_order => 'desc', :groupable => true)
        alias_method_chain :initialize_available_filters, :synch
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def initialize_available_filters_with_synch
        add_available_filter "updated_on", :type => :date_past
        initialize_available_filters_without_synch
      end

      def default_columns_names_with_synch
        default_columns_names_without_synch
        @default_columns_names << :updated_on
      end
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  TimeEntryQuery.send(:include, SynchTimeEntries::TimeEntryQueryPatch)
end
