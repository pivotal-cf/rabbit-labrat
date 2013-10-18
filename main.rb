require "sinatra/base"
require "multi_json"
require "bunny"

# For development
if File.exists?("vcap_services.json") && File.readable?("vcap_services.json")
  ENV["VCAP_SERVICES"] = MultiJson.dump(MultiJson.load(File.read("vcap_services.json")))
end

Tilt.register Tilt::ERBTemplate, 'html.erb'

class LabRat < Sinatra::Base
  require 'sinatra/reloader' if development?

  configure do
    set :server, :puma
    set :views,  File.join(settings.root, 'views')
  end

  get "/" do
    erb :index
  end

  get "/services/rabbitmq" do
    if ENV["VCAP_SERVICES"]
      svs  = MultiJson.load(ENV["VCAP_SERVICES"])
      uri  = svs["rabbitmq-1.0"].first["credentials"]["uri"]
      conn = Bunny.new(uri, :verify_peer => false)
      begin
        conn.start

        ch   = conn.create_channel
        q    = ch.queue("", :exclusive => true)

        erb :rabbitmq_service, :locals => {
          :healthy    => true,
          :connection => conn,
          :channel    => ch,
          :queue      => q
        }
      rescue Bunny::PossibleAuthenticationFailureError => e
        erb :rabbitmq_service, :locals => {
          :healthy    => false,
          :connection => nil
        }
      end
    else
      erb :rabbitmq_service, :locals => {
        :healthy => false
      }
    end
  end
end
