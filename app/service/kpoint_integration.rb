class KpointIntegration < BaseIntegration
  attr_accessor :client,:source_id,:organization_id
  def self.get_source_name
    'kpoint'
  end

  def self.get_fetch_content_job_queue
    :kpoint
  end

  def self.get_credentials_from_config(source)
    source["source_config"]
  end

  def self.ecl_client_id
    AppConfig.integrations['kpoint']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['kpoint']['ecl_token']
  end

  def kapsules_url(current_page, per_page)
    start = (current_page.to_i * per_page) + 1
    "#{AppConfig.integrations['kpoint']['request_uri']}/api/v1/xapi/kapsules/popular"
  end

  def get_content(options={})
    @options = options
    @source_id       = @credentials["source_id"]
    @organization_id = @credentials["organization_id"]
    begin
      per_page = 20
      kapsules_paginated_url = kapsules_url(options[:page], per_page)
      data = json_request(kapsules_paginated_url, :get, params:{}, headers:{})
      if data["list"].present?
        data["list"].map { |entry| create_content_item(entry) }
        if options[:page] == 0
          (1..(data['totalcount']/per_page)).each do |page|
            Sidekiq::Client.push(
              'class' => FetchContentJob,
              'queue' => self.class.get_fetch_content_job_queue.to_s,
              'args' => [ self.class.to_s, @credentials, @credentials["source_id"], @credentials["organization_id"], options[:last_polled_at], page]
            )
          end
        end
      end
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[LinkedinLearningIntegration] Failed Integration for source #{@credentials['source_id']} => Page: #{options[:page]}, ErrorMessage: #{err.message}"
    end
  end

  def get_access_token
    begin
      auth_param = {  grant_type: "client_credentials", 
                      client_id: @credentials['client_id'], 
                      client_secret: @credentials['client_secret']
                   }
      auth_url = ""
      auth_data = json_request(auth_url, :get, params:{}, headers:{})
      auth_data["access_token"] if auth_data
    rescue => err
      raise Webhook::Error::IntegrationFailure, "[KpointIntegration] Failed to get access token, ErrorMessage: #{err.message}"
    end
  end

  def content_item_attributes(entry)
    {
      name:         entry['displayname'],
      url:          entry['url'],
      source_id:    @source_id,
      description:  entry['description'],
      external_id:  entry['kapsule_id'],
      content_type: 'video',
      organization_id: @organization_id,
      resource_metadata: {
        title:        entry['displayname'],
        description:  entry['description'],
        url:          entry['url']
      },
      additional_metadata: {
        images:     entry['images']['thumb'],
        status:     entry['status'],
        ratings:    entry['ratings'],
        visibility: entry['visibility'],
        like_count: entry['like_count'],
        owner_name: entry['owner_name'],
        view_count: entry['view_count'],
        download_url:         entry['download_url'],
        published_duration:   entry['published_duration'],
        download_video_path:  entry['download_video_path'],
      }
    }
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
