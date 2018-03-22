require 'rest_client'
class SuccessFactorIntegration < BaseIntegration
  def self.get_source_name
    'success_factor'
  end

  def self.get_fetch_content_job_queue
    :success_factor
  end

  def self.get_credentials_from_config(config)
    config['source_config']
  end

  def self.ecl_client_id
    SourceTypeConfig.where(source_type_name: 'success_factor').first.values['ecl_client_id']
  end

  def self.ecl_token
    SourceTypeConfig.where(source_type_name: 'success_factor').first.values['ecl_token']
  end

  def token_url
    "#{@host_url}/learning/oauth-api/rest/v1/token"
  end

  def courses_url
    "#{@host_url}/learning/odatav4/public/admin/searchItem/v1/Items?$filter=criteria/itemTypeIDs%20eq%20'CRSE'%20and%20criteria/active%20eq%20true&$count=true"
  end

  def get_content(options = {})
    begin
      @host_url = @credentials['host_url']
      @user_id = @credentials['user_id']
      @company_id = @credentials['company_id']
      @client_id = @credentials['client_id']
      @client_secret = @credentials['client_secret']
      catalogs = fetch_catalogs(options)
      catalogs.map { |entry| create_content_item(entry) }
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[successFactorIntegration] Failed Integration for source #{@credentials['source_id']} => Page: #{options[:page]}, ErrorMessage: #{err.message}"
    end
  end

  def access_token(user_type)
    begin
      auth_secret = Base64.encode64("#{@client_id}:#{@client_secret}").gsub("\n", '')

      body_params = {
        grant_type: 'client_credentials',
        scope: {
          userId: user_id,
          companyId: @company_id,
          userType: user_type,
          resourceType: 'learning_public_api'
        }
      }

      token = json_request(token_url, :post, headers: { 'Authorization' => "Basic #{auth_secret}" }, body: body_params.to_json)
      @access_token = token['access_token']
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[SuccessFactorIntegration] Failed to get access token, ErrorMessage: #{err.message}"
    end
  end

  def fetch_catalogs(options)
    page = options[:page]
    per_page = options[:limit]
    skip = page * per_page

    token = access_token('admin')
    response = RestClient.get("#{courses_url}&$top=#{per_page}&$skip=#{skip}", { 'Authorization' => "Bearer #{token}" })
    response = JSON.parse(response.body)
    if options[:page].zero? && !response['value'].empty?
      count = response['value'].first['totalCount']
      paginate_catalogs(count, options)
    end
    response['value']
  end

  def paginate_catalogs(count, options)
    (1..((count.to_f / options[:limit]).ceil)).each do |page|
      Sidekiq::Client.push(
        'class' => FetchContentJob,
        'queue' => self.class.get_fetch_content_job_queue.to_s,
        'args' => [self.class.to_s, @credentials, @credentials['source_id'], @credentials['organization_id'], options[:last_polled_at], page]
      )
    end
  end

  def content_item_attributes(entry)
    query = "destUrl=#{CGI.escape("#{@host_url}/learning/user/deeplink_redirect.jsp?linkId=ITEM_DETAILS&componentID=#{entry['itemID']}&componentTypeID=CRSE&revisionDate=#{entry['revisionDate']}&fromSF=Y")}&company=#{@credentials['company_name']}"
    deep_link = "https://hcm4preview.sapsf.com/sf/learning?#{query.gsub('.', '%2e')}"
    {
      external_id:     entry['itemID'],
      source_id:       @credentials['source_id'],
      url:             deep_link,
      name:            sanitize_content(entry['itemTitle']),
      raw_record:      entry,
      content_type:    'course',
      organization_id: @credentials['organization_id'],

      additional_metadata: {
        provider:      entry['Provider'],
        type:          entry['itemTypeID'],
        classification_id: entry['classificationID']
      },

      resource_metadata: {
        title:         sanitize_content(entry['itemTitle']),
        description:   sanitize_content(entry['Descr']),
        url:           deep_link
      }
    }
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
