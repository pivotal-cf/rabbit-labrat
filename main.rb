require "sinatra/base"
require "multi_json"
require "bunny"

$LOAD_PATH << "./lib"

# For development
if File.exists?("vcap_services.json") && File.readable?("vcap_services.json")
  ENV["VCAP_SERVICES"] = MultiJson.dump(MultiJson.load(File.read("vcap_services.json")))
end

Tilt.register Tilt::ERBTemplate, 'html.erb'

class LabRat < Sinatra::Base
  require "lab_rat/health_checker"
  require 'sinatra/reloader' if development?

  configure do
    set :server, :puma
    set :views,  File.join(settings.root, 'views')
  end

  helpers do
    def svs
      MultiJson.load(ENV["VCAP_SERVICES"])
    end

    def creds
      creds = svs["rabbitmq-1.0"].
        map { |h| h["credentials"] }
    end
  end

  get "/" do
    erb :index
  end

  get "/vcap/services.json" do
    MultiJson.dump(ENV["VCAP_SERVICES"])
  end

  get "/services/rabbitmq" do
    if ENV["VCAP_SERVICES"]
      hc      = HealthChecker.new
      results = creds.map { |c| hc.check(c) }

      erb :rabbitmq_service, :locals => {
        :results => results
      }
    end
  end

  get "/services/rabbitmq.json" do
    if ENV["VCAP_SERVICES"]
      begin
        hc      = HealthChecker.new
        results = creds.
          map { |c| hc.check(c) }.
          map do |h|
          # modify objects that cannot be serialized to JSON
          h[:connection] = "connected"
          h[:queue] = h[:queue].name

          h
        end

        MultiJson.dump(results.to_json)
      rescue Exception => e
        MultiJson.dump({:exception => e.message})
      end
    end
  end
end
