require 'net/sftp'
require 'csv'
require 'open-uri'

OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0

class SftpConnection < BaseIntegration

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
    obj = CsvParser.new(  server_ip:                  options[:server_ip],
                          server_encrypted_password:  options[:server_encrypted_password],
                          server_username:            options[:server_username],
                          server_folder_path:         options[:server_folder_path],
                          delimiter: ',')
    data = obj.fetch_progresses
    data.each { |row| post_statement(row) } if data
  end

  def form_statement_query(progress)
    {
      "actor": {
        "name": progress[:user_username],
        "mbox": "mailto:#{progress[:user_email]}"
      },
      "verb": {
        "id": "http://activitystrea.ms/schema/1.0/start",
        "display": {
            "en-US": "started"
        }
      },
      "context": {
        "registration": SecureRandom.uuid,
        "contextActivities":{
          "category":[
            {
              "id":"http://adlnet.gov/expapi/activities/assessment",
              "definition": {
                "name": {
                    "en": "Course"
                },
                "description": {
                    "en": "A category of course with Assesment."
                }
              }
            },
            { "id":"http://adlnet.gov/expapi/activities/objective"  },
            { "id":"http://activitystrea.ms/schema/1.0/audio" },
            { "id":"http://activitystrea.ms/schema/1.0/video" }
          ]
        }
        # "instructor": {
        #   "name": progress[''] #,
        #   "account": {
        #       "homePage": progress[''],
        #       "name": progress['']
        #   }
        # }
      },
      "object": {
        "id": "https://courses.edx.org/enterprise/#{progress[:enterprise_id]}/course/#{progress[:course_id]}/enroll/?utm_medium=enterprise&utm_source=edcast-sparks" ,#{}"https://courses.edx.org/courses/#{progress[:course_id]}/course",
        "definition": {
          "name": {
              "en-US": "completed"
          },
          "description": {
              "en-US": "completed"
          },
          "type": "http://adlnet.gov/expapi/activities/course"
        },
        "objectType": "Activity"
      } #,
      # "result":{
      #     "score":{
      #       "scaled": course_grade["status"]
      #     },
      #   "success":true,
      #   "completion":true,
      #   "duration": "PT1234S"
      # }
    }
  end

  def lxp_secret
    # "ZWYyOGZiZWJjZjQ5MmVhN2RiMDZiMWRlMGRiNGRkYzkyNzRmMGJmNjpkZTAwZjAwMDY2ZDBlOWE4MjU0MmExMjMxMzdmOTE4M2UzMGIwN2Zk"
    AppConfig.integrations['edx']['lxp_secret']
  end

  def post_statement(progress)
    conn = Faraday.new('http://lrs.edcast.com') do |b|
      b.use FaradayMiddleware::EncodeJson
      b.adapter Faraday.default_adapter
    end
    
    headers = { 'Authorization' => "Basic #{lxp_secret}",
                'X-Experience-API-Version' => '1.0.3',
                'Content-Type' => 'application/json',
                'charset' => 'utf-8'
              }
    # byebug
    params = form_statement_query(progress)
    puts "\n------------- params:statement -----------------"
    puts params
    Rails.logger.debug "\n------------- params:statement -----------------"
    Rails.logger.debug params
    response = conn.post do |req|
      req.url '/data/xAPI/statements'
      req.headers.update(headers)
      req.body = params
    end
    puts JSON.parse(response.body)
    Rails.logger.debug "\nStatement reponse:"
    Rails.logger.debug JSON.parse(response.body)
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
    content.gsub(re, '').encode("iso-8859-1", invalid: :replace, undef: :replace).force_encoding('utf-8') if content.present?
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end

  def get_verb(course_status)
      if course_status == "in_progress"
        "http://activitystrea.ms/schema/1.0/start"
      elsif course_status == "achievements"
        "http://adlnet.gov/expapi/verbs/completed"
      else
        "http://activitystrea.ms/schema/1.0/assign"
      end
    end
end
