class SharepointIntegration < BaseIntegration
  attr_accessor :client,:source_id,:organization_id
  def self.get_source_name
    'sharepoint'
  end

  def self.get_fetch_content_job_queue
    :sharepoint
  end

  def self.get_credentials_from_config(source)
    source["source_config"]
  end

  def self.ecl_client_id
    AppConfig.integrations['sharepoint']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['sharepoint']['ecl_token']
  end

  #
  #  @options ={start: start, limit: limit, page: page, last_polled_at: @last_polled_at}
  #  We dont need start or limit for this Integration
  #  Whenever pagination is available we can use it
  def get_content(options={})
    @options = options
    @source_id              = @credentials["source_id"]
    @organization_id        = @credentials["organization_id"]

    @audience_principal_id  = @credentials["audience_principal_id"]
    @client_id              = @credentials["client_id"]
    @client_secret          = @credentials["client_secret"]
    @site_realm             = @credentials["site_realm"]
    @sharepoint_url         = @credentials["sharepoint_url"]
    @token                  = sharepoint_communicator(JSON.parse(@credentials['access_token'])).get_refresh_token

    fetch_content(@credentials["folder_relative_url"])
  end

  def sharepoint_communicator(token = @token)
    @communicator = @communicator || SharepointCommunicator.new(
                  client_id:              @client_id,
                  client_secret:          @client_secret,
                  site_realm:             @site_realm,
                  audience_principal_id:  @audience_principal_id,
                  sharepoint_url:         @sharepoint_url,
                  token:                  token,
                  redirect_uri:           AppConfig.integrations['sharepoint']['redirect_uri']
                )
  end

  def fetch_content(folder_relative_url)
    response = sharepoint_communicator.get_files("/_api/web/GetFolderByServerRelativeUrl('#{URI.encode(folder_relative_url)}')", { "$expand" => "Folders,Files" })
    collect_files(response)
  end

  def select_folders(folders)
    system_folders = ["Attachments", "Item", "Forms"]
    folders.select do |folder| 
      folder unless system_folders.include?(folder["Name"])
    end
  end

  def collect_files(response)
    response["Files"].each do |entry|
      entry["parent_name"] = @credentials['parent_name']
      entry["public_url"] = sharepoint_communicator.get_public_url( "/_api/web/GetFileByServerRelativeUrl('#{URI.encode(entry['ServerRelativeUrl'])}')/GetPreAuthorizedAccessUrl(48)" )
      create_content_item(entry)
    end  

    select_folders(response["Folders"]).each do |folder|
      credentials = @credentials
      credentials['folder_relative_url'] = folder["ServerRelativeUrl"]
      credentials['parent_name'] = folder["Name"]

      # Call again background job so current job is finish faster
      Sidekiq::Client.push(
        'class' => FetchContentJob,
        'queue' => self.class.get_fetch_content_job_queue.to_s,
        'args' => [self.class.to_s, credentials, @source_id, @organization_id, @options[:last_polled_at]],
        'at' => self.class.schedule_at
      )
    end
  end

  def create_content_item(entry)
    attributes = {
      name:         entry["Name"],
      description:  entry["CheckInComment"],
      url:          entry["LinkingUri"],
      content_type: 'document',
      external_id:  entry["UniqueId"],
      raw_record:   entry,
      source_id:    @source_id,
      organization_id: @organization_id,
      resource_metadata: {
        images:       [{ url: nil }],
        title:        entry["Name"],
        description:  entry["CheckInComment"],
        url:          entry["public_url"]
      },
      additional_metadata: {
        path_lower:      entry["ServerRelativeUrl"],
        parent_name:     entry["parent_name"]
      }
    }

    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, attributes)
  end
end
