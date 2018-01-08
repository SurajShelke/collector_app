require 'net/http'
require 'openssl'

class JobPostsController < ApplicationController

	OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

	def job_postings
    begin
    	@q = params[:q]
    	@start = (Date.today - 2.months).strftime("%Y-%m")   # Current date MINUS 2 months
			@end 	 = Date.today.strftime("%Y-%m")
    	result = User.new.job_postings(params[:q], params[:limit] || 10)
	    @jobposts = result["data"]["samples"]
	    respond_to :rss
	  rescue Exception => err
	  	render json: { message: 'Invalid or bad parameters' }, status: :unprocessable_entity
	  end
  end


  def feed
		uri = URI('https://emsiservices.com/jpa/taxonomies/title')

		Net::HTTP.start(uri.host, uri.port, 
			:use_ssl => uri.scheme == 'https', 
			:verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|

		  request = Net::HTTP::Get.new uri.request_uri
		  request.basic_auth EMSI_USER, EMSI_PASS

		  response = http.request request # Net::HTTPResponse object
		  @jobposts = JSON.parse(response.body)["data"]
		end

    respond_to do |format|
      format.rss { render :layout => false }
    end
  end
end
