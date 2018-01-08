require 'faraday_middleware'

class User < ApplicationRecord
	# OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
	def job_postings(q, limit)
		begin
			q = q.gsub("+", " ")
	    params = {
	        filter: {
							        when: {
							            start: (Date.today - 2.months).strftime("%Y-%m"),   # Current date MINUS 2 months
							            end: Date.today.strftime("%Y-%m") # Current date
							        },
							        
							        keywords: {
							            query: q,
							            type: "or"
							        }
							    },
							    limit: limit.to_i
	      }
	    conn = Faraday.new('https://emsiservices.com') do |b|
	    	b.use FaradayMiddleware::EncodeJson
	  		b.adapter Faraday.default_adapter
	    end
	    conn.basic_auth(EMSI_USER, EMSI_PASS)
	    response = conn.post do |req|
	      req.url '/jpa/samples'
	      req.headers.update({ 'Content-type' => 'application/json' })
	      req.body = params
	    end
	    JSON.parse(response.body)
	  rescue Exception => err
	  	Rails.logger.debug "Exception while fetching job postings for query: #{q}, limit: #{limit}: #{err.message}"
	  	err.backtrace.each { |ee| Rails.logger.debug ee }
	  	nil
	  end
  end


end
