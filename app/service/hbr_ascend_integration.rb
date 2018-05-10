# {
#    "Id":"1261",
#    "Title":"The More People We Connect with on LinkedIn, the Less Valuable It Becomes",
#    "Image":"http:\/\/www.hbrascend.in\/wp-content\/uploads\/2016\/09\/linkedin.png",
#    "Author Name":"Alexandra Samuel",
#    "Meta Description":"A large number of social connections may not necessarily add any value. Read on to find out how 'smaller is better'.",
#    "Tags":"Digital Article, Career planning, Networking, Social platforms",
#    "Url":"https:\/\/hbrascend-preprod.agilecollab.com\/topics\/the-more-people-we-connect-with-on-linkedin-the-less-valuable-it-becomes\/",
#    "Primary Skill":"Networking",
#    "Essential Skill":"Managing Your Career"
# },
# {
#    "Id":"1263",
#    "Title":"5 Misconceptions About Networking",
#    "Image":"http:\/\/www.hbrascend.in\/wp-content\/uploads\/2016\/09\/5mcpn.jpg",
#    "Author Name":"Herminia Ibarra",
#    "Meta Description":"Your mindset could be deterring you from networking more efficiently. Read on how to go beyond the famous myths of networking to derive the most out of it.",
#    "Tags":"Digital Article, Managing yourself, Networking",
#    "Url":"https:\/\/hbrascend-preprod.agilecollab.com\/topics\/5-misconceptions-about-networking\/",
#    "Primary Skill":"Networking",
#    "Essential Skill":"Managing Your Career"
# }

# doc link:
# https://docs.google.com/document/d/1ig4F5xotQodq6lIZcSmyGAmeQ6nHH45EjBPGp2ylXDM/edit?usp=sharing

class HbrAscendIntegration < BaseIntegration
  def self.get_source_name
    'hbr_ascend'
  end

  def self.get_fetch_content_job_queue
    :hbr_ascend
  end

  def self.get_credentials_from_config
    source["source_config"]
  end

  def self.ecl_client_id
    SourceTypeConfig.find_by(source_type_name: 'hbr_ascend').values['ecl_client_id']
  end

  def self.ecl_token
    SourceTypeConfig.find_by(source_type_name: 'hbr_ascend').values['ecl_token']
  end

  def get_content(options={})
    begin
      if @credentials['host_url'].present?
        headers = {
          'Content-Type' => 'application/json',
          'token' => @credentials['token']
        }

        data = json_request(
          "#{@credentials['host_url']}",
          :get,
          headers: headers,
          params: delta_params
        )

        data.each{|entry| create_content_item(entry)}
      end
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[HbrAscendIntegration] Failed Integration for source #{@credentials['source_id']}, ErrorMessage: #{err.message}"
    end
  end

  def content_item_attributes(entry)
    description = sanitize_content(entry['Meta Description'])
    url = CGI.unescape(entry['Url'])

    {
      external_id:     entry['Id'],
      source_id:       @credentials["source_id"],
      url:             url,
      name:            entry['Title'],
      description:     description,
      content_type:   'article',
      organization_id: @credentials["organization_id"],
      author:          entry['Author Name'],
      tags:            get_tags(entry['Tags']),

      resource_metadata: {
        title:         entry['Title'],
        description:   description,
        url:           url,
        images:        [{ url: entry['Image'] }]
      },

      additional_metadata: {
        skills: {
          primary_skill:   entry['Primary Skill'],
          essential_skill: entry['Essential Skill']
        }
      }
    }
  end

  def get_tags(tags)
    if tags.present?
      tags = tags.split(',')
      tags.collect do |tag|
        { source: 'native', tag_type: 'keyword', tag: tag.squish }
      end
    end
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end

  def delta_params
    if @credentials['last_polled_at'].present?
      {'sdate' => Time.parse(@credentials['last_polled_at']).to_s(:db)}
    else
      {'li' => '-1'}
    end
  end
end
