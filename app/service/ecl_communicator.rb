class EclCommunicator
  attr_accessor :response_data,:token,:payload

  def initialize(payload={})
    @payload = payload
  end

  def headers
    {
      "X-Api-Token" => get_token,
      "X-Api-Client" => get_client
    }
  end

  def get_token
    AppConfig.ecl_app_token
  end

  def base_url
    AppConfig.ecl_app_url
  end

  def get_client
    AppConfig.ecl_app_client
  end

  def establish_connection(relative_url, params={})
    conn = Faraday.new(base_url)
    @response = conn.get do |req|
      req.url relative_url
      req.headers = headers
      req.params = params
    end
  end

  def establish_post_connection(relative_url, params={})
    conn = Faraday.new(base_url)

    @response = conn.post do |req|
      req.url relative_url
      req.headers = headers
      req.body = params
    end
  end

  def establish_put_connection(relative_url, params={})
    conn = Faraday.new(base_url)

    @response = conn.put do |req|
      req.url relative_url
      req.headers = headers
      req.body = params
    end
  end

  def establish_delete_connection(relative_url, params={})
    conn = Faraday.new(base_url)

    @response = conn.delete do |req|
      req.url relative_url
      req.headers = headers
      req.body = params
    end
  end

  def response_data
    JSON.parse(@response.body)
  end

  def error
    (response_data["error"] || response_data["message"]).try(:humanize)
  end
end
