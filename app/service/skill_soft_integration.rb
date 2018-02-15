require 'active_support/core_ext/hash'
require 'nokogiri'
class SkillSoftIntegration < BaseIntegration
  attr_accessor :client, :source_id, :organization_id
  def self.get_source_name
    'skill_soft'
  end

  def self.get_fetch_content_job_queue
    :skill_soft
  end

  def self.get_credentials_from_config(source)
    source['source_config']
  end

  def self.ecl_client_id
    AppConfig.integrations['skill_soft']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['skill_soft']['ecl_token']
  end

  #  @options ={start: start, limit: limit, page: page, last_polled_at: @last_polled_at}
  #  We dont need start or limit for this Integration
  #  Whenever pagination is available we can use it
  def get_content(options = {})
    @options = options
    @source_id               = @credentials['source_id']
    @organization_id         = @credentials['organization_id']

    @wsdl = @credentials['wsdl']
    @customer_id = @credentials['customer_id']
    @shared_secret = @credentials['shared_secret']

    @client = Savon.client(
                            wsdl: @wsdl,
                            wsse_timestamp: true,
                            wsse_auth: [@customer_id, @shared_secret, :digest],
                            soap_version: 1
                          )
    fetch_content
  end

  def get_report_url(report_id)
    tries = 3
    begin
      response = @client.call(:util_poll_for_report, message: { customer_id: @customer_id, report_id: report_id })
      return response.body[:url_response][:olsa_url]
    rescue Exception => e
      tries -= 1
      if tries > 0
        sleep 5
        retry
      else
        raise Webhook::Error::IntegrationFailure, "[SkillSoftIntegration] Unable to get Report. #{e.message}"
      end
    end
  end

  def fetch_content
    begin
      response = @client.call(:ai_initiate_full_course_listing_report, message: { customer_id: @customer_id, report_format: 'XML', mode: 'summary' })
      report_url = get_report_url(response.body[:handle_response][:handle])

      conn = Faraday.new(report_url)
      response = conn.get

      doc = Nokogiri::XML(response.body.gsub('\n', '').gsub('\r', ''))
      full_listing_summary = Hash.from_xml(doc.to_s)

      full_listing_summary = full_listing_summary['full_listing_summary']
      assets = full_listing_summary['asset'].class == Array ?  full_listing_summary['asset'] : [full_listing_summary['asset']]

      assets.each do |asset|
        response = @client.call(:ai_get_xml_asset_meta_data, message: { customer_id: @customer_id, asset_id: asset['id'], format: 'XML' }) rescue nil
        create_content_item(response.body) if response
      end
    rescue Exception => e
      raise Webhook::Error::IntegrationFailure, "[SkillSoftIntegration] Unable to get assests. #{e.message}"
    end
  end

  def create_content_item(entry)
    attributes = {
      name:         entry['title'],
      description:  '',
      url:          entry['launchurl'],
      content_type: 'document',
      external_id:  entry['identifier'],
      raw_record:   entry,
      source_id:    @source_id,
      organization_id: @organization_id,
      resource_metadata: {
        images:       [{ url: nil }],
        title:        entry['title'],
        description:  '',
        url:          entry['launchurl']
      },
      additional_metadata: {
        size:            entry['size'],
        cTag:            entry['cTag'],
        eTag:            entry['eTag']
      }
    }

    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, attributes)
  end
end
