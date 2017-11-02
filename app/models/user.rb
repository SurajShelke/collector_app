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

  def self.create_or_update_sharepoint_user(account, access_token)
    user            = find_or_initialize_by(email: account["Email"])
    user.first_name = account["Title"]
    
    if user.save!
      IdentityProvider.create_or_update_sharepoint(
        user_id: user.id,
        account_id:  account["UserId"]["NameId"],
        access_token: access_token.to_json
      )
    end
  end
end
