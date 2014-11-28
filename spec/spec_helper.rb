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
