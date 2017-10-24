class EclCommunicator
  attr_accessor :client_id,:token

  def initialize(client_id,token)
    @token = token
    @client_id = client_id
    @payload = payload

  end

end
