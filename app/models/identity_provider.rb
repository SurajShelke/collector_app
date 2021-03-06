class IdentityProvider < ApplicationRecord
  enum provider_type: { dropbox: 1 , team_drive: 2, sharepoint: 3, box: 4, sharepoint_onprem: 5, google_drive: 6 }
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

  # Methods for Google Drive connectors
  def self.create_or_update_google_drive(args= {})
    identity_provider = find_or_initialize_by(
      provider_type: IdentityProvider.provider_types[args[:integration_type]],
      user_id:       args[:user_id]
    )

    identity_provider.uid   = args[:account_id]
    identity_provider.token = args[:refresh_token]
    identity_provider.save! ? identity_provider : nil
  end

  def self.get_google_drive_refresh_token(provider_id)
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

  # Methods for Dropbox connector
  def self.create_or_update_box(args= {})
    identity_provider = find_or_initialize_by(
      provider_type: IdentityProvider.provider_types['box'],
      user_id:       args[:user_id]
    )

    identity_provider.uid   = args[:account_id]
    identity_provider.token = args[:access_token]
    identity_provider.save! ? identity_provider : nil
  end

  def self.get_box_refresh_token(provider_id)
    provider = IdentityProvider.find_by(id: provider_id)
    provider.try(:token)
  end

  def self.create_or_update_sharepoint_onprem(args= {})
    identity_provider = find_or_initialize_by(
      provider_type: IdentityProvider.provider_types['sharepoint_onprem'],
      user_id:       args[:user_id]
    )

    identity_provider.uid   = args[:account_id]
    identity_provider.auth_info = args[:auth_info]
    identity_provider.secret = args[:secret]
    identity_provider.save! ? identity_provider : nil
  end

  def self.get_sharepoint_onprem_provider(provider_id)
    IdentityProvider.find_by(id: provider_id)
  end
end
