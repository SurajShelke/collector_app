class Api::V1::WebhookController < ApplicationController
  skip_before_action :verify_authenticity_token

  def fetch_content
    if params[:webhook_type] == "source_type"
      SourceType.fetch_content(params[:id])
    elsif params[:webhook_type] == "source"
      Source.fetch_content(params[:id])
    end
    head :ok
  end
end
