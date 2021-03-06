class User < ApplicationRecord
  has_many :identity_providers

  def self.create_or_update_dropbox_user(account, access_token)
    user            = find_or_initialize_by(email: account.email)
    user.first_name = account.name.given_name
    user.last_name  = account.name.surname

    if user.save!
      IdentityProvider.create_or_update_dropbox(
        user_id: user.id,
        account_id: account.account_id,
        access_token: access_token
      )
    end
  end

  def self.create_or_update_google_drive_user(account, refresh_token, integration_type) # integration_type = 'google_drive' or 'team_drive'
    user            = find_or_initialize_by(email: account["email"])
    user.first_name = account["given_name"]
    user.last_name  = account["family_name"]

    if user.save!
      IdentityProvider.create_or_update_google_drive(
        user_id: user.id,
        account_id: account["id"],
        refresh_token: refresh_token,
        integration_type: integration_type
      )
    end
  end

  def self.create_or_update_sharepoint_user(access_token, refresh_token, expires_at, email, name)
    user            = find_or_initialize_by(email: email)
    user.first_name = name

    if user.save!
      IdentityProvider.create_or_update_sharepoint(
        user_id: user.id,
        account_id:  email,
        access_token: access_token,
        refresh_token: refresh_token,
        expires_at: expires_at
      )
    end
  end

  def self.create_or_update_box_user(account, access_token)
    user            = find_or_initialize_by(email: account.login)
    user.first_name = account.name

    if user.save!
      IdentityProvider.create_or_update_dropbox(
        user_id: user.id,
        account_id: account.id,
        access_token: access_token
      )
    end
  end

  def self.create_or_update_sharepoint_onprem_user(id, user_name, auth_data, secret)
    user            = find_or_initialize_by(email: id)
    user.first_name = user_name
    
    if user.save!
      IdentityProvider.create_or_update_sharepoint_onprem(
        user_id: user.id,
        account_id:  id,
        secret: secret,
        auth_info: auth_data
      )
    end
  end
end
