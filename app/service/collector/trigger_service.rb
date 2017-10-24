# options = {id: "162d6e4d-e780-48f4-b471-280c88aaf14b", webhook_type: "source"}
# Collector::TriggerService.new(options)

module Collector
  class TriggerService
    attr_accessor :options, :record, :collector_queue_name,
      :collector_class_name

    def initialize(options={})
      @options = options
      fetch_record
      get_collector_details
    end

    def run
      if @options[:webhook_type] == "source_type"
        run_source_type_collector
      elsif @options[:webhook_type] == "source"
        run_source_collector
      end
    end

    def run_source_collector
      Sidekiq::Client.push(
        'class' => FetchContentJob,
        'queue' => @collector_queue_name.to_sym,
        'args' => [@collector_class_name, record['source_config'], record['id'], record['organization_id'], record['last_polled_at']],
        'at'=> @collector_class_name.constantize.schedule_at
      )
    end

    def run_source_type_collector
      Sidekiq::Client.push(
        'class' => @collector_queue_name.camelize,
        'queue' => @collector_queue_name.to_sym,
        'args' => [],
        'at'=> @collector_class_name.constantize.schedule_at
      )
    end

    def get_collector_details
      @collector_queue_name = "#{source_type_name}_ecl_job"
      @collector_class_name = "#{source_type_name}_integration".camelize
    end

    def fetch_record
      if @options[:webhook_type] == "source_type"
        ecl_communicator = EclDeveloperClient::SourceType.new(AppConfig.dropbox['ecl_client_id'], AppConfig.dropbox['ecl_token'])
      elsif @options[:webhook_type] == "source"
        ecl_communicator = EclDeveloperClient::Source.new(AppConfig.dropbox['ecl_client_id'], AppConfig.dropbox['ecl_token'])
      end

      response      = ecl_communicator.find(@options[:id])
      response_data = ecl_communicator.response_data
      @record       = response_data["data"] if response.success?
    end

    def source_type_name
      @options[:webhook_type] == "source_type" ? @record["name"] : @record["source_type_name"]
    end
  end
end
