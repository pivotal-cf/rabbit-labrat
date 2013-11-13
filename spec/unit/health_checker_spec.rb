require "spec_helper"

require "lab_rat/aggregate_health_checker"


describe LabRat::AggregateHealthChecker do
  context "with valid credentials" do
    let(:credentials) do
      [{
          "uri"   => "amqp://guest:guest@127.0.0.1",
          :proto  => "amqp"
        },
        {
          :proto  => "management",
          "uri"   => "http://guest:guest@127.0.0.1:15672/api"
        }]
    end

    it "returns check results as a map" do
      m = subject.check(credentials).first

      m[:uri].should == credentials.first["uri"]
      m[:connection].should be_connected

      m[:queue].should_not be_nil
      m[:consumed_message_payload].should_not be_nil

      m[:connection].close
    end
  end


  context "with invalid credentials" do
    let(:credentials) do
      [{
          "uri"   => "amqp://guest:guest@127.0.87.9",
          :proto  => "amqp"
        },
        {
          :proto  => "management",
          "uri"   => "http://guest:guest@192.168.80.91:15678/api"
        }]
    end

    it "returns check results with :exception" do
      m = subject.check(credentials).first

      m[:exception].should_not be_nil
    end
  end
end
