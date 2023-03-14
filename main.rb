require "sinatra/base"
require "multi_json"
require "bunny"

require "mqtt"
require "stomp"

$LOAD_PATH << "./lib"

# For development
if File.exist?("vcap_services.json") && File.readable?("vcap_services.json")
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
      rabbitmq_services.map { |h| h["credentials"] }.map do |creds|
        creds["protocols"] || {
          "amqp"       => {"uri" => creds["uri"], "uris" => creds["uris"]},
          "management" => {"uri" => creds["http_api_uri"]}
        }
      end.flat_map do |m|
        m.map { |(k, v)| v.merge(:proto => k)}
      end.compact
    end

    def amqp091_conn
      conns.detect { |m| %w(amqp amqp+ssl).include?(m[:proto]) }
    end

    def stomp_conn
      conns.detect { |m| %w(stomp stomp+ssl).include?(m[:proto]) }
    end

    def mqtt_conn
      conns.detect { |m| %w(mqtt mqtt+ssl).include?(m[:proto]) }
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
      results = hc.check_amqp(amqp091_conn)

      if results.empty? || results.any? { |r| !!r[:exception] }
        status 500
      end

      erb :check_protocol_amqp091, :locals => {
        :results => results
      }
    else
      status 500
      "VCAP_SERVICES is not set or blank"
    end
  end

  get "/services/rabbitmq/protocols/mqtt" do
    if ENV["VCAP_SERVICES"] && !ENV["VCAP_SERVICES"].empty?
      hc     = AggregateHealthChecker.new
      result = hc.check_mqtt(mqtt_conn)

      if result.empty? || !!result[:exception]
        status 500
      end

      erb :check_protocol_mqtt, :locals => {
        :result => result
      }
    else
      status 500
      "VCAP_SERVICES is not set or blank"
    end
  end

  get "/services/rabbitmq/protocols/stomp" do
    if ENV["VCAP_SERVICES"] && !ENV["VCAP_SERVICES"].empty?
      hc     = AggregateHealthChecker.new
      result = hc.check_stomp(stomp_conn)

      if result.empty? || !!result[:exception]
        status 500
      end

      erb :check_protocol_stomp, :locals => {
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
