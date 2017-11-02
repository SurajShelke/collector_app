class SharepointCommunicator
	
	def initialize(options= {})
    @options         				= options
    @client_id   						= options[:client_id]
    @client_secret   				= options[:client_secret]
    @site_realm 						= options[:site_realm]
    @token 									= options[:token]
		@audience_principal_id	= options[:audience_principal_id]
		@sharepoint_url 				= options[:sharepoint_url]
		@redirect_uri						= options[:redirect_uri]
  end
	
	def get_access_token(auth_code)
  	@token = get_token("authorization_code", "code=#{auth_code}")
  end

  def get_refresh_token
  	@token = get_token("refresh_token", "refresh_token=#{@token['refresh_token']}")
  end

	def get_token(grant_type, token_param)
		# Remove RestClient and identify way to use Faraday TODO
		relative_url = "#{@site_realm}/tokens/OAuth/2"
    params = "grant_type=#{grant_type}&client_id=#{@client_id}@#{@site_realm}&client_secret=#{@client_secret}&redirect_uri=#{redirect_uri}&resource=#{@audience_principal_id}/#{@sharepoint_url}@#{@site_realm}&#{token_param}"
    @response = RestClient.post "https://accounts.accesscontrol.windows.net/#{@site_realm}/tokens/OAuth/2", params, {content_type: "application/x-www-form-urlencoded"}
    response_data
  end
  
  def get_loged_in_user(relative_url, params = {})
  	conn = Faraday.new(base_url)

    # fetch user account details
    @response = conn.get do |req|
      req.url relative_url
      req.headers = headers
      req.params = {}
    end
    response_data
  end

  def get_folders(relative_url, params = {})
    conn = Faraday.new(base_url)
    @response = conn.get do |req|
      req.url relative_url
      req.headers = headers
      req.params = params
    end
    response_data
  end

  def get_files(relative_url, params = {})
    conn = Faraday.new(base_url)
    @response = conn.get do |req|
      req.url relative_url
      req.headers = headers
      req.params = params
    end
    response_data
  end
  
  def fetch_content(folder_relative_url)
    response = get_sharepoint_files(folder_relative_url)
    collect_files(response)
  end

  def get_public_url(relative_url, params = {})
    conn = Faraday.new(base_url)
    @response = conn.get do |req|
      req.url relative_url
      req.headers = headers
      req.params = params
    end
    response_data["value"]
  end

  def base_url
    "https://#{@sharepoint_url}"
  end
  
  def redirect_uri
    URI.encode(AppConfig.integrations['sharepoint']['redirect_uri'])
  end

  def headers
    {
      "content_type" => "application/json",
      "accept" => "application/json",
      "Authorization" => "Bearer #{@token['access_token']}"
    }
  end
  
  def response_data
    JSON.parse(@response.body)
  end
end