require 'sharepoint_communicator'
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
    @drive_id                = @credentials["drive_id"]
    @client_id               = AppConfig.integrations['sharepoint']['client_id']
    @client_secret           = AppConfig.integrations['sharepoint']['client_secret']
    # @extract_content         = @credentials["extract_content"]
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
    if folder_id == @drive_id
      parent_url = @sharepoint_communicator.files("/v1.0/drives/#{@drive_id}/root")["webUrl"]
      response = @sharepoint_communicator.files("/v1.0/drives/#{@drive_id}/root/children")
    else
      parent_url = @sharepoint_communicator.files("/v1.0/drives/#{@drive_id}/items/#{folder_id}")["webUrl"]
      response = @sharepoint_communicator.files("/v1.0/drives/#{@drive_id}/items/#{folder_id}/children")
    end
    collect_files(response, parent_url)
    fetch_next_content(response["@odata.nextLink"], parent_url) if response["@odata.nextLink"]
  end

  def fetch_next_content(url, parent_url)
    response = @sharepoint_communicator.next_page_files(url)
    collect_files(response, parent_url)
    fetch_next_content(response["@odata.nextLink"], parent_url) if response["@odata.nextLink"]
  end

  def collect_files(response, parent_url)
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
        create_content_item(entry, parent_url)
      end
    end
  end
  
  def deep_link(entry, parent_url)
    "#{parent_url}/#{URI.encode(entry["name"])}"
  end
  
  def create_content_item(entry, parent_url)
    # content = @sharepoint_communicator.get_file_content(entry["@microsoft.graph.downloadUrl"]) if @extract_content && @extract_content == "true"
    image_url = thumbnail_url(entry["id"])
    attributes = {
      name:         entry["name"],
      description:  "",
      url:          deep_link(entry, parent_url),
      content_type: 'document',
      # content:      content,
      external_id:  entry["id"],
      raw_record:   entry,
      source_id:    @source_id,
      organization_id: @organization_id,
      resource_metadata: {
        images:       image_url,
        title:        entry["name"],
        description:  "",
        url:          deep_link(entry, parent_url)
      },
      additional_metadata: {
        desktop_url:     entry["webUrl"],
        mobile_url:      "#{parent_url}/#{URI.encode(entry["name"])}",
        size:            entry['size'],
        cTag:            entry['cTag'],
        eTag:            entry['eTag']
      }
    }

    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, attributes)
  end

  def thumbnail_url(record_id)
    image_data = @sharepoint_communicator.files("/v1.0/drives/#{@drive_id}/items/#{record_id}/thumbnails")
    response = []
    image_data["value"].each { |data| response << { url: data['medium']['url'] } if data['medium'] } if image_data && image_data["value"].any?
    response
  end
end
