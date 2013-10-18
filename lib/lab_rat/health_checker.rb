require "bunny"
require "rabbitmq/http/client"
require "securerandom"

class LabRat
  class HealthChecker
    def check(credentials)
      begin
        conn = Bunny.new(credentials["uri"],
          :tls_cert            => "./tls/client_cert.pem",
          :tls_key             => "./tls/client_key.pem",
          :tls_ca_certificates => ["./tls/cacert.pem"])
        conn.start

        ch   = conn.create_channel
        q    = ch.queue("", :exclusive => true)

        q.publish(SecureRandom.hex(20))
        _, _, payload = q.pop

        http_uri    = URI.parse(credentials["http_api_uri"])
        opts        = if http_uri.scheme == "https"
                        # since this is an example,
                        # it is reasonable for the client to not
                        # authenticate to the service. MK.
                        {:ssl => {:verify => false}}
                      else
                        {}
                      end
        http_client = RabbitMQ::HTTP::Client.new(credentials["http_api_uri"], opts)
        overview    = http_client.overview

        {
          :uri               => credentials["uri"],
          :connection        => conn,
          :tls               => !!conn.uses_tls?,
          :queue             => q,
          :management_plugin_version => overview.management_version,
          :statistics_db_node        => overview.statistics_db_node,
          :full_erlang_version       => overview.erlang_full_version,
          :object_totals             => overview.object_totals.to_hash,
          :consumed_message_payload  => payload
        }
      rescue Bunny::PossibleAuthenticationFailureError => e
        {
          :uri       => credentials["uri"],
          :exception => e
        }
      end
    end
  end
end
