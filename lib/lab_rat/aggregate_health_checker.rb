require "bunny"
require "rabbitmq/http/client"
require "securerandom"

class LabRat
  class AggregateHealthChecker
    def check(protos)
      protos.map do |m|
        k = m[:proto]

        case k
        when "amqp", "amqp+ssl" then
          check_amqp(m)
        when "management", "management+ssl" then
          check_management(m)
        when "mqtt", "mqtt+ssl" then
          check_mqtt(m)
        when "stomp" then
          check_stomp(m)
        end
      end
    end


    def check_amqp(proto)
      begin
        conn = Bunny.new(proto["uri"],
          :tls_cert            => "./tls/client_cert.pem",
          :tls_key             => "./tls/client_key.pem",
          :tls_ca_certificates => ["./tls/cacert.pem"])
        conn.start

        ch   = conn.create_channel
        q    = ch.queue("", :exclusive => true)

        q.publish(SecureRandom.hex(20))
        _, _, payload = q.pop

        {
          :proto             => :amqp,
          :uri               => proto["uri"],
          :connection        => conn,
          :tls               => !!conn.uses_tls?,
          :queue             => q,
          :consumed_message_payload  => payload
        }
      rescue Exception => e
        {
          :proto     => :amqp,
          :uri       => proto["uri"],
          :exception => e
        }
      end
    end # check_amqp

    def check_management(proto)
      begin
        http_uri    = URI.parse(proto["uri"])
        opts        = if http_uri.scheme == "https"
                        # since this is an example,
                        # it is reasonable for the client to not
                        # authenticate to the service. MK.
                        {:ssl => {:verify => false}}
                      else
                        {}
                      end
        http_client = RabbitMQ::HTTP::Client.new(proto["uri"], opts)
        puts proto.inspect
        overview    = http_client.overview

        {
          :proto                     => :management,
          :management_plugin_version => overview.management_version,
          :statistics_db_node        => overview.statistics_db_node,
          :full_erlang_version       => overview.erlang_full_version,
          :object_totals             => overview.object_totals.to_hash
        }
      rescue Exception => e
        {
          :proto     => :management,
          :uri       => proto["uri"],
          :exception => e
        }
      end
    end

    def check_mqtt(proto)
      begin
        u   = URI.parse(proto["uri"])
        c   = MQTT::Client.connect(u.host)
        msg = "mqtt #{SecureRandom.hex}"
        c.publish("mqtt-test", msg)

        {
          :proto      => :mqtt,
          :uri        => proto["uri"],
          :connection => c,
          :payload    => msg
        }
      rescue Exception => e
        {
          :proto     => :mqtt,
          :uri       => proto["uri"],
          :exception => e
        }
      end
    end

    def check_stomp(proto)
      begin
        c   = Stomp::Client.new(proto["uri"])
        msg = "stomp #{SecureRandom.hex}"
        c.publish("stomp-test", msg)

        {
          :connection => c,
          :proto      => :stomp,
          :uri        => proto["uri"],
          :payload    => msg
        }
      rescue Exception => e
        {
          :proto     => :stomp,
          :uri       => proto["uri"],
          :exception => e
        }
      end
    end

  end
end
