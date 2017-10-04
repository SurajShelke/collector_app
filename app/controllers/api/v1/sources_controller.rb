class Api::V1::SourcesController < ApplicationController
  skip_before_action :verify_authenticity_token

  def fetch_content
    Source.fetch_content(params[:id])
    head :ok
  end
end
