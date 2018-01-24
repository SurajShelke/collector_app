require 'sharepoint-http-auth'
require 'jwt'

class SharepointOnpremIntegration < BaseIntegration
  attr_accessor :client,:source_id,:organization_id
  def self.get_source_name
    'sharepoint_onprem'
  end

  def self.get_fetch_content_job_queue
    :sharepoint_onprem
  end

  def self.get_credentials_from_config(source)
    source["source_config"]
  end

  def self.ecl_client_id
    AppConfig.integrations['sharepoint_onprem']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['sharepoint_onprem']['ecl_token']
  end

  def decode_credentials(auth_data)
    auth_data = JWT.decode(auth_data, AppConfig.digest_secret, algorithm='HS256')[0]
    @user_name  = auth_data['user_name']
    @password  = auth_data['password']
  end
  #
  #  @options ={start: start, limit: limit, page: page, last_polled_at: @last_polled_at}
  #  We dont need start or limit for this Integration
  #  Whenever pagination is available we can use it
  def get_content(options={})
    @options = options
    @source_id        = @credentials["source_id"]
    @organization_id  = @credentials["organization_id"]
    @sharepoint_url   = @credentials["sharepoint_url"]
    @site_name        = @credentials["site_name"]
    @client_secret    = @credentials["client_secret"]

    decode_credentials(@client_secret)
    @communicator = SharepointOnpremCommunicator.new(@user_name, @password, @sharepoint_url, @site_name)
    fetch_content(@credentials["folder_relative_url"])
  end

  def fetch_content(folder_relative_url)
    contents = @communicator.get_content_by_folder_relative_url(folder_relative_url)
    collect_files(contents)
  end

  def collect_files(response)
    response.files.each do |entry|
      create_content_item(entry.data)
    end

    folders = response.folders.select {|f| f unless ["Attachments", "Item", "Forms"].include?(f.name)}
    folders.each do |folder|
      credentials = @credentials
      credentials['folder_relative_url'] = folder.server_relative_url

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
    all_fields = @communicator.get_file_meta_data(entry["ServerRelativeUrl"])
    # entry["permission"] = @communicator.get_file_permission(all_fields["d"]["RoleAssignments"]["__deferred"]["uri"])
    entry["Id"] = all_fields["d"]["Id"]
    attributes = {
      name:         entry["Name"],
      description:  entry["CheckInComment"],
      url:          entry["__metadata"]["uri"],
      content_type: 'document',
      external_id:  entry["Id"],
      raw_record:   entry,
      source_id:    @source_id,
      organization_id: @organization_id,
      resource_metadata: {
        images:       [{ url: nil }],
        title:        entry["Name"],
        description:  entry["CheckInComment"],
        url:          entry["__metadata"]["uri"]
      },
      additional_metadata: {
        # permission:      entry["permission"],
        path_lower:      entry["ServerRelativeUrl"],
        parent_name:     entry["parent_name"]
      }
    }
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, attributes)
  end
end
