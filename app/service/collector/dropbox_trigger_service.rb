# options = {id: "162d6e4d-e780-48f4-b471-280c88aaf14b", webhook_type: "source"}
# Collector::TriggerService.new(options)

module Collector 
  class DropboxTriggerService < Collector::TriggerService
    attr_accessor :options, :record, :collector_queue_name,
      :collector_class_name

    def initialize(options={})
      super(options)
      @ecl_client_id = AppConfig.dropbox['ecl_client_id']
      @ecl_token = AppConfig.dropbox['ecl_token']
      fetch_record
      get_collector_details
    end

   
  end
end
