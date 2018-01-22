# README

Local server URL: http://localhost:3000

Step 1 (fetch user's folders):
- Connects to sharepoint: http://localhost:3000/sharepoint_onprem/fetch_folders
- Returns parent folder list, and user email in json response.

Step 2 (create sources):
- Uses email param, source_type_id, organization_id, and folders list
- Creates Source for each folder detail (folder_id, folder_name).
- This will trigger fetch content job to pull sharepoint on premise contents for each source.
- Contents will be pulled only for shared links. Private content items will be skipped.
- Child folders contents will be recursively pulled.

Collectore Webhook URL for reference:
- HOSTURL/api/v1/sources/:id/fetch_content
- HOSTURL/api/v1/source_types/:id/fetch_content

Enhancement Required:
- Pull metadata for each shared link content item to create ECL content item
  with resource metadata

# JOB
- SharepointOnpremEclJob.perform_async

# Generate git hub token 
bundle config github.com Your token
https://blog.codeship.com/managing-private-dependencies-with-bundler/

# Simulate Sharepoint on premise on local without UI
  - Consider App is running on 3000
```
  require 'base64' 
  require 'openssl' 
  require 'json' 
  key_hash = {organization_id: 439, client_host: 'http://es.lvh.me:4000', source_type_id:'7dc13b41-ab20-4c9f-9b1c-e097458454ad', user_name: 'edcast', password: 'Edcast@123456', sharepoint_url: 'http://sharepoint.edcastcloud.com'}.to_json 
  secret = "da4b0aaec42c8a17183b5c52be5cd3b0" 
  encode_key = Base64.encode64(key_hash).gsub("\n","") 
  digest = OpenSSL::Digest.new('sha256') 
  digest_key = OpenSSL::HMAC.hexdigest(digest, secret, encode_key)
  decode_key = Base64.decode64(encode_key) 
  decode_key_encode = Base64.encode64(decode_key).gsub("\n","") 
  decode_digest = OpenSSL::Digest.new('sha256') 
  decode_digest = OpenSSL::HMAC.hexdigest(decode_digest, secret, decode_key_encode) 
  digest_key == decode_digest
  puts "http://localhost:3000/sharepoint_onprem/fetch_folders?auth_data=#{encode_key}&secret=#{digest_key}"
```
 # To run webhook using rails console
  - Input: For `webhook_type=source`, pass `source_type_id` along with `source_id` as well.
```
input = {:webhook_type=>"source", :id=>"9bff2b98-ec9b-4eda-bcbc-69d7b587a177", :source_type_id=>"7dc13b41-ab20-4c9f-9b1c-e097458454ad"}
Webhook::TriggerService.new(input).run
```