class Api::V1::SourceTypesController < ApplicationController
  skip_before_action :verify_authenticity_token

  def fetch_content
    SourceType.fetch_content(params[:id])
    head :ok
  end
end
