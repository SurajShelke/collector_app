# README

Local server URL: http://localhost:3000

Step 1 (authorize):
- Connects to dropbox: http://localhost:3000/dropbox/authorize
- This will get redirected to configured callback url after successful authorization (AppConfig.redirect_uri) ie: http://localhost:3000/dropbox/callback

Step 2 (callback) :
- Proceed create or update User details with received authentication code
- Redirects to Fetch Folders path passing User's email

Step 3 (fetch user's folders):
- fetches folders list for user using email param received.
- Returns parent folder list, and user email in json response.

Step 4 (create sources):
- Uses email param, source_type_id, organization_id, and folders list
- Creates Source for each folder detail (folder_id, folder_name).
- This will trigger fetch content job to pull dropbox contents for each source.
- Contents will be pulled only for shared links. Private content items will be skipped.
- Child folders contents will be recursively pulled.

Collectore Webhook URL for reference:
- HOSTURL/api/v1/sources/:id/fetch_content
- HOSTURL/api/v1/source_types/:id/fetch_content

Enhancement Required:
- Pull metadata for each shared link content item to create ECL content item
  with resource metadata

# JOB
- DropboxEclJob.perform_async
- SafariBooksOnlineEclJob.perform_async


# Generate git hub token 
bundle config github.com Your token
https://blog.codeship.com/managing-private-dependencies-with-bundler/

# Simulate Dropbox on local without UI
  - Consider App is running on 5000
  require 'base64'
  require 'openssl'
  require 'json'
  key_hash = {organization_id: 15,client_host: 'http://es.lvh.me:4000',source_type_id:'37b7923c-ba37-417f-b43f-b901a45b92e6'}.to_json
  secret = "34899d721ba319bb99f79847d5146093"
  encode_key = Base64.encode64(key_hash).gsub("\n","")
  digest  = OpenSSL::Digest.new('sha256')
  digest_key =  OpenSSL::HMAC.hexdigest(digest, secret, encode_key)

  decode_key = Base64.decode64(encode_key)
  decode_key_encode =  Base64.encode64(decode_key).gsub("\n","")
  decode_digest  = OpenSSL::Digest.new('sha256')
  decode_digest =  OpenSSL::HMAC.hexdigest(decode_digest, secret, decode_key_encode)
digest_key == decode_digest
 "http://localhost:5000/dropbox/authorize?auth_data=#{encode_key}&secret=#{digest_key}"