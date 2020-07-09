require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::UpholdCardBalanceAgent do
  before(:each) do
    @valid_options = Agents::UpholdCardBalanceAgent.new.default_options
    @checker = Agents::UpholdCardBalanceAgent.new(:name => "UpholdCardBalanceAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
