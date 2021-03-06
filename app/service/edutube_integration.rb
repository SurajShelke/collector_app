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

  DAILY_FEED_URL = '/html5/edutube/dailyfeed'.freeze
  
  BULK_FEED_URL =  '/html5/edutube/bulkfeed'.freeze

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

  def get_content(options = {})
    begin
      relative_url = get_relative_url(options[:last_polled_at])
      headers = {
        'Content-Type' => 'application/json',
        'API_Key' => @credentials['api_key']
      }
      data = json_request(
        "#{@credentials['host']}#{relative_url}",
        :get,
        headers: headers,
        basic_auth:{ key: @credentials['client_id'], secret: @credentials['client_secret']}
      )
      JSON.parse(data).each{|entry| create_content_item(entry)}

      reset_is_delta
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[EdutubeIntegration] Failed Integration for source #{@credentials['source_id']}, ErrorMessage: #{err.message}"
    end
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
      content_type:    entry['contenttype'].try(:downcase),
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
        embed_html:    generate_embed_html(entry['shareplayer'])
      }
    }
  end
  
  def generate_embed_html(share_player_link)
    "<iframe height='380' width='640' src='#{share_player_link}' allowfullscreen></iframe>"    
  end
  
  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end

  def humanize_seconds(seconds)
    distance_of_time_in_words(Time.now, Time.now + (seconds || 0).seconds)
  end

  # TODO: if last_polled_at present then use delta changes api
  def get_relative_url(last_polled_at)
    if @credentials['is_delta'] == 'false'
      BULK_FEED_URL
    else
      last_polled_at = Time.now.strftime('%Y-%m-%dT%H:%M:%S.%LZ') unless last_polled_at 
      "#{DAILY_FEED_URL}?startdate=#{last_polled_at}"
    end
  end
end
