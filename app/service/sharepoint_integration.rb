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

  #  @options ={start: start, limit: limit, page: page, last_polled_at: @last_polled_at}
  #  We dont need start or limit for this Integration
  #  Whenever pagination is available we can use it
  def get_content(options={})
    @options = options
    @source_id               = @credentials["source_id"]
    @organization_id         = @credentials["organization_id"]
    @sharepoint_url          = @credentials["sharepoint_url"]
    @client_id               = AppConfig.integrations['sharepoint']['client_id']
    @client_secret           = AppConfig.integrations['sharepoint']['client_secret']
    @sharepoint_communicator = SharepointCommunicator.new(
      client_id:      @client_id,
      client_secret:  @client_secret,
      refresh_token:  @credentials['refresh_token']
    )

    # this will update @sharepoint_communicator @token variable
    @sharepoint_communicator.get_access_token
    fetch_content(@credentials["folder_id"])
  end

  def fetch_content(folder_id)
    response = @sharepoint_communicator.files("/v1.0/sites/#{@sharepoint_url}/drive/items/#{folder_id}/children")
    collect_files(response)
    fetch_next_content(response["@odata.nextLink"]) if response["@odata.nextLink"]
  end

  def fetch_next_content(url)
    response = @sharepoint_communicator.next_page_files(url)
    collect_files(response)
    fetch_next_content(response["@odata.nextLink"]) if response["@odata.nextLink"]
  end

  def collect_files(response)
    response["value"].each do |entry|
      if entry["folder"]
        credentials = @credentials
        credentials['folder_id'] = entry["id"]

        # Call again background job so current job is finish faster
        Sidekiq::Client.push(
          'class' => FetchContentJob,
          'queue' => self.class.get_fetch_content_job_queue.to_s,
          'args' => [self.class.to_s, credentials, @source_id, @organization_id, @options[:last_polled_at]],
          'at' => self.class.schedule_at
        )
      else
        create_content_item(entry)
      end
    end
  end

  def create_content_item(entry)
    permission = @sharepoint_communicator.files("/v1.0/sites/#{@sharepoint_url}/drive/items/#{entry["id"]}/permissions")
    entry["permission"] = permission
    attributes = {
      name:         entry["name"],
      description:  "",
      url:          entry["webUrl"],
      content_type: 'document',
      external_id:  entry["id"],
      raw_record:   entry,
      source_id:    @source_id,
      organization_id: @organization_id,
      resource_metadata: {
        images:       [{ url: nil }],
        title:        entry["name"],
        description:  "",
        url:          entry["@microsoft.graph.downloadUrl"]
      },
      additional_metadata: {
        size:            entry['size'],
        cTag:            entry['cTag'],
        eTag:            entry['eTag']#,
        # permission:      entry['permission']
      }
    }

    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, attributes)
  end
end
