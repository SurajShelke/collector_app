class BaseIntegration
  include ActionView::Helpers::SanitizeHelper

  def initialize(credentials)
    @credentials = credentials
  end

  def get_content(options={})
    raise NotImplementedError
  end

  def self.get_source_name
    raise NotImplementedError
  end

  def self.get_fetch_content_job_queue
    raise NotImplementedError
  end

  def self.get_credentials_from_config(config)
    raise NotImplementedError
  end

  def self.ecl_client_id
    raise NotImplementedError
  end

  def self.ecl_token
    raise NotImplementedError
  end

  def self.per_page
    100
  end

  def self.persistence_enabled?
    false
  end

  def self.schedule_at
    Time.now.to_f
  end

  def url(*args)
    args.join('')
  end

  def sanitize_content(content)
    strip_tags content
  end

  def json_request(url, method, params:{}, headers:{}, basic_auth:{}, bearer:nil, body: nil)
    # Initialize connection
    connection = Faraday.new(url: url) do |f|
      f.response :logger
      f.adapter Faraday.default_adapter
    end

    # Check for basic auth
    if !basic_auth.empty?
      connection.basic_auth(basic_auth[:key], basic_auth[:secret])
    end

    # Make request
    response = connection.send(method) do |request|
      request.headers['Accept'] = headers['Accept'] || 'application/json'
      request.headers['Content-Type'] = headers['Content-Type'] || 'application/json'

      # check for bearer token
      request.headers['Authorization'] = "Bearer #{bearer}" if bearer.present?

      params.each do |k, v|
        request.params[k] = v
      end

      headers.each do |k, v|
        request.headers[k] = v
      end

      request.body = body if body.present?
    end

    # If no content, then raise a no content exception
    if response.status == 204
      raise Webhook::NoContentException
    end
    # Return json body
    ActiveSupport::JSON.decode(response.body)
  end

  def get_option(options, name, default)
    if options[name].present?
      options[name]
    else
      default
    end
  end

  def get_cached_content(options={})
    limit = get_option(options, :limit, 100)
    start = get_option(options, :start, 0)

    content_items = ContentItem.where(source_name: self.class.get_source_name).limit(limit).offset(start)

    content_items.map { |x| yield x.content }
  end

  def get_url_meta_data(url)
    url_meta_data = UrlMetaDataService.new(url)
    url_meta_data.run
    url_meta_data.resource_meta_data
  end

  def pagination?
    false
  end

  def cached_content_pagination?
    true
  end

  def reset_is_delta
    ecl_service = EclDeveloperClient::Source.new(self.class.ecl_client_id, self.class.ecl_token)

    if @credentials['is_delta'].present? && @credentials['is_delta'] == 'false'
      @credentials['is_delta'] = 'true'
    end

    ecl_service.update(@credentials["source_id"], {
      source_config: @credentials.except("source_id", "organization_id", "last_polled_at"),
      last_polled_at: Time.now
    })
  end
end
