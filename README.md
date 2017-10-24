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