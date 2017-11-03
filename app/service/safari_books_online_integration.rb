class SafariBooksOnlineIntegration < BaseIntegration

  SAFARI_BOOKS_ONLINE_URL = 'https://www.safaribooksonline.com/api/v2/search/'

  def self.get_source_name
    'safari_books_online'
  end

  def self.get_fetch_content_job_queue
    :safari_books_online
  end

  def self.get_credentials_from_config(config)
    source["source_config"]
  end

  def self.ecl_client_id
    AppConfig.integrations['safari_books_online']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['safari_books_online']['ecl_token']
  end

  def get_content(options={})
    begin
      current_page = options[:page].to_i + 1
      data = json_request(SAFARI_BOOKS_ONLINE_URL, :get,params: {page: current_page})
      if data["results"].present?
        data["results"].map {|entry| create_content_item(entry)}
        if current_page == 1
          (1..(data['total']/10)).each do |page|
            Sidekiq::Client.push(
              'class' => FetchContentJob,
              'queue' => self.class.get_fetch_content_job_queue.to_s,
              'args' => [self.class.to_s, @credentials, @credentials["source_id"],@credentials["organization_id"], options[:last_polled_at], page],
              'at' => (Time.now + rand(0..120)).to_f
            )
          end
        end
      end
    rescue=>e
    end
  end

  def get_url(url)
    "https://safarijv.auth0.com/authorize?client_id=#{@credentials['client_id']}&response_type=code&redirect_uri=https://www.safaribooksonline.com/complete/auth0-oauth2/&connection=#{@credentials['domain']}&state=#{url}"
  end

  def content_item_attributes(entry)
    {
      external_id:  entry['id'], # This is the unique ID (as far as the search API is concerned) of the result.
      source_id:  @credentials["source_id"],
      url:          get_url(entry['web_url']),
      name:         sanitize_content(entry['title']),
      description:  sanitize_content(entry['description']),
      content_type: entry['content_type'],
      raw_record:   entry,

      additional_metadata: {
        duration_seconds: entry['duration_seconds'],
        language:         entry['language'],
        has_assessment:   entry['has_assessment'],
        publishers:       entry['publishers']
      },

      resource_metadata: {
        title:       sanitize_content(entry['title']),
        description: sanitize_content(entry['description']),
        url:         entry['web_url'],
        images:      [{ url: entry['cover_url'] }]
      }
    }
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
