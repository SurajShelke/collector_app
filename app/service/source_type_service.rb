class SourceTypeService < EclCommunicator
  attr_accessor :client_id,:secret,:communicator
  
  def initialize(client_id,secret)
    @client_id = client_id
    @token = token
  end
  # Get Source Type Name
  def get_source_type_by_name(source_type_name,options={})
    params = { name: source_type_name }
    params[:limit]  = options[:limit] || 10
    params[:offset] = options[:offset] || 0

    @communicator = EclDeveloperClient::SourceType.new(@client_id,@secret)
    response = @communicator.get(params)
    response.success? ? @communicator.response_data["data"] : []
  end


  # Get Source Type based on id
  def find(source_type_id)
    @communicator = EclDeveloperClient::SourceType.new(@client_id,@secret)
    response = @communicator.find(source_type_id)
    response.success? ? @communicator.response_data["data"] : {}
  end

  # Get Sources for given source type id
  # Default @options ={limit=>0,offset=>10}
  def get_sources(source_type_id, options= {limit: 10, offset: 0})
    options[:source_type_id] = source_type_id
    @communicator = EclDeveloperClient::Source.new(@client_id,@secret)
    response = @communicator.get(options)
    response.success? ? @communicator.response_data["data"] : []
  end

  # def self.fetch_content(source_type_id)
  #   DropboxCollectorJob.perform_async(source_type_id)
  # end
end
