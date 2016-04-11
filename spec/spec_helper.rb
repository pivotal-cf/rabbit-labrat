# encoding: binary

require 'bundler/setup'
require 'rspec'

require "effin_utf8"

$: << File.expand_path('../../lib', __FILE__)
$: << File.expand_path('../../', __FILE__)

class RabbitMQAdmin
  def initialize(admin_uri)
    @conn = Faraday.new(:url => admin_uri)

    @vhost = 'labrat'
    @user = 'guest'
  end

  def create_vhost_and_user
    conn.put "/api/vhosts/#{vhost}" do |req|
      req.headers['Content-Type'] = 'application/json'
    end

    conn.put "/api/permissions/#{vhost}/#{user}" do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = '{"configure":".*","write":".*","read":".*"}'
    end
  end

  def delete_vhost
    conn.delete "/api/vhosts/#{vhost}" do |req|
      req.headers['Content-Type'] = 'application/json'
    end
  end

  private

  attr_reader :conn, :vhost, :user
end

RSpec.configure do |config|
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!

  Kernel.srand config.seed
end
