require "spec_helper"
require "main"

describe "LabRat HTTP API" do
  before :all do
    @t = Thread.new do
      LabRat.run!
    end
    @t.abort_on_exception = true

    # give HTTP server some time to start
    sleep 1.5
  end

  after :all do
    @t.kill
    @t.join
  end

  before :each do
    ENV["VCAP_SERVICES"] = MultiJson.dump(MultiJson.load(vcap_services))
  end

  let(:conn) { Faraday.new(:url => "http://127.0.0.1:4567/") }

  def get(path)
    conn.get(path)
  end

  describe "/services/rabbitmq" do
    context "with valid credentials" do
      let(:vcap_services) do
        <<-JSON
        {
          "rabbitmq-1.0": [
            {
              "name": "rabbit1",
              "label": "rabbitmq",
              "provider": "megacorp",
              "tags": ["amqp", "rabbitmq"],
              "plan": "free",
              "credentials": {
                "uri":          "amqp://guest:guest@127.0.0.1/labrat",
                "http_api_uri": "http://guest:guest@127.0.0.1:15672/api"
              }
            }
          ]
        }
        JSON
      end

      it "responds with 200" do
        res = get("services/rabbitmq")
        res.status.should == 200
      end
    end

    context "with invalid credentials" do
      let(:vcap_services) do
        <<-JSON
        {
          "rabbitmq-1.0": [
            {
              "name": "rabbit1",
              "label": "rabbitmq",
              "provider": "megacorp",
              "tags": ["amqp", "rabbitmq"],
              "plan": "free",
              "credentials": {
                "uri":          "amqp://guest_-s9d8:guest87832738@127.0.0.1/labrat",
                "http_api_uri": "http://8as7djk2jkjl8#7727:8sds7d7a7@127.0.0.1:15672/api"
              }
            }
          ]
        }
        JSON
      end

      it "responds with 500" do
        res = get("services/rabbitmq")
        res.status.should == 500
      end
    end
  end


  describe "/services/rabbitmq.json" do
    context "with valid credentials" do
      let(:vcap_services) do
        <<-JSON
        {
          "rabbitmq-1.0": [
            {
              "name": "rabbit1",
              "label": "rabbitmq",
              "provider": "megacorp",
              "tags": ["amqp", "rabbitmq"],
              "plan": "free",
              "credentials": {
                "uri":          "amqp://guest:guest@127.0.0.1/labrat",
                "http_api_uri": "http://guest:guest@127.0.0.1:15672/api"
              }
            }
          ]
        }
        JSON
      end

      it "responds with 200" do
        res = get("services/rabbitmq.json")
        res.status.should == 200
      end
    end

    context "with invalid credentials" do
      let(:vcap_services) do
        <<-JSON
        {
          "rabbitmq-1.0": [
            {
              "name": "rabbit1",
              "label": "rabbitmq",
              "provider": "megacorp",
              "tags": ["amqp", "rabbitmq"],
              "plan": "free",
              "credentials": {
                "uri":          "amqp://guest_-s9d8:guest87832738@127.0.0.1/labrat",
                "http_api_uri": "http://8as7djk2jkjl8#7727:8sds7d7a7@127.0.0.1:15672/api"
              }
            }
          ]
        }
        JSON
      end

      it "responds with 500" do
        res = get("services/rabbitmq.json")
        res.status.should == 500
      end
    end
  end
end
