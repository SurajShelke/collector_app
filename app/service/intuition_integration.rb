class IntuitionIntegration < BaseIntegration

  INTUITION_BASE_URL = "https://api.intuition.com"
  DEEP_LAUNCH_BASE_URL = "https://learner.intuition.com"

  def self.get_source_name
    'intuition'
  end

  def self.get_fetch_content_job_queue
    :intuition
  end

  def self.source_type_config_values
    SourceTypeConfig.where(source_type_name: 'intuition').first.values
  end

  def self.ecl_client_id
    source_type_config_values['ecl_client_id']
  end

  def self.ecl_token
    source_type_config_values['ecl_token']
  end

  def catalogue_url
    "#{INTUITION_BASE_URL}/catalogue/Catalogues/my"
  end

  def get_content(options={})
    
    begin
      @access_token = get_access_token
      data = json_request(catalogue_url, :get, headers: { 'Authorization' => "Bearer #{@access_token}", 'Accept' => 'application/json'})
      if data["titles"].present?
        data["titles"].map do |entry|
          create_content_item(entry)
        end
      end
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[IntuitionIntegration] Failed Integration for source #{@credentials['source_id']} => Page: #{options[:page]}, ErrorMessage: #{err.message}"
    end
  end

  def get_access_token
    begin
      auth_param = {  "organisationCode" =>  @credentials['organisationCode'], "userName" => @credentials['userName'],"password" => @credentials['password'] }
      auth_url = "#{INTUITION_BASE_URL}/user/basic-authentication"
      auth_data = json_request(auth_url, :post, params: {}, headers: { content_type:  'application/json' }, basic_auth: {}, bearer:nil, body: auth_param.to_json)
      auth_data["access_token"] if auth_data
    rescue => err
      raise Webhook::Error::IntegrationFailure, "[IntuitionIntegration] Failed to get access token, ErrorMessage: #{err.message}"
    end
  end

  def content_item_attributes(entry)
    details = entry['tags'].first

    deep_link_url = deep_launch_url(entry['id'])

    title_description = catologue_description(entry['id'])
    
    description = sanitize_content(title_description) if title_description
    
    {
      external_id:  entry["id"],
      source_id:    @credentials["source_id"],
      url:          deep_link_url,
      name:         sanitize_content(entry['title']),
      description:  description,
      raw_record:   entry,
      content_type: "course",
      organization_id: @credentials["organization_id"],

      additional_metadata: {
        id: details["id"],
        pos: details["pos"],
        dueDate:         entry['dueDate'],
        contentId:       entry['contentId'],
        assignmentLevel: entry['assignmentLevel']
      },

      resource_metadata: {
        title:           sanitize_content(entry['title']),
        description:     description,
        url:             deep_link_url       
      }
    }
  end
  
  def catologue_description(title_id)
    description_url = "#{INTUITION_BASE_URL}/catalogue/Titles/#{title_id}"
    title_data = json_request(description_url, :get, headers: { 'Authorization' => "Bearer #{@access_token}", 'Accept' => 'application/json'})
    title_data["description"] if title_data
  end
  

  def deep_launch_url(record_id)
    "#{DEEP_LAUNCH_BASE_URL}/#{@credentials["organisationCode"]}/player/stream/#{record_id}?token=#{@access_token}"
  end


  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
