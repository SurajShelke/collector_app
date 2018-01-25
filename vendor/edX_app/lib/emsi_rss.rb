require 'net/http'
require 'openssl'
require 'byebug'
require 'faraday'
# uri = URI('https://emsiservices.com/jpa/taxonomies/title')

# Net::HTTP.start(uri.host, uri.port,
#   :use_ssl => uri.scheme == 'https', 
#   :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|

#   request = Net::HTTP::Get.new uri.request_uri
#   request.basic_auth 'edcast', '8e944092-9d77-42af-9621-960fba17499f'

#   response = http.request request # Net::HTTPResponse object
#   result = JSON.parse(response.body)
#   @job_posts = result["data"]
# end

#Get a sample of individual postings that match a set of filters.
# uri = URI("https://emsiservices.com/jpa/samples")  # https://emsiservices.com/jpa/samples

# Net::HTTP.start(uri.host, uri.port,
#   :use_ssl => uri.scheme == 'https', 
#   :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|

# 	header = {'Content-Type': 'application/json'}

#   request = Net::HTTP::Post.new(uri.request_uri, header)
#   request.basic_auth 'edcast', '8e944092-9d77-42af-9621-960fba17499f'
#   request.set_form_data(
# 								    filter: {
# 								        when: {
# 								            start: "2014-01",
# 								            end: "2016-03"
# 								        },
# 								        keywords: {
# 								            query: "Business Skills, Security, Networking",
# 								            type: "or"
# 								        }
# 								    },
# 								    limit: 10
# 									)

#   response = http.request request # Net::HTTPResponse object
#   byebug
#   # puts response
#   result = JSON.parse(response.body)
#   @job_posts = result["data"]
# end

params = "{
						filter: {
								        when: {
								            start: '2014-01',
								            end: '2016-03'
								        },
								        keywords: {
								            query: 'Business Skills, Security, Networking',
								            type: 'or'
								        }
								    },
								    limit: 10
					}"

conn = Faraday.new("https://emsiservices.com")
response = conn.post do |req|
  req.url '/jpa/samples'
  req.headers = { 'Content-Type' => 'application/json' }
  req.body = params
end
byebug
puts response.body