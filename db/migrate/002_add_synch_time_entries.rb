class AddSynchTimeEntries < ActiveRecord::Migration
  def self.up
    create_table :synch_time_entry_relations do |t|
      t.column :source_id, :integer, :null => false
      t.column :target_id, :integer, :null => false
      t.column :last_update, :datetime, :null => false
      t.column :spent_on, :date, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :synch_time_entry_relations
  end
end