class BrightCoveIntegration < BaseIntegration
  BRIGHT_COVE_CMS_BASE_URL = 'https://cms.api.brightcove.com'.freeze
  BRIGHT_COVE_AUTH_BASE_URL = 'https://oauth.brightcove.com'.freeze
  BRIGHT_COVE_PLAYER_BASE_URL = 'https://players.api.brightcove.com'.freeze

  def self.get_source_name
    'bright_cove'
  end

  def self.get_fetch_content_job_queue
    :bright_cove
  end

  def self.get_credentials_from_config(config)
    config['source_config']
  end

  def self.ecl_client_id
    SourceTypeConfig.where(source_type_name: 'bright_cove').first.values['ecl_client_id']
  end

  def self.ecl_token
    SourceTypeConfig.where(source_type_name: 'bright_cove').first.values['ecl_token']
  end

  def self.per_page
    100
  end

  def videos_url
    "#{BRIGHT_COVE_CMS_BASE_URL}/v1/accounts/#{@credentials['account_id']}/videos"
  end

  def video_count_url
    "#{BRIGHT_COVE_CMS_BASE_URL}/v1/accounts/#{@credentials['account_id']}/counts/videos"
  end

  def auth_url
    "#{BRIGHT_COVE_AUTH_BASE_URL}/v4/access_token?grant_type=client_credentials"
  end

  def video_deep_link_url(video_id)
    "#{BRIGHT_COVE_CMS_BASE_URL}/v1/accounts/#{@credentials['account_id']}/videos/#{video_id}/sources"
  end

  def players_url
    "#{BRIGHT_COVE_PLAYER_BASE_URL}/v2/accounts/#{@credentials['account_id']}/players"
  end

  def player
    @credentials['player_url'] ||= default_player
  end

  def default_player
    players = json_request(players_url, :get, headers: { 'Authorization' => "Bearer #{get_access_token}" })
    players['items'].first['url']
  end

  def get_content(options = {})
    begin
      params = { page: options[:page], limit: options[:limit], offset: options[:start] }
      params['q'] = "updated_at:#{options[:last_polled_at]}..now" if @credentials['is_delta'].nil? || @credentials['is_delta'] == 'true'
      videos = json_request(videos_url, :get, headers: { 'Authorization' => "Bearer #{get_access_token}" }, params: params)
      if videos.count > 0
        videos.map { |entry| create_content_item(entry) if Time.parse(options[:last_polled_at]) < Time.parse(entry['updated_at']) }
        if options[:page].zero?
          max_videos = json_request(video_count_url, :get, headers: { 'Authorization' => "Bearer #{get_access_token}" })
          paginate_catalogs(max_videos['count'], options)
        end
      end
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[BrightCoveIntegration] Failed Integration for source #{@credentials['source_id']} => Page: #{options[:page]}, ErrorMessage: #{err.message}"
    end
  end

  def paginate_catalogs(count, options)
    (1...((count.to_f / options[:limit]).ceil)).each do |page|
      Sidekiq::Client.push(
        'class' => FetchContentJob,
        'queue' => self.class.get_fetch_content_job_queue.to_s,
        'args' => [self.class.to_s, @credentials, @credentials['source_id'], @credentials['organization_id'], options[:last_polled_at], page]
      )
    end
  end

  def get_access_token
    begin
      auth_data = json_request(auth_url, :post, headers: { 'Authorization' => "Basic #{Base64.encode64("#{@credentials['client_id']}:#{@credentials['client_secret']}")}".tr("\n", '') })
      auth_data['access_token'] if auth_data
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[BrightCoveIntegration] Failed to get access token, ErrorMessage: #{err.message}"
    end
  end

  def content_item_attributes(entry)
    direct_link = "#{player}?videoId=#{entry['id']}&autoplay=true"
    {
      external_id: entry['id'],
      name: sanitize_content(entry['name']),
      description: sanitize_content(entry['description']),
      summary: sanitize_content(entry['long_description']),
      url: direct_link,
      tags: entry['tags'].present? ? [{ 'source' => 'native', 'tag_type' => 'keyword', 'tag' => entry['tags'] }] : nil,
      source_id: @credentials['source_id'],
      content_type: 'video',
      organization_id: @credentials['organization_id'],
      duration: entry['duration'].to_i,

      resource_metadata: {
        url: direct_link,
        title: sanitize_content(entry['name']),
        description: sanitize_content(entry['description']),
        images: {
          poster: entry['images'].empty? ? nil : entry['images']['poster']['src'],
          thumbnail: entry['images'].empty? ? nil : entry['images']['thumbnail']['src']
        }
      },

      additional_metadata: {
        created_at: entry['created_at'],
        published_at: entry['published_at'],
        updated_at: entry['updated_at'],
        state: entry['state'],
        complete: entry['complete']
      }
    }
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end