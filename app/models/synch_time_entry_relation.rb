class SynchTimeEntryRelation < ActiveRecord::Base
	belongs_to :time_entry, :foreign_key => :target_id

end