class IdentityProvider < ApplicationRecord
  enum provider_type: { dropbox: 1 , team_drive: 2, sharepoint: 3 }
  belongs_to :user

  # Methods for Dropbox connector
  def self.create_or_update_dropbox(args= {})
    identity_provider = find_or_initialize_by(
      provider_type: IdentityProvider.provider_types['dropbox'],
      user_id:       args[:user_id]
    )

    identity_provider.uid   = args[:account_id]
    identity_provider.token = args[:access_token]
    identity_provider.save! ? identity_provider : nil
  end

  def self.get_dropbox_access_token(provider_id)
    provider = IdentityProvider.find_by(id: provider_id)
    provider.try(:token)
  end

  # Methods for Team Drive connector
  def self.create_or_update_google_team_drive(args= {})
    identity_provider = find_or_initialize_by(
      provider_type: IdentityProvider.provider_types['team_drive'],
      user_id:       args[:user_id]
    )

    identity_provider.uid   = args[:account_id]
    identity_provider.token = args[:refresh_token]
    identity_provider.save! ? identity_provider : nil
  end

  def self.get_team_drive_refresh_token(provider_id)
    provider = IdentityProvider.find_by(id: provider_id)
    provider.try(:token)
  end

  def self.create_or_update_sharepoint(args= {})
    identity_provider = find_or_initialize_by(
      provider_type: IdentityProvider.provider_types['sharepoint'],
      user_id:       args[:user_id]
    )

    identity_provider.uid    = args[:account_id]
    identity_provider.token  = args[:access_token]
    identity_provider.secret = args[:refresh_token]
    identity_provider.expires_at = Time.at(args[:expires_at])
    identity_provider.save! ? identity_provider : nil
  end

  def self.get_sharepoint_access_token(provider_id)
    provider = IdentityProvider.find_by(id: provider_id)
    provider.try(:token)
  end
end
