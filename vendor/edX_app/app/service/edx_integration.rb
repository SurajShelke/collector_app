class EdxIntegration < BaseIntegration
  attr_accessor :client
  def self.get_source_name
    'edx'
  end

  def self.get_fetch_content_job_queue
    :edx
  end

  def self.get_credentials_from_config(source)
    source["source_config"]
  end

  #  @options ={start: start, limit: limit, page: page, last_polled_at: @last_polled_at}
  #  We dont need start or limit for this Integration
  #  Whenever pagination is available we can use it
  def get_content(options={})
    @options = options
    @client  = client
    fetch_content(@credentials['team_drive_id'], @credentials['folder_id'])
  end

  def client
    OAuth2::Client.new(@credentials['client_id'],
                       @credentials['client_secret'],
                       :site => "https://accounts.google.com",
                       :authorize_url => "/o/oauth2/auth",
                       :token_url => "/o/oauth2/token",
                       :additional_parameters => {"access_type" => "offline"})
  end

  def auth_session
    token = get_refresh_token
    if token
      token_hash = JSON.parse(token.to_json)
      access_token = OAuth2::AccessToken.from_hash(@client, token_hash.dup)
    end
  end

  def get_catalogs
    access_token = get_access_token
    puts "-----> access_token: \n#{access_token}"
    conn = Faraday.new('https://api.edx.org')
    response = conn.get do |req|
      req.url '/catalog/v1/catalogs'
      req.headers = { 'Authorization' => "JWT #{access_token}" }
    end
    response = JSON.parse(response.body)
    puts "----------------------------"
    puts response
  end

  # Gets the current access token
  def get_access_token
    params = {
        client_id:  AppConfig.integrations['edx']['client_id'],
        client_secret: AppConfig.integrations['edx']['client_secret'],
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
    puts "----------------------------"
    response["access_token"]
    # OAuth2::AccessToken.new(@client, response["access_token"])
  end
end
