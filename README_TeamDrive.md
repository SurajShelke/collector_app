# README

# Register an application with Google
- Register new application using Google API Console dashboard. Reference: [About Google authorization](https://developers.google.com/drive/v3/web/about-auth)
- Google then provides information we need later, such as a client ID and a client secret.
- Activate the Drive API in the Google API Console.
- Refer sample application registration screenshot at public/GoogleTeamDriveAppRegistration.png and [wiki page](https://github.com/Course-Master/collector_app/wiki/Register-an-application-with-third-party-services-and-Connector-Configurations).

Local server URL: http://localhost:3000

Step 1 (authorize):
- Connects to team_drive: http://localhost:3000/google_team_drive/authorize
- This will get redirected to configured callback url after successful authorization (AppConfig.redirect_uri) ie: http://localhost:3000/google_team_drive/callback

Step 2 (callback) :
- Proceed create or update User details with received authentication code
- Redirects to Fetch Folders path passing User's email

Step 3 (fetch user's folders):
- fetches folders list for user using email param received.
- Returns parent folder list, and user email in json response.

Step 4 (create sources):
- Uses email param, source_type_id, organization_id, and folders list
- Creates Source for each folder detail (folder_id, folder_name).
- This will trigger fetch content job to pull team_drive contents for each source.
- Contents will be pulled only for shared links. Private content items will be skipped.
- Child folders contents will be recursively pulled.

Collectore Webhook URL for reference:
- HOSTURL/api/v1/sources/:id/fetch_content
- HOSTURL/api/v1/source_types/:id/fetch_content

Enhancement Required:
- Pull metadata for each shared link content item to create ECL content item
  with resource metadata

# JOB
- TeamDriveEclJob.perform_async

# Generate git hub token
bundle config github.com Your token
https://blog.codeship.com/managing-private-dependencies-with-bundler/

http://localhost:3000/google_team_drive/authorize?organization_id=&source_type_id=&client_host=localhost
# Simulate team drive on local without UI
  - Consider App is running on 3000
```
  require 'base64'
  require 'openssl'
  require 'json'
  key_hash = {organization_id: 439, client_host: 'http://es.lvh.me:4000', source_type_id:'f8ad2ed9-d1eb-4ec5-80d0-7ca0088baa9a'}.to_json
  secret = "34899d721ba319bb99f79847d5146093"
  encode_key = Base64.encode64(key_hash).gsub("\n","")
  digest  = OpenSSL::Digest.new('sha256')
  digest_key =  OpenSSL::HMAC.hexdigest(digest, secret, encode_key)

  decode_key = Base64.decode64(encode_key)
  decode_key_encode =  Base64.encode64(decode_key).gsub("\n","")
  decode_digest  = OpenSSL::Digest.new('sha256')
  decode_digest =  OpenSSL::HMAC.hexdigest(decode_digest, secret, decode_key_encode)
  digest_key == decode_digest
  # use following URL in the web browser to launch the connector app UI interface
  puts "http://localhost:3000/google_team_drive/authorize?auth_data=#{encode_key}&secret=#{digest_key}"
```
 # To run webhook using rails console
  - Input: For `webhook_type=source`, pass `source_type_id` along with `source_id` as well.
```
input = {:webhook_type=>"source", :id=>"9bff2b98-ec9b-4eda-bcbc-69d7b587a177", :source_type_id=>"f8ad2ed9-d1eb-4ec5-80d0-7ca0088baa9a"}
Webhook::TriggerService.new(input).run
```
