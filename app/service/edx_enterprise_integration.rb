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
    "/enterprise/v1/enterprise-catalogs"
  end

  def get_content(options={})
    begin
      catalogs = paginated_data(catalog_url)
      catalogs.each do |catalog|
        courses = paginated_data("#{catalog_url}/#{catalog['uuid']}")
        next if courses.empty? || courses.first['content_type'] != 'course'
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

  def paginated_data(relative_url)
    results = []
    url = "#{EDX_ENTERPRISE_BASE_URL}#{relative_url}"
    loop do
      puts url
      response = json_request(url, :get, headers: { 'Authorization' => "JWT #{get_access_token}" })
      results.push(*response['results'])
      break if response['next'].nil? || response['next'].empty? || response['results'].first['content_type'] != 'course'
      url = response['next']
    end
    results
  end

  def get_access_token
    params = {
        client_id:  AppConfig.integrations['edx_enterprise']['client_id'],
        client_secret: AppConfig.integrations['edx_enterprise']['client_secret'],
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
    puts entry
    {
      external_id:  entry['key'],
      source_id:    @credentials["source_id"],
      url:          entry['enrollment_url'],
      name:         entry['title'],
      description:  sanitize_content(entry['full_description']),
      raw_record:   entry,
      content_type: 'course',
      organization_id: @credentials["organization_id"],

      resource_metadata: {
        title:       entry['title'],
        description: sanitize_content(entry['full_description']),
        url:         entry['enrollment_url']
      }
    }
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
