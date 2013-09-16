require "sinatra/base"
require "multi_json"
require "bunny"

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
      conn = Bunny.new(uri)
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
          :healthy => false
        }
      end
    else
      erb :rabbitmq_service, :locals => {
        :healthy => false
      }
    end
  end
end
