class NuveproIntegration < BaseIntegration

  def self.get_source_name
    'nuvepro'
  end

  def self.get_fetch_content_job_queue
    :nuvepro
  end

  def self.get_credentials_from_config(config)
    source["source_config"]
  end

  def self.ecl_client_id
    AppConfig.integrations['nuvepro']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['nuvepro']['ecl_token']
  end

  def get_all_plans_url
    "/v1/plans/getPlans"
  end

  def authenticate_url
    "/v1/users/login"
  end

  def headers
    @headers ||= {
      'Content-Type' => 'application/x-www-form-urlencoded', 
      'X-CSRF-Token' => access_token["token"],
      "Cookie" => "#{access_token['session_name']}=#{access_token['sessid']}"
    }
  end

  def get_content(options={})
    begin
      plans = post_execution(get_all_plans_url, req_headers: headers)
      plans.each{|entry| create_content_item(entry)}
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[NuveproIntegration] Failed Integration for source #{@credentials['source_id']} => Page: #{options[:page]}, ErrorMessage: #{err.message}"
    end
  end

  def post_execution(relative_url, req_headers: {}, body: nil)
    conn = Faraday.new(@credentials["host"])
    response = conn.post do |req|
      req.url relative_url
      req.headers["Content-Type"] = 'application/x-www-form-urlencoded'

      req_headers.each do |k, v|
        req.headers[k] = v
      end

      req.body = body if body
    end
    JSON.parse(response.body)
  end
  
  def access_token
    begin
      @access_token ||= post_execution(authenticate_url, body: { username: @credentials["username"], password: @credentials["password"] } )
    rescue => err
      raise Webhook::Error::IntegrationFailure, "[NuveproIntegration] Failed to get access token, ErrorMessage: #{err.message}"
    end
  end

  def content_item_attributes(entry)
    {
      external_id:     entry['planId'],
      source_id:       @credentials["source_id"],
      url:             entry['pageUrl'],
      name:            sanitize_content(entry['planDisplayName']),
      description:     sanitize_content(entry['fullDescription']),
      raw_record:      entry,
      content_type:    'course',
      organization_id: @credentials["organization_id"],
      tags:            entry['tags'].present? ? [{ 'source' => 'native', 'tag_type' => 'keyword', 'tag' => entry['tags'] }] : nil,

      additional_metadata: {
        provisionData: entry['provisionData'],
        duration:      entry['duration']
      },

      resource_metadata: {
        title:         sanitize_content(entry['planDisplayName']),
        description:   sanitize_content(entry['fullDescription']),
        url:           entry['pageUrl'],
        images:        [{ url: entry['image'] }]
      }
    }
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
