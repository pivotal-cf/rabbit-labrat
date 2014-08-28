require "sinatra/base"
require "multi_json"
require "bunny"

require "mqtt"
require "stomp"

$LOAD_PATH << "./lib"

# For development
if File.exists?("vcap_services.json") && File.readable?("vcap_services.json")
  puts "WARNING: using VCAP_SERVICES from vcap_services.json!"
  ENV["VCAP_SERVICES"] = MultiJson.dump(MultiJson.load(File.read("vcap_services.json")))
end

Tilt.register Tilt::ERBTemplate, 'html.erb'

class LabRat < Sinatra::Base
  require "lab_rat/aggregate_health_checker"
  require 'sinatra/reloader' if development?

  configure do
    set :server, :puma
    set :bind,   "0.0.0.0"
    set :port,   ENV.fetch("PORT", 4567)
    set :views,  File.join(settings.root, 'views')
  end

  helpers do
    def svs
      MultiJson.load(ENV["VCAP_SERVICES"])
    end

    def rabbitmq_services
      svs.values.reduce([]) do |acc, instances|
        xs = instances.select do |m|
          m["label"] =~ /rabbitmq/i || (m["tags"] && m["tags"].include?("rabbitmq"))
        end

        acc + xs
      end
    end

    def conns
      xs = rabbitmq_services.
        map { |h| h["credentials"] }.
        map do |creds| creds["protocols"] || {
          "amqp"       => {"uri" => creds["uri"]},
          "management" => {"uri" => creds["http_api_uri"]}
        } end.reduce([]) do |acc, m|
          acc + m.reduce([]) { |acc2, (k, v)| acc2 << (v.merge(:proto => k))}
        end

      xs.compact.
        sort_by { |m| m[:proto].to_s }
    end

    def amqp091_conn
      conns.detect { |m| %w(amqp amqp+ssl).include?(m[:proto]) }
    end

    def partial(template, locals = {})
      erb(template, :layout => false, :locals => locals)
    end
  end

  get "/" do
    erb :index
  end

  get "/vcap/services.json" do
    MultiJson.dump(ENV["VCAP_SERVICES"])
  end

  get "/services/rabbitmq/protocols/all" do
    if ENV["VCAP_SERVICES"] && !ENV["VCAP_SERVICES"].empty?
      hc      = AggregateHealthChecker.new
      results = hc.check(conns)

      if results.empty? || results.any? { |m| !!m[:exception] }
        status 500
      end

      erb :check_protocols_all, :locals => {
        :results => results
      }
    else
      status 500
      "VCAP_SERVICES is not set or blank"
    end
  end

  get "/services/rabbitmq/protocols/amqp091" do
    if ENV["VCAP_SERVICES"] && !ENV["VCAP_SERVICES"].empty?
      hc     = AggregateHealthChecker.new
      result = hc.check_amqp(amqp091_conn)

      if result.empty? || !!result[:exception]
        status 500
      end

      erb :check_protocol_amqp091, :locals => {
        :result => result
      }
    else
      status 500
      "VCAP_SERVICES is not set or blank"
    end
  end

  get "/services/rabbitmq.json" do
    if ENV["VCAP_SERVICES"] && !ENV["VCAP_SERVICES"].empty?
      begin
        hc      = AggregateHealthChecker.new
        results = hc.check(conns).
          map do |h|
          # modify objects that cannot be serialized to JSON
          h[:connection] = "connected"
          h[:queue] = h[:queue].name if h[:queue]

          h
        end

        if results.empty? || results.any? { |m| !!m[:exception] }
          status 500
        end

        MultiJson.dump(results)
      rescue Exception => e
        status 500

        MultiJson.dump({:exception => "#{e.class.name}: #{e.message} (#{e.backtrace.first})"})
      end
    else
      status 500
      "VCAP_SERVICES is not set or blank"
    end
  end
end
