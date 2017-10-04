class CreateIdentityProviders < ActiveRecord::Migration[5.1]
  def change
    create_table :identity_providers do |t|
      t.integer  :provider_type, null: false
      t.string   :uid, null: false
      t.string   :token
      t.string   :secret
      t.datetime :expires_at
      t.datetime :created_at
      t.datetime :updated_at
      t.json     :auth_info
      t.references :user, index: true, foreign_key: true
    end

    add_index :identity_providers, [:user_id, :provider_type], unique: true
  end
end
