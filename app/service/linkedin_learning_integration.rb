class LinkedinLearningIntegration < BaseIntegration

  LINKEDIN_LEARNING_BASE_URL = "https://api.linkedin.com/v2"

  def self.get_source_name
    'linkedin_learning'
  end

  def self.get_fetch_content_job_queue
    :linkedin_learning
  end

  def self.get_credentials_from_config(config)
    config["source_config"]
  end

  def self.ecl_client_id
    AppConfig.integrations['linkedin_learning']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['linkedin_learning']['ecl_token']
  end

  def self.per_page
    100
  end

  def courses_url
    "#{LINKEDIN_LEARNING_BASE_URL}/learningAssets"
  end

  def asset_types
    (@credentials['asset_type'] || '').upcase.split(',')
  end

  def get_content(options={})
    asset_types.each do |asset_type|
      begin
        per_page = options[:limit]
        param = { "q": "localeAndType",
                "assetType": asset_type,
                "sourceLocale.language": "en",
                "sourceLocale.country": "US",
                "expandDepth": "1",
                "includeRetired": "false",
                "start": options[:start],
                "count": per_page }
        data = json_request(courses_url, :get, params: param, headers: { 'Authorization' => "Bearer #{get_access_token}", 'referer' => 'urn:li:partner:edcast' })
        if data["elements"].present?
          data["elements"].map do |entry|
            if push_content_item?(options[:last_polled_at], entry['details']['lastUpdatedAt'])
              create_content_item(entry)
            end
          end
          if options[:page].zero?
            paginate_courses(data['paging']['total'], options)
          end
        end
      rescue StandardError => err
        raise Webhook::Error::IntegrationFailure, "[LinkedinLearningIntegration] Failed Integration for source #{@credentials['source_id']} => Page: #{options[:page]}, ErrorMessage: #{err.message}"
      end
    end
  end

  # Description:
  # 1. When user sets is_delta == 'true' check for last_polled_at and last_updated_at attributes
  #    to find whether to push data or not
  # 2. When user sets is_delta == 'false' push data
  def push_content_item?(last_polled_at, last_updated_at)
    (
      (@credentials['is_delta'].presence || 'true') == 'false' ||
      last_polled_at.nil? ||
      (Time.parse(last_polled_at).to_time.to_i < (last_updated_at /1000))
    )
  end

  def paginate_courses(count, options)
    (1..((count.to_f / options[:limit]).ceil)).each do |page|
      Sidekiq::Client.push(
        'class' => FetchContentJob,
        'queue' => self.class.get_fetch_content_job_queue.to_s,
        'args' => [ self.class.to_s, @credentials, @credentials["source_id"], @credentials["organization_id"], options[:last_polled_at], page]
      )
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

  def deep_link_type
    @credentials['deep_link_type'] || 'webLaunch'
  end
  def content_item_attributes(entry)
    details = entry['details']
    deep_link_url = details['urls'][deep_link_type] || details['urls']['webLaunch'] if details['urls'].present?
    description = sanitize_content(entry['description']['value']) if entry['description']
    {
      external_id:  entry['urn'],
      source_id:    @credentials["source_id"],
      url:          deep_link_url,
      name:         sanitize_content(entry['title']['value']),
      description:  description,
      raw_record:   entry,
      content_type: entry['type'].try(:downcase),
      organization_id: @credentials["organization_id"],

      additional_metadata: {
        level: details["level"]
      },

      resource_metadata: {
        title:       sanitize_content(entry['title']['value']),
        description: description,
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
