class SafariBooksOnlineV2Integration < BaseIntegration

  def self.get_source_name
    'safari_books_online_v2'
  end

  def self.get_fetch_content_job_queue
    :safari_books_online_v2
  end

  def self.get_credentials_from_config(config)
    config["source_config"]
  end

  def self.ecl_client_id
    SourceTypeConfig.where(source_type_name: 'safari_books_online_v2').first.values['ecl_client_id']
  end

  def self.ecl_token
    SourceTypeConfig.where(source_type_name: 'safari_books_online_v2').first.values['ecl_token']
  end

  def base_url
    "https://www.#{@credentials['host_name']}.com"
  end
  
  def search_url
    "#{base_url}/api/v2/search/"
    #{}"#{base_url}/api/v2/search/"
  end

  def get_content(options={})
    begin
      data = json_request(search_url, :get,params: {page: options[:page], limit: 200})
      if data["results"].present?
        data["results"].map {|entry| create_content_item(entry)}
        if options[:page] == 0
          (1..(data['total']/200)).each do |page|  # 500 results per page
            Sidekiq::Client.push(
              'class' => FetchContentJob,
              'queue' => self.class.get_fetch_content_job_queue.to_s,
              'args' => [self.class.to_s, @credentials, @credentials["source_id"],@credentials["organization_id"], options[:last_polled_at], page],
              # 'at' => (Time.now + rand(0..120)).to_f,
              'rate' => {
                :name   => 'safari_books_online_v2_50_rpm_rate_limit',
                :limit  => 50,
                :period => 60, ## A minute
              }
            )
          end
        end
      end
    rescue=>e
      
    end
  end

  def content_item_attributes(entry)
    {
      external_id:  entry['id'], # This is the unique ID (as far as the search API is concerned) of the result.
      source_id:    @credentials["source_id"],
      url:          entry['web_url'],
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
