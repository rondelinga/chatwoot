class CreateRoutingTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :routing_types do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :attribute_key, null: false
      t.string :attribute_value, null: false
      t.timestamps
    end
    add_index :routing_types, [:account_id, :attribute_key, :attribute_value],
              unique: true, name: 'idx_routing_types_unique_attr'
  end
end
