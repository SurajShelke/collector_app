class LinkedinLearningIntegration < BaseIntegration

  LINKEDIN_LEARNING_BASE_URL = "https://api.linkedin.com/v2"

  def self.get_source_name
    'linkedin_learning'
  end

  def self.get_fetch_content_job_queue
    :linkedin_learning
  end

  def self.get_credentials_from_config(config)
    source["source_config"]
  end

  def self.ecl_client_id
    AppConfig.integrations['linkedin_learning']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['linkedin_learning']['ecl_token']
  end

  def self.per_page
    50
  end

  def courses_url
    "#{LINKEDIN_LEARNING_BASE_URL}/learningAssets"
  end

  def get_content(options={})
    begin
      per_page = options[:limit]
      param = { "q": "localeAndType",
              "assetType": "COURSE",
              "sourceLocale.language": "en",
              "sourceLocale.country": "US",
              "expandDepth": "1",
              "includeRetired": "false",
              "start": options[:start],
              "count": per_page }
      data = json_request(courses_url, :get, params: param, headers: { 'Authorization' => "Bearer #{get_access_token}", 'referer' => 'urn:li:partner:edcast' })
      if data["elements"].present?
        data["elements"].map { |entry| create_content_item(entry) }
        if options[:page] == 0
          (1..(data['paging']['total']/per_page)).each do |page|
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
      auth_url = "https://www.linkedin.com/oauth/v2/accessToken?#{auth_param.to_query}"
      auth_data = json_request(auth_url, :get, params:{}, headers: { 'referer' => 'urn:li:partner:edcast' })
      auth_data["access_token"] if auth_data
    rescue => err
      raise Webhook::Error::IntegrationFailure, "[LinkedinLearningIntegration] Failed to get access token, ErrorMessage: #{err.message}"
    end
  end

  def content_item_attributes(entry)
    details = entry['details']

    deep_link_url = ''
    # aiccLaunch: the launch URL of the learning asset that can be used to initiate AICC tracking in an AICC-compliant system.
    # aiccLaunch is the URL of LinkedIn Learning content, a URL that includes an identifier for a specific organization
    # webLaunch : the launch URL of the learning asset in the LinkedIn Learning web application.
    if details['urls'].present?
      deep_link_url = details['urls']['aiccLaunch'] || details['urls']['webLaunch']
    end

    {
      external_id:  entry['urn'],
      source_id:    @credentials["source_id"],
      url:          deep_link_url,
      name:         sanitize_content(entry['title']['value']),
      description:  sanitize_content(details['description']['value']),
      raw_record:   entry,
      content_type: 'course',
      organization_id: @credentials["organization_id"],

      additional_metadata: {
      },

      resource_metadata: {
        title:       sanitize_content(entry['title']['value']),
        description: sanitize_content(details['description']['value']),
        url:         deep_link_url,
        images:      [{ url: details['images']['primary'] }],
        level:       details['level'],
        type:        entry['type']
      }
    }
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
