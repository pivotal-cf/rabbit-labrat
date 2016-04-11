require "spec_helper"

require "lab_rat/aggregate_health_checker"

RSpec.describe LabRat::AggregateHealthChecker do
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

      expect(m[:uri]).to eq credentials.first["uri"]
      expect(m[:connection]).not_to be_connected, "Health checker closes its own resources"

      expect(m[:queue]).not_to be_nil
      expect(m[:consumed_message_payload]).not_to be_nil
    end
  end


  context "with invalid credentials" do
    let(:credentials) do
      [{
        "uri"   => "amqp://guest:wrongpassword@127.0.0.1",
        :proto  => "amqp"
      },
      {
        :proto  => "management",
        "uri"   => "http://guest:guest@192.168.80.91:15678/api"
      }]
    end

    it "returns check results with :exception" do
      m = subject.check(credentials).first

      expect(m[:exception]).not_to be_nil
    end
  end
end
