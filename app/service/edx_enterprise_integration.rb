class EdxEnterpriseIntegration < BaseIntegration

  EDX_ENTERPRISE_BASE_URL = "https://api.edx.org"

  def self.get_source_name
    'edx_enterprise'
  end

  def self.get_fetch_content_job_queue
    :edx_enterprise
  end

  def self.get_credentials_from_config
    source["source_config"]
  end

  def self.ecl_client_id
    AppConfig.integrations['edx_enterprise']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['edx_enterprise']['ecl_token']
  end

  def catalog_url
    "/enterprise/v1/catalogs/"
  end

  def course_url(catalog_id)
    "/enterprise/v1/catalogs/#{catalog_id}/courses"
  end

  def get_content(options={})
    begin
      catalogs = get_catalogs
      catalogs.each do |catalog|
        courses = get_courses(catalog["id"])
        courses.each do |course|
          begin
            create_content_item(course)
          rescue Exception => err
            Rails.logger.debug "Exception: #{err.message} while parsing edX course: #{course['uuid']}"
          end
        end
      end
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[EdxEnterpriseIntegration] Failed Integration for source #{@credentials['source_id']} => ErrorMessage: #{err.message}"
    end
  end

  def get_catalogs
    conn = Faraday.new(EDX_ENTERPRISE_BASE_URL)
    response = conn.get do |req|
      req.url catalog_url
      req.headers = { 'Authorization' => "JWT #{get_access_token}" }
    end
    JSON.parse(response.body).try(:[], "results") || []
  end

  def get_courses(catalog_id)
    conn = Faraday.new(EDX_ENTERPRISE_BASE_URL)
    response = conn.get do |req|
      req.url course_url(catalog_id)
      req.headers = { 'Authorization' => "JWT #{get_access_token}" }
    end
    JSON.parse(response.body).try(:[], "results") || []
  end

  def get_access_token
    params = {
        client_id: @credentials['client_id'],
        client_secret: @credentials['client_secret'],
        grant_type: "client_credentials",
        token_type: "jwt"
      }
    conn = Faraday.new('https://api.edx.org')
    response = conn.post do |req|
      req.url '/oauth2/v1/access_token'
      req.headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
      req.body = params
    end
    response = JSON.parse(response.body)
    response["access_token"] if response
  end

  def content_item_attributes(entry)
    enrollment_url = entry["course_runs"].first["enrollment_url"] rescue ''
    {
      external_id:  entry['uuid'],
      source_id:    @credentials["source_id"],
      url:          enrollment_url,
      name:         entry['title'],
      description:  sanitize_content(entry['full_description']),
      raw_record:   entry,
      content_type: 'course',
      organization_id: @credentials["organization_id"],

      additional_metadata: {
      },

      resource_metadata: {
        title:       entry['title'],
        description: sanitize_content(entry['full_description']),
        url:         entry['enrollment_url'],
        marketing_url: entry['marketing_url'],
        images:      [{ url: entry['image']['src'] }],
        video_url:   (entry['video']['src'] rescue ''),
        level:       entry['level_type']
      }
    }
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
