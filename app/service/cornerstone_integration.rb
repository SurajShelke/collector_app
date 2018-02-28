require 'hmac-sha2'
require 'curb'

class CornerstoneIntegration < BaseIntegration
  def self.get_source_name
    'cornerstone'
  end

  def self.get_fetch_content_job_queue
    :cornerstone
  end

  def self.get_credentials_from_config(config)
    config['source_config']
  end

  def self.ecl_client_id
    SourceTypeConfig.where(source_type_name: 'cornerstone').first.values['ecl_client_id']
  end

  def self.ecl_token
    SourceTypeConfig.where(source_type_name: 'cornerstone').first.values['ecl_token']
  end

  def base_url
    "https://#{@host_name}.csod.com"
  end

  def session_url
    '/services/api/sts/session'
  end

  def catalogs_url
    '/services/api/Catalog/GlobalSearch'
  end

  def lo_url
    '/services/api/LO/GetDetails'
  end

  def sign_signature(string_to_sign, key)
    key =  Base64.decode64(key)
    hmac = HMAC::SHA512.new(key)
    hmac.update string_to_sign
    Base64.encode64(hmac.digest).tr("\n", '')
  end

  def curl_headers(params)
    params.merge!('x-csod-date' => @current_date, 'Content-Type' => 'application/json', 'accept' => 'application/json')
  end

  def get_content(options = {})
    begin
      @host_name = @credentials['host_name']
      @user_name = @credentials['user_name']
      @api_key = @credentials['api_key']
      @secret_key = @credentials['secret_key']
      @access_token = access_token
      fetch_catalogs
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[CornerstoneIntegration] Failed Integration for source #{@credentials['source_id']} => Page: #{options[:page]}, ErrorMessage: #{err.message}"
    end
  end

  def response_data
    JSON.parse(@response.body_str)
  end

  def access_token
    begin
      @current_date = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.000')
      string_to_sign = "POST\nx-csod-api-key:#{@api_key}\nx-csod-date:#{@current_date}\n#{session_url}"
      signature = sign_signature(string_to_sign, @secret_key)
      headers = curl_headers('x-csod-api-key' => @api_key, 'x-csod-signature' => signature)
      url = "#{base_url}#{session_url}?userName=#{@user_name}&alias=#{@current_date}"
      @response = Curl.post(url) do |cur|
        headers.each { |k, v| cur.headers[k] = v }
      end
      response_data
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[CornerstoneIntegration] Failed to get access token, ErrorMessage: #{err.message}"
    end
  end

  def fetch_catalogs
    @current_date = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.000')
    string_to_sign = "GET\nx-csod-date:#{@current_date}\nx-csod-session-token:#{@access_token['data'].first['Token']}\n#{catalogs_url}"
    signature = sign_signature(string_to_sign, @access_token['data'].first['Secret'])
    headers = curl_headers('x-csod-session-token' => @access_token['data'].first['Token'], 'x-csod-signature' => signature)
    page_number = 1
    loop do
      # url = "#{base_url}#{catalogs_url}"
      url = "#{base_url}#{catalogs_url}?PageNumber=#{page_number}"
      http = Curl::Easy.new(url) do |cur|
        cur.headers = headers
      end
      http.perform
      catalogs = JSON.parse(http.body_str)
      raise Webhook::Error::IntegrationFailure, "[CornerstoneIntegration] Failed to get catalogs, ErrorMessage: #{err.message}" unless catalogs.key?('data')
      break if catalogs['data'].count.zero?
      catalogs['data'].map do |entry|
        puts "#{entry['ObjectId']}----->#{entry['Title']}"
        lo = fetch_lo_details(entry['ObjectId'])
        puts lo
        if lo['status'].to_i == 200 && lo['data'].count > 0
          create_content_item(lo['data'][0]['trainingItem'])
        else
          Rails.logger.error "Lo not found, #{lo['message']}"
        end
      end
      page_number += 1
    end
  end

  def fetch_lo_details(lo_id)
    begin
      @current_date = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.000')
      string_to_sign = "GET\nx-csod-date:#{@current_date}\nx-csod-session-token:#{@access_token['data'].first['Token']}\n#{lo_url}"
      signature = sign_signature(string_to_sign, @access_token['data'].first['Secret'])
      headers = curl_headers('x-csod-session-token' => @access_token['data'].first['Token'], 'x-csod-signature' => signature)
      url = "#{base_url}#{lo_url}?ObjectID=#{lo_id}"
      http = Curl::Easy.new(url) do |cur|
        cur.headers = headers
      end
      http.perform
      JSON.parse(http.body_str)
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[CornerstoneIntegration] Failed to get access token, ErrorMessage: #{err.message}"
    end
  end

  def content_item_attributes(entry)
    {
      external_id:     entry['ObjectId'],
      source_id:       @credentials['source_id'],
      url:             "#{base_url}#{URI.decode_www_form_component(entry['DeepLinkURL'])}",
      name:            sanitize_content(entry['Title']),
      description:     sanitize_content(entry['Descr']),
      raw_record:      entry,
      content_type:    'course',
      organization_id: @credentials['organization_id'],

      additional_metadata: {
        provider:      entry['Provider'],
        Type:          entry['Type']
      },

      resource_metadata: {
        title:         sanitize_content(entry['Title']),
        description:   sanitize_content(entry['Descr']),
        url:           "#{base_url}#{URI.decode_www_form_component(entry['DeepLinkURL'])}"
      }
    }
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
