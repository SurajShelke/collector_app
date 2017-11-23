class SharepointCommunicator
  include ContentExtractionService

  GRAPH_RESOURCE = 'https://graph.microsoft.com'.freeze
  GRAPH_AUTH_URL = 'https://login.microsoftonline.com'.freeze

  def initialize(options= {})
    @options                = options
    @client_id              = options[:client_id]
    @client_secret          = options[:client_secret]
    @token                  = options[:token]
    @refresh_token          = options[:refresh_token]
  end

  def get_access_token
    params = {
      client_id: @client_id,
      client_secret: @client_secret,
      refresh_token: @refresh_token,
      grant_type: 'refresh_token',
      additional_parameters: {"access_type" => "offline"}
    }

    conn = Faraday.new(GRAPH_AUTH_URL)
    @response = conn.post do |req|
      req.url '/common/oauth2/v2.0/token'
      req.headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
      req.body = params
    end
    @token = response_data["access_token"]
  end

  def get(relative_url, params = {})
    conn = Faraday.new(GRAPH_RESOURCE)
    @response = conn.get do |req|
      req.url relative_url
      req.headers = headers
      req.params = params
    end
    response_data
  end

  def next_page_files(url, params = {})
    conn = Faraday.new(url)
    conn.headers = headers
    @response = conn.get
    response_data
  end

  #created alias to provide appropriate call while calling method
  alias_method :folders, :get
  alias_method :files, :get
  alias_method :root_site, :get

  def headers
    {
      "content_type" => 'application/json;odata.metadata=minimal;odata.streaming=true',
      "accept" => 'application/json;odata.metadata=minimal;odata.streaming=true',
      "Authorization" => "Bearer #{@token}"
    }
  end

  def response_data
    JSON.parse(@response.body)
  end
end
