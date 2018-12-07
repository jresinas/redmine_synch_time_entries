class AddSynchRelations < ActiveRecord::Migration
  def self.up
    create_table :synch_relations do |t|
      t.column :source_id, :integer, :null => false
      t.column :source_name, :string, :null => false
      t.column :target_id, :integer, :null => false
      t.column :data_type, :string, :null => false
    end

    add_index :synch_relations, [:data_type, :target_id]
  end

  def self.down
    drop_table :synch_relations
  end
end