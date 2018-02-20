class LyndaIntegration < BaseIntegration

  BASE_URL = 'http://api-1.lynda.com'
  COURSES_URL = '/courses'

  def get_content(options={})
    courses = fetch_content(options)
    courses.map{|x| create_content_item(x)}
  end

  def self.get_source_name
    'lynda'
  end

  def self.get_fetch_content_job_queue
    :lynda
  end

  def self.get_credentials_from_config(config)
    {
      api_key: config['source_config']['api_key'],
      secret_key: config['source_config']['secret_key'],
      domain: config['source_config']['domain']
    }
  end

  def pagination?
    true
  end

  private

  def fetch_content(options)
    begin
      api_key = @credentials["api_key"]
      secret_key = @credentials["secret_key"]

      # Set up parameters
      params = {
        :limit => get_option(options, :limit, 20),
        :start => get_option(options, :start, 0),
        'filter.includes' => filter_includes,
        'filter.values' => filter_values,
      }

      # Setup request
      uri = URI(url(BASE_URL, COURSES_URL))
      uri.query = URI.encode_www_form(params)
      timestamp = Time.now.utc.to_i.to_s
      hash_key = api_key + secret_key + uri.to_s + timestamp
      hash = Digest::MD5.hexdigest(hash_key)

      request = Net::HTTP::Get.new(uri)
      request.add_field('appkey',api_key)
      request.add_field('timestamp',timestamp)
      request.add_field('hash',hash)

      # Process response
      response = Net::HTTP.start(uri.hostname, uri.port) { |http|
        http.request(request)
      }

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        raise Collector::Error::InvalidContent, "Integration: #{self.class.get_source_name}, Credentials: #{@credentials}, ErrorMessage: #{response.code}, #{response.body}"
      end
    rescue => e
      raise Collector::Error::InvalidContent, "Integration: #{self.class.get_source_name}, Credentials: #{@credentials}, ErrorMessage: #{e.message}"
    end
  end

  def content_item_attributes(entry)
    url = get_url(entry['URLs'])
    url_with_org_domain = url_with_org_domain(url)

    title = sanitize_content(entry['Title'].to_s.strip)
    description = sanitize_content(entry['Description'].to_s.strip)

    {
      name:         title,
      description:  description,
      author:       entry['Authors'].map {|x|x['Fullname']}.join(', '),
      url:          url_with_org_domain,
      tags:         get_tags(entry['Tags']),
      content_type: 'course',
      external_id:  url,
      raw_record:   entry,
      summary:      entry["ShortDescription"],

      resource_metadata:  {
        title:       title,
        description: description,
        url:         url_with_org_domain,
        images:      get_images(url)
      },

      additional_metadata: {
        duration_in_seconds: entry["DurationInSeconds"],
        views_count: entry["Views"],
        skill_level: skill_level(entry['Tags']),
        course_type: course_type(entry['Tags']),
        course_id: entry['ID']
      }
    }
  end

  def course_type(tags)
    tag = tags.select {|x| x["TypeName"] == 'CourseType' }.first
    tag["Name"] if tag.present?
  end

  def skill_level(tags)
    tag = tags.select {|x| x["TypeName"] == 'Level' }.first
    tag["Name"] if tag.present?
  end

  def get_images(url)
    resource_metadata = get_url_meta_data(url)
    if resource_metadata[:images].present?
      resource_metadata[:images].collect do |image|
        { url: image[:url] }
      end
    end
  end

  def get_tags(tags)
    tags.collect do |x|
      { source: 'native', tag_type: 'keyword', tag: x['Name'] }
    end
  end

  def get_url(list)
    id_regex = /\/(\d+)(-\d+)?\.html$/
    'https://'+ list.to_a.first.join
  end

  def url_with_org_domain(url)
    if url && @credentials['domain'].present?
      uri = URI(url)
      params = URI.decode_www_form(uri.query || "") << ['org', @credentials['domain']]
      uri.query = URI.encode_www_form(params)
      url = uri.to_s
    end

    url
  end

  def filter_includes
    'Description,ShortDescription,DateReleasedUTC,DateUpdatedUTC,Title,Tags,DurationInSeconds,URLs,Authors.Fullname,Thumbnails,ID,Views'
  end

  def filter_values
    'Thumbnails[Width$gte$110,Width$lte$180,Height$gte$110,Height$lte$180]'
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end
end
