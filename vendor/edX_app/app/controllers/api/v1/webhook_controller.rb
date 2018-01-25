class Api::V1::WebhookController < ApplicationController
  skip_before_action :verify_authenticity_token

  def fetch_content
    Webhook::TriggerService.new(params).run
    render json: {success: true}
  end
end
