require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::InfluxdbWriteDataAgent do
  before(:each) do
    @valid_options = Agents::InfluxdbWriteDataAgent.new.default_options
    @checker = Agents::InfluxdbWriteDataAgent.new(:name => "InfluxdbWriteDataAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
