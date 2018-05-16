class FileIntegration < BaseIntegration

  REQUIRED_KEYS = [:id, :title, :description, :deeplink_url]

  def self.get_source_name
    'file'
  end

  def self.get_fetch_content_job_queue
    :file
  end

  def self.source_type_config_values
    SourceTypeConfig.where(source_type_name: 'file').first.values
  end

  def self.ecl_client_id
    source_type_config_values['ecl_client_id']
  end

  def self.ecl_token
    source_type_config_values['ecl_token']
  end

  def get_content(options={})
    data = FileParser.new(
            url: @credentials['url'], 
            root_element: @credentials['root_element'], 
            file_type: @credentials['file_type']
          ).parse_content
    data.each{|row| create_content_item(row)} if data
  end

  def content_item_attributes(entry)
    # entry[:keywords].gsub!("\"", "") if entry[:keywords].present?

    {
      name:         sanitize_content(entry['title']),
      description:  sanitize_content(entry['description']),
      url:          entry['deeplink_url'],
      content_type: entry['content_type'].try(:downcase).presence || 'course',
      external_id:  entry['id'].present? ? entry['id'] : entry['deeplink_url'],
      raw_record:   entry,
      # tags:         get_tags(entry[:keywords]),
      source_id:    @credentials["source_id"],

      resource_metadata:  {
        title:         sanitize_content(entry['title']),
        description:   sanitize_content(entry['description']),
        url:           entry['deeplink_url'],
        images:        course_image(entry['image_url'])
      },

      additional_metadata: get_additional_metadata(entry)
    }
  end

  def get_additional_metadata(entry)
    keys = entry.keys - REQUIRED_KEYS
    metadata = {}

    keys.each do |key|
      metadata[key] = entry[key]
    end
    metadata = metadata.reject{|k,v| v.blank?}
    metadata.presence
  end

  def course_image(image_url)
    if image_url.present?
      urls = image_url.split(',')
      urls.collect{ |url| { url: image_url.squish } }
    end
  end

  def get_tags(tags)
    if tags.present?
      tags = tags.split(',')
      tags.collect do |tag|
        { source: 'native', tag_type: 'keyword', tag: tag.squish }
      end
    end
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end