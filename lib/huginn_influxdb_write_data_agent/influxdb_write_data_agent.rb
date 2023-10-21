module Agents
  class InfluxdbWriteDataAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'never'

    description do
      <<-MD
      The Influxdb Write Data Agent writes events to an InfluxDB time series database..

      `url` is the influxdb url ( ex: http://influxdb:8086).

      `influxdb_version` to choose if api V1 or V2.

      `debug` is used for verbose mode.

      `database` is the database's / bucket's name.

      `token` is needed with v2 for auth.

      `org` is needed with v2 for queries.

       If `emit_events` is set to `true`, the server response will be emitted as an Event. No data processing
       will be attempted by this Agent, so the Event's "body" value will always be raw text.

      `data` is the equivalent of data-binary in curl command, in influx line protocol (ex: campaigns_number,region=fr value=1111 1603573200000000000).

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
        'token' => '',
        'org' => '',
        'influxdb_version' => '',
        'database' => '',
        'data' => '',
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'emit_events' => 'false'
      }
    end

    form_configurable :url, type: :string
    form_configurable :token, type: :string
    form_configurable :org, type: :string
    form_configurable :influxdb_version, type: :array,values: ['v1', 'v2']
    form_configurable :debug, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :database, type: :string
    form_configurable :data, type: :string
    form_configurable :emit_events, type: :boolean

    def validate_options
      errors.add(:base, "influxdb_version has invalid value: should be 'v1' 'v2'") if interpolated['influxdb_version'].present? && !%w(v1 v2).include?(interpolated['influxdb_version'])

      unless options['database'].present?
        errors.add(:base, "database is a required field")
      end

      unless options['token'].present? || !['v2'].include?(options['influxdb_version'])
        errors.add(:base, "token is a required field")
      end

      unless options['org'].present? || !['v2'].include?(options['influxdb_version'])
        errors.add(:base, "org is a required field")
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

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          log event
          write_data
        end
      end
    end

    def check
      write_data
    end

    private

    def write_datav1

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

    def write_datav2

      full_url = interpolated['url'] + '/api/v2/write?org=' + interpolated['org'] + '&bucket=' + interpolated['database'] + '&precision=ns'

      if interpolated['debug'] == 'true'
        log full_url
      end

      uri = URI.parse(full_url)
      request = Net::HTTP::Post.new(uri)
      request.content_type = "text/plain; charset=utf-8"
      request["Authorization"] = "token #{interpolated['token']}"
      request["Accept"] = "application/json"
      request.body = "#{interpolated['data']}"

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      if interpolated['emit_events'] == 'true'
        create_event :payload => { 'http_status' => "#{response.code}"}
      end

    end

    def write_data
      case interpolated['influxdb_version']
      when "v1"
         write_datav1()
      when "v2"
         write_datav2()
      else
        log "Error: influxdb_version has an invalid value (#{type})"
      end
    end
  end
end
