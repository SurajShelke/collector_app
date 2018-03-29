class GetAbstractIntegration < BaseIntegration
  attr_accessor :token

  BASE_URL = 'https://www.getabstract.com'
  TOKEN_URL = '/api/oauth/token'
  LIST_URL = '/api/library/v1/abstract/list'

  def get_content(options={})
    # Generate and set token only if not already present
    generate_and_set_token if self.token.nil?

    # Set up parameters
    params = {
        limit: get_option(options, :limit, 100),
        start: get_option(options, :start, 0)
    }

    data = json_request(url(BASE_URL, LIST_URL), :get, params:params, bearer:self.token
    data['abstracts'].map{|x| create_content_item(x)}
  end

  def self.get_source_name
    'get_abstract'
  end

  def self.get_fetch_content_job_queue
    :get_abstract
  end

  def self.get_credentials_from_config(config)
    {
      client_id: config['source_config']['client_id'],
      client_secret: config['source_config']['client_secret']
    }
  end

  def pagination?
    true
  end

  private

  def content_item_attributes(entry)
    attributes = {
        name: sanitize_content(entry['bookinfo']['title']),
        description: sanitize_content(entry['recommendation']),
        author: entry['aboutauthor'],
        url: (entry['summaryURL'] || entry['publicURL']),
        tags: get_tags(entry),
        content_type: 'article',
        external_id: entry['dataId'],
        raw_record: entry
    }

    resource_metadata = get_url_meta_data(entry['publicURL'])
    if resource_metadata.present?
      resource_metadata[:url] = (entry['summaryURL'] || entry['publicURL'])
      attributes.merge!(resource_metadata: resource_metadata)
    end

    attributes
  end

  def get_tags(entry)
    list = [entry['primaryCategory']['description']]
    list = list.push(entry['subCategories'].map{|x|x['description']}).flatten.compact.uniq

    tags = []
    list.each do |tag|
      tags.push({'source' => 'native', 'tag_type' => 'keyword', 'tag' => tag})
    end

    tags
  end

  def get_image(entry)
    bookinfo = entry['bookinfo']
    [bookinfo['bookcoverOriginal'], bookinfo['bookcover'], bookinfo['bookcoverMedium']]
  end

  def generate_and_set_token
    basic_auth = {
        key: @credentials["client_id"],
        secret: @credentials["client_secret"]
    }

    params = {
        grant_type: 'client_credentials'
    }

    data = json_request(url(BASE_URL, TOKEN_URL), :post, params:params, basic_auth:basic_auth)
    self.token = data['access_token']
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
