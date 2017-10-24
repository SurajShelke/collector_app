class Api::V1::WebhookController < ApplicationController
  skip_before_action :verify_authenticity_token

  def fetch_content
    Collector::TriggerService.new(params).run
    head :ok
  end
end
