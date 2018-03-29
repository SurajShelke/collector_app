# SourcTypeConfig record creation
#
# SourceTypeConfig.create!(
#   source_type_name: 'edutube',
#   source_type_id: 'a08b4e04-e11e-4286-91c2-5b115e9c8e8a',
#   values: {
#     'ecl_client_id' => 'Ah16kvsMyw',
#     'ecl_token' => 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc19kZXZlbG9wZXIiOnRydWUsImNsaWVudF9pZCI6IkFoMTZrdnNNeXciLCJlbWFpbCI6InlvZ2VuZHJhQGVkY2FzdC5jb20ifQ.Fm838Eh05y6i8zqkJDLLJJx9w05O9SCE3KudVzfQdsU'
#   }
# )

class EdutubeIntegration < BaseIntegration
  include ActionView::Helpers::DateHelper

  def self.get_source_name
    'edutube'
  end

  def self.get_fetch_content_job_queue
    :edutube
  end

  def self.source_type_config_values
    SourceTypeConfig.where(source_type_name: 'edutube').first.values
  end

  def self.ecl_client_id
    source_type_config_values['ecl_client_id']
  end

  def self.ecl_token
    source_type_config_values['ecl_token']
  end

  def get_content(options= {})
    relative_url = get_relative_url

    if relative_url.present?
      begin
        data = call_api(relative_url)
        JSON.parse(data).each{|entry| create_content_item(entry)}
      rescue StandardError => err
        raise Webhook::Error::IntegrationFailure, "[EdutubeIntegration] Failed Integration for source #{@credentials['source_id']}, ErrorMessage: #{err.message}"
      end
    end
  end

  def call_api(relative_url)
    conn = Faraday.new(@credentials['host'])
    response = conn.get do |req|
      req.url relative_url
      req.headers['API_Key'] = @credentials['api_key']
    end
    JSON.parse(response.body)
  end
  
  def content_item_attributes(entry)
    duration_in_seconds = ChronicDuration.parse(entry['duration'])

    {
      external_id:     entry['sharepage'],
      source_id:       @credentials['source_id'],
      url:             entry['sharepage'],
      name:            sanitize_content(entry['videoname']),
      description:     sanitize_content(entry['videodescription']),
      raw_record:      entry,
      content_type:    entry['contenttype']&.downcase,
      organization_id: @credentials['organization_id'],

      duration_metadata: {
        calculated_duration: duration_in_seconds,
        calculated_duration_display: humanize_seconds(duration_in_seconds)
      },

      additional_metadata: {
        author: entry['presenter'],
        language: entry['videolanguage'],
        created_at: entry['createddatetime']
      },

      resource_metadata: {
        title:         sanitize_content(entry['videoname']),
        description:   sanitize_content(entry['videodescription']),
        url:           entry['sharepage'],
        images:        [{ url: entry['thumbnail'] }],
        embed_html:    entry['embedpage']
      }
    }
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end

  def humanize_seconds(seconds)
    distance_of_time_in_words(Time.now, Time.now + (seconds || 0).seconds)
  end

  # TODO: if last_polled_at present then use delta changes api
  def get_relative_url
    '/html5/edutube/bulkfeed' if @credentials['last_polled_at'].blank?
  end
end
