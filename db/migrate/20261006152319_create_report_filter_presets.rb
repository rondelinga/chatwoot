class CreateReportFilterPresets < ActiveRecord::Migration[7.1]
  def change
    create_table :report_filter_presets do |t|
      t.references :account, null: false, index: false
      t.references :user, null: false, index: false
      t.string :section
      t.string :name, null: false
      t.jsonb :filters, null: false, default: {}
      t.timestamps
    end

    add_index :report_filter_presets,
              [:account_id, :user_id, :name],
              unique: true,
              name: 'idx_report_filter_presets_unique_name'
  end
end
