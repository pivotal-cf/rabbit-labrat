require "bunny"
require "rabbitmq/http/client"
require "securerandom"

class LabRat
  class AggregateHealthChecker
    def check(protos)
      begin
        amqp_status = check_amqp(protos)
        http_status = check_management(protos)

        [amqp_status, http_status].reduce([]) do |acc, m|
          acc << m
        end
      rescue Exception => e
        {
          :uri       => protos["amqp"]["uri"],
          :exception => e
        }
      end
    end


    def check_amqp(protos)
      begin
        conn = Bunny.new(protos["amqp"],
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
          :uri               => protos["amqp"]["uri"],
          :connection        => conn,
          :tls               => !!conn.uses_tls?,
          :queue             => q,
          :consumed_message_payload  => payload
        }
      rescue Exception => e
        {
          :uri       => protos["amqp"]["uri"],
          :exception => e
        }
      end
    end # check_amqp

    def check_management(protos)
      begin
        http_uri    = URI.parse(protos["management"]["uri"])
        opts        = if http_uri.scheme == "https"
                        # since this is an example,
                        # it is reasonable for the client to not
                        # authenticate to the service. MK.
                        {:ssl => {:verify => false}}
                      else
                        {}
                      end
        http_client = RabbitMQ::HTTP::Client.new(protos["management"]["uri"], opts)
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
          :uri       => protos["management"]["uri"],
          :exception => e
        }
      end
    end
  end
end
