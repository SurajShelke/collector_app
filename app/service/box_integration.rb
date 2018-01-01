class BoxIntegration < BaseIntegration
  include ContentExtractionService

  FOLDER_ITEMS_LIMIT = 1000

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
    @extract_content = @credentials["extract_content"]
    fetch_content(@credentials['folder_id'])
  end

  def fetch_content(folder_id)
    begin
      page_token = @options[:page] == 0 ? nil : @options[:page]

      @boxr_client = get_boxr_client

      folder = @boxr_client.folder_from_id(folder_id, fields: [])
      files =  @boxr_client.folder_items(folder, fields: [], offset: 0, limit: FOLDER_ITEMS_LIMIT)

      # if new_page_token.present?
      #   Sidekiq::Client.push(
      #     'class' => FetchContentJob,
      #     'queue' => self.class.get_fetch_content_job_queue.to_s,
      #     'args' => [self.class.to_s, @credentials, @credentials['source_id'], @credentials['organization_id'], @options[:last_polled_at], new_page_token],
      #     'at' => self.class.schedule_at
      #   )
      # end

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
      if entry.type == "folder"
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
    # return if entry.trashed?
    # content = get_file_content(entry.web_view_link) if @extract_content && @extract_content == "true"
    # collecting parent information
    # parent_name = get_parent(entry.parents.first.to_sym) if entry.parents
    download_url = @boxr_client.download_url(entry)
    attributes = {
      name: entry.name,
      description: entry.description,
      # summary: entry.content_hints,
      url: download_url,
      external_id: entry.id,
      content_type: 'document',
      # content:      content,
      source_id:     @credentials['source_id'],
      organization_id: @credentials['organization_id'],
      resource_metadata: {
        title: entry.title,
        description: entry.description,
        url: download_url
      }
    }
    attributes.merge!(additional_metadata: {"sharable_link" => @boxr_client.create_shared_link_for_file(entry)})
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, attributes)
  end

  # def get_parent(parent)
  #   @parents[parent] if @parents && @parents.keys.include?(parent)
  # end

  def client
    OAuth2::Client.new(@credentials['client_id'],
                       @credentials['client_secret'],
                       :site => "https://api.box.com",
                       :authorize_url => "/api/oauth2/authorize",
                       :token_url => "/oauth2/token",
                       :grant_type => "authorization_code")
  end

  def get_boxr_client
    token = get_access_token
    if token
      token_hash = JSON.parse(token.to_json)
      access_token = OAuth2::AccessToken.from_hash(@client, token_hash.dup)
      Boxr::Client.new(access_token.token)
    end
  end

  # Gets the current access token
  def get_access_token
    params = {
                client_id: @credentials['client_id'],
                client_secret: @credentials['client_secret'],
                refresh_token: @credentials['refresh_token'],
                grant_type: 'refresh_token'
              }
    conn = Faraday.new('https://api.box.com')
    response = conn.post do |req|
      req.url '/oauth2/token'
      req.headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
      req.body = params
    end
    response = JSON.parse(response.body)

    # Update refresh_token in the database as Box's refresh tokens are valid for a single refresh
    provider = IdentityProvider.find_by(token: @credentials['refresh_token'])
    provider.update_attribute(:token, response["refresh_token"]) if provider

    # Update refresh_token in the integration framework as Box's refresh tokens are valid for a single refresh
    ecl_service = EclDeveloperClient::Source.new(AppConfig.integrations['box']['ecl_client_id'], AppConfig.integrations['box']['ecl_token'])
    ecl_service.update(@credentials["source_id"], { refresh_token: response["refresh_token"] })

    OAuth2::AccessToken.new(nil, response["access_token"])
  end

end
