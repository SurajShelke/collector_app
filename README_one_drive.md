# README

Local server URL: http://localhost:3000

Step 1 (authorize):
- Connects to One: http://localhost:3000/sharepoint/authorize
- This will get redirected to configured callback url after successful authorization (AppConfig.redirect_uri) ie: http://localhost:3000/sharepoint/callback

Step 2 (callback) :
- Proceed create or update User details with received authentication code
- Redirects to Fetch Folders path passing User's email

Step 3 (fetch user's folders):
- fetches folders list for user using email param received.
- Returns parent folder list, and user email in json response.

Step 4 (create sources):
- Uses email param, source_type_id, organization_id, and folders list
- Creates Source for each folder detail (folder_id, folder_name).
- This will trigger fetch content job to pull One Drive contents for each source.
- Contents will be pulled only for shared links. Private content items will be skipped.
- Child folders contents will be recursively pulled.

Collectore Webhook URL for reference:
- HOSTURL/api/v1/sources/:id/fetch_content
- HOSTURL/api/v1/source_types/:id/fetch_content

Enhancement Required:
- Pull metadata for each shared link content item to create ECL content item
  with resource metadata

# JOB
- OneDriveEclJob.perform_async

# Generate git hub token 
bundle config github.com Your token
https://blog.codeship.com/managing-private-dependencies-with-bundler/

# Simulate One Drive on local without UI
  - Consider App is running on 3000
```
  require 'base64'
  require 'openssl'
  require 'json'
  key_hash = {organization_id: 439,client_host: 'http://es.lvh.me:4000',source_type_id:'ba114a89-44ce-44ef-97fa-a88e8219d8d1'}.to_json
  secret = "da4b0aaec42c8a17183b5c52be5cd3b0"
  encode_key = Base64.encode64(key_hash).gsub("\n","")
  digest  = OpenSSL::Digest.new('sha256')
  digest_key =  OpenSSL::HMAC.hexdigest(digest, secret, encode_key)

  decode_key = Base64.decode64(encode_key)
  decode_key_encode =  Base64.encode64(decode_key).gsub("\n","")
  decode_digest  = OpenSSL::Digest.new('sha256')
  decode_digest =  OpenSSL::HMAC.hexdigest(decode_digest, secret, decode_key_encode)
  digest_key == decode_digest
  # use following URL in the web browser to launch the connector app UI interface
  puts "http://localhost:3000/sharepoint/authorize?auth_data=#{encode_key}&secret=#{digest_key}"
```
 # To run webhook using rails console
  - Input: For `webhook_type=source`, pass `source_type_id` along with `source_id` as well.
```
input = {:webhook_type=>"source", :id=>"c3610d27-05c0-4d36-9c06-8bf38a8be9cc", :source_type_id=>"ba114a89-44ce-44ef-97fa-a88e8219d8d1"}
Webhook::TriggerService.new(input).run
```