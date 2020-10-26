require 'huginn_agent'

#HuginnAgent.load 'huginn_influxdb_write_data_agent/concerns/my_agent_concern'
HuginnAgent.register 'huginn_influxdb_write_data_agent/influxdb_write_data_agent'
