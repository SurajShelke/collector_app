class IdentityProvider < ApplicationRecord
  enum provider_type: { dropbox: 1 }
  belongs_to :user

  def self.create_or_update_dropbox(args= {})
    identity_provider = find_or_initialize_by(
      provider_type: IdentityProvider.provider_types['dropbox'],
      user_id:       args[:user_id]
    )

    identity_provider.uid   = args[:account_id]
    identity_provider.token = args[:access_token]
    identity_provider.save!
  end

  def self.get_dropbox_access_token(email)
    user = User.find_by(email: email)

    if user
      provider = IdentityProvider.find_by(
        user_id: user.id,
        provider_type: IdentityProvider.provider_types['dropbox']
      )
      provider.try(:token)
    end
  end
end
