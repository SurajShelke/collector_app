require 'net/sftp'
require 'csv'

OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0

class SftpIntegration < BaseIntegration

  REQUIRED_KEYS = [:id, :title, :description, :deeplink_url, :keywords, :image_url]

  def self.get_source_name
    'sftp'
  end

  def self.get_fetch_content_job_queue
    :sftp
  end

  def self.get_credentials_from_config(config)
    source["source_config"]
  end

  def self.ecl_client_id
    AppConfig.integrations['sftp']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['sftp']['ecl_token']
  end

  def self.per_page
    20
  end

  def get_content(options={})
    data = SftpCsvParser.new(server_ip:                 @credentials['server_ip'],
                             server_encrypted_password: @credentials['server_encrypted_password'],
                             server_username:           @credentials['server_username'],
                             server_folder_path:        @credentials['server_folder_path'],
                             delimiter: ',').fetch_courses
    data.each{|row| create_content_item(row)} if data
  end

  def content_item_attributes(entry)

    entry[:keywords].gsub!("\"", "") if entry[:keywords].present?

    {
      name:         sanitize_content(entry[:title]),
      description:  sanitize_content(entry[:description]),
      url:          entry[:deeplink_url],
      content_type: entry[:content_type].try(:downcase).presence || 'course',
      external_id:  entry[:id].present? ? entry[:id] : entry[:deeplink_url],
      raw_record:   entry,
      tags:         get_tags(entry[:keywords]),
      source_id:       @credentials["source_id"],

      resource_metadata:  {
        title:         sanitize_content(entry[:title]),
        description:   sanitize_content(entry[:description]),
        url:           entry[:deeplink_url],
        images:        course_image(entry[:image_url])
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

  def sanitize_content(content)
    re = /<("[^"]*"|'[^']*'|[^'">])*>/

    # Check iso-8859-1 encoding for unrecognised characters
    content.gsub(re, '').encode("iso-8859-1", invalid: :replace, undef: :replace, replace: '').force_encoding('utf-8') if content.present?
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
