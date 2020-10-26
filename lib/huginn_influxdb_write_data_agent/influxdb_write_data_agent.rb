module Agents
  class InfluxdbWriteDataAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule '1h'

    description do
      <<-MD
      The Github notification agent fetches notifications and creates an event by notification.

      `url` is the influxdb url ( ex: http://influxdb:8086).

      `debug` is used for verbose mode.

      `database` is the database's name.

       If `emit_events` is set to `true`, the server response will be emitted as an Event. No data processing
       will be attempted by this Agent, so the Event's "body" value will always be raw text.

      `data` is the equivalent of data-binary in curl command (ex: campaigns_number,region=fr value=1111 1603573200000000000).

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "http_status": "204"
        }
    MD

    def default_options
      {
        'url' => '',
        'database' => '',
        'data' => '',
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'emit_events' => 'false'
      }
    end

    form_configurable :url, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :database, type: :string
    form_configurable :data, type: :string
    form_configurable :emit_events, type: :boolean

    def validate_options
      unless options['database'].present?
        errors.add(:base, "database is a required field")
      end

      unless options['url'].present?
        errors.add(:base, "url is a required field")
      end

      unless options['data'].present?
        errors.add(:base, "data is a required field")
      end

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      write_data
    end

    private

    def write_data

      full_url = interpolated['url'] + '/write?db=' + interpolated['database']
  
      if interpolated['debug'] == 'true'
        log full_url
      end
  
      uri = URI.parse(full_url)
      request = Net::HTTP::Post.new(uri)
      request.body = "#{interpolated['data']}"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
       
      log "request  status : #{response.code}"
  
      if interpolated['debug'] == 'true'
        log "response body : #{response.body}"
      end
  
      if interpolated['emit_events'] == 'true'
        create_event :payload => { 'http_status' => "#{response.code}"} 
      end
    end
  end
end
