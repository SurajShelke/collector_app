class BoxIntegration < BaseIntegration
  attr_accessor :client
  def self.get_source_name
    'box'
  end

  def self.get_fetch_content_job_queue
    :box
  end

  def self.get_credentials_from_config(source)
    source["source_config"]
  end

  def self.ecl_client_id
    AppConfig.integrations['box']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['box']['ecl_token']
  end

  #  @options ={start: start, limit: limit, page: page, last_polled_at: @last_polled_at}
  #  We dont need start or limit for this Integration
  #  Whenever pagination is available we can use it
  def get_content(options={})
    @options = options
    @client  = client
    fetch_content(@credentials['box'], @credentials['folder_id'])
  end

  # Sample `auth_session.files` response from Google Drive API
  # [#<GoogleDrive::File id="1u5_4-NFatQPw9doeL8sZBZgSiDdjhhGn3gbUQARqBac" title="File1">,
  #  #<GoogleDrive::File id="1W8IQH7TeiSA7Exu1vVtDLAbsK3jiNtddBRWtjmbwd5U" title="File2">,
  #  #<GoogleDrive::File id="1pZfz3RRhHJ4k7T-Z2Qgjm06JhZcjmrvO_SttyLyYah0" title="File3.docx">]
  def fetch_content(box_id, folder_id)
    begin
      query = folder_id ? "'#{folder_id}'" : "'#{box_id}'"
      page_token = @options[:page] == 0 ? nil : @options[:page]

      files, new_page_token = auth_session.files

      if new_page_token.present?
        Sidekiq::Client.push(
          'class' => FetchContentJob,
          'queue' => self.class.get_fetch_content_job_queue.to_s,
          'args' => [self.class.to_s, @credentials, @credentials['source_id'], @credentials['organization_id'], @options[:last_polled_at], new_page_token],
          'at' => self.class.schedule_at
        )
      end

      collect_files(files)
    rescue StandardError => e
      Rails.logger.error "Invalid Oauth2 token, #{e.message}"
      nil
    end
  end

  def collect_files(files)
    @parents = {}
    files.each do |entry|
      #  Conisder folder has 3 sub folder and 3 file
      #  Create 3 content Item and spawn 3 different job
      # TODO add code for to check last polled at vs server update - 1 days so we will not fetched lot of data
      # time so we will not have multiple jobs to spawn every time
      if entry.mime_type == "application/vnd.google-apps.folder"
        @parents[entry.id.to_s.to_sym] = entry.name
        credentials = @credentials
        credentials['folder_id'] = entry.id

        # Call again background job so current job is finish faster
        Sidekiq::Client.push(
          'class' => FetchContentJob,
          'queue' => self.class.get_fetch_content_job_queue.to_s,
          'args' => [self.class.to_s, credentials, @credentials['source_id'], @credentials['organization_id'], @options[:last_polled_at]],
          'at' => self.class.schedule_at
        )
      else
        create_content_item(entry)
      end
    end
  end

  def create_content_item(entry, last_polled_at=nil)
    #Do not process Trashed file
    return if entry.trashed?
    #collecting parent information
    parent_name = get_parent(entry.parents.first.to_sym) if entry.parents
    attributes = {
      name: entry.name,
      description: entry.description,
      summary: entry.content_hints,
      url: entry.web_view_link,
      external_id: entry.id,
      content_type: 'document',
      source_id:     @credentials['source_id'],
      organization_id: @credentials['organization_id'],
      resource_metadata: {
        title: entry.title,
        description: entry.description,
        url: entry.web_view_link
      }
    }
    attributes.merge!(additional_metadata: {"parent_name" => parent_name}) if parent_name.present?
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, attributes)
  end

  def get_parent(parent)
    @parents[parent] if @parents && @parents.keys.include?(parent)
  end

  def client
    OAuth2::Client.new(@credentials['client_id'],
                       @credentials['client_secret'],
                       :site => "https://api.box.com",
                       :authorize_url => "/oauth2/authorize",
                       :token_url => "/oauth2/token",
                       :additional_parameters => {"grant_type" => "authorization_code"})
  end

  def auth_session
    token = get_refresh_token
    if token
      token_hash = JSON.parse(token.to_json)
      access_token = OAuth2::AccessToken.from_hash(@client, token_hash.dup)
      # access_token.refesh! if Time.now.to_i > access_token.expires_at
      # GoogleDrive.login_with_oauth(access_token)
    end
  end

  # Gets the current access token
  def get_refresh_token
  end
end
