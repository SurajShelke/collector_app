# options = {id: "162d6e4d-e780-48f4-b471-280c88aaf14b", webhook_type: "source"}
# Collector::TriggerService.new(options)

module Webhook
  class TriggerService
    attr_accessor :options, :record, :collector_queue_name,:collector_class_name,:app_config

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

    # TODO raise exception if no source type or sources has been configured
    def fetch_record
      if @options[:webhook_type] == "source_type"
        @app_config = AppConfig.integrations.select {|k,v|v["source_type_id"] == @options[:id]}.first
        app_config_value = @app_config[1]
        @ecl_client_id = app_config_value["ecl_client_id"]
        @ecl_token = app_config_value["ecl_token"]
        communicator = EclDeveloperClient::SourceType.new(@ecl_client_id, @ecl_token)
      elsif @options[:webhook_type] == "source"
        @app_config = AppConfig.integrations.select {|k,v|v["source_type_id"] == @options[:source_type_id] }.first
        app_config_value = @app_config[1]
        @ecl_client_id = app_config_value["ecl_client_id"]
        @ecl_token = app_config_value["ecl_token"]
        communicator = EclDeveloperClient::Source.new(@ecl_client_id, @ecl_token)
      end

      response      = communicator.find(@options[:id])
      response_data = communicator.response_data
      @record       = response_data["data"] if response.success?
    end

    def source_type_name
      @options[:webhook_type] == "source_type" ? @record["name"] : @record["source_type_name"]
    end
  end
end
