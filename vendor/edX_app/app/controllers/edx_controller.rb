class EdxController < ApplicationController

  skip_before_action :verify_authenticity_token

  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

  def catalogs
    conn = Faraday.new('https://api.edx.org')
    response = conn.get do |req|
      req.url '/catalog/v1/catalogs'
      req.headers = { 'Authorization' => "JWT #{get_access_token}" }
    end
    @response = JSON.parse(response.body)
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
    response["access_token"] if response
  end

end
