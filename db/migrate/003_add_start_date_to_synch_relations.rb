class AddStartDateToSynchRelations < ActiveRecord::Migration
	def self.up
		add_column :synch_relations, :start_date, :date
	end

	def self.down
		remove_column :synch_relations, :start_date
	end
end