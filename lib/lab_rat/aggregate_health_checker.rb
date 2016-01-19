require "bunny"
require "rabbitmq/http/client"
require "securerandom"
require "timeout"
require "cgi"

class LabRat
    class AggregateHealthChecker
        CONNECTION_TIMEOUT = 4
        N = 100

        def check(protos)
            protos.map do |m|
                k = m[:proto] || m["proto"]

                case k
                when "amqp", "amqp+ssl" then
                    check_amqp(m)
                when "management", "management+ssl" then
                    check_management(m)
                when "mqtt", "mqtt+ssl" then
                    check_mqtt(m)
                end
            end.compact
        end

        def check_amqp(proto)
            begin
              tls_cert = File.expand_path("../../../tls/client_certificate.pem", __FILE__)
              tls_key = File.expand_path("../../../tls/client_key.pem", __FILE__)
              tls_ca_certificates = [File.expand_path("../../../tls/ca_certificate.pem", __FILE__)]
              conn = Bunny.new(
                proto["uri"],
                :tls_cert            => tls_cert,
                :tls_key             => tls_key,
                :tls_ca_certificates => tls_ca_certificates,
                :verify_peer         => false,
              )
              conn.start
              tls = !!conn.uses_tls?

              ch   = conn.create_channel
              q    = ch.queue("", :exclusive => true)

              q.publish(SecureRandom.hex(20))
              _, _, payload = q.pop


              {
                :proto             => :amqp,
                :uri               => proto["uri"],
                :connection        => conn,
                :tls               => tls,
                :queue             => q,
                :consumed_message_payload  => payload
              }
            rescue Exception => e
            {
              :proto     => :amqp,
              :uri       => proto["uri"],
              :exception => e
            }
            ensure
              conn.close if !conn.nil? && conn.connected?
          end
        end # check_amqp

        def check_management(proto)
            begin
              with_timeout do
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
                overview    = http_client.overview

              {
                :proto                     => :management,
                :tls                       => (http_uri.scheme == "https"),
                :management_plugin_version => overview.management_version,
                :statistics_db_node        => overview.statistics_db_node,
                :full_erlang_version       => overview.erlang_full_version,
                :object_totals             => overview.object_totals.to_hash
              }
              end
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
        with_timeout do
          c   = MQTT::Client.connect(:remote_host => proto["host"],
            :port          => proto["port"],
            :username      => proto["username"],
            :password      => proto["password"],
            :client_id     => "mqtt_test_client",
            :clean_session => false)
          msg = "mqtt #{SecureRandom.hex}"
          c.subscribe(["test_subscription", 1])
          N.times { c.publish("/pcf/mqtt-test", msg) }
          c.disconnect

          {
            :proto      => :mqtt,
            :uri        => proto["uri"],
            :payload    => msg
          }
        end
      rescue Exception => e
        puts e.message
        {
          :proto     => :mqtt,
          :uri       => proto["uri"],
          :exception => e
        }
      end
    end

    def check_stomp(proto)
      begin
        logger = Logger.new(STDOUT)
        c   = Stomp::Client.new({
            :hosts                  => [
              {:host     => proto["host"],
               :port     => proto["port"],
               :login    => proto["username"],
               :passcode => proto["password"]}
            ],
            :connect_headers => {
              :host => proto["vhost"],
              "accept-version" => "1.1"
            },
            :connread_timeout       => 3,
            :connect_timeout        => 3,
            :max_reconnect_attempts => 0,
            :logger                 => logger
          })
        t   = "/topic/stomp-test"
        msg = "stomp #{SecureRandom.hex}"

        N.times { c.publish(t, msg) }
        c.close

        {
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

    protected

    def with_timeout(&block)
      Timeout.timeout(CONNECTION_TIMEOUT) do
        begin
          block.call
        rescue Exception => e
          {:exception => e}
        end
      end
    end
  end
end
