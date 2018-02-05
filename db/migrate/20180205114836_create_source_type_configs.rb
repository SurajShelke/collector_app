class CreateSourceTypeConfigs < ActiveRecord::Migration[5.1]
  def change
    create_table :source_type_configs do |t|
      t.string   :source_type_name, null: false
      t.uuid     :source_type_id, null: false
      t.json     :values
    end

    add_index :source_type_configs, :source_type_id, unique: true
  end
end
