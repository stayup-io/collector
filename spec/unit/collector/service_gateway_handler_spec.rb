# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", File.dirname(__FILE__))

describe Collector::ServiceGatewayHandler do
  it "has the right component type" do
    handler = Collector::ServiceGatewayHandler.new(nil, nil, nil, nil, nil)
    handler.component.should == "gateway"
  end

  describe "#process" do
    it "should call the other process methods" do
      handler = Collector::ServiceGatewayHandler.new(nil, nil, nil, nil, nil)
      handler.should_receive(:process_plan_score_metric)
      handler.should_receive(:process_online_nodes)
      handler.process
    end
  end

  describe "#process_plan_score_metric" do
    let(:history_data) { Hash.new { |h, k| h.store(k, []) } }
    let(:historian) do
      double("Historian").tap do |h|
        h.stub(:send_data) do |data|
          name = data.fetch(:key)
          history_data[name] << data
        end
      end
    end

    let(:varz) do
      {
        "plans" => [
          {
            "plan" => "free",
            "low_water" => 100,
            "high_water" => 1400,
            "score" => 150,
            "max_capacity" => 500,
            "available_capacity" => 450,
            "used_capacity" => 50
          }
        ]
      }
    end

    def self.test_report_metric(metric_name, key, value)
      it "should report #{key} to TSDB server" do
        handler = Collector::ServiceGatewayHandler.new(historian, "Test", 1, 10000, varz)
        handler.process_plan_score_metric
        history_data.fetch(metric_name).should have(1).item
        history_data.fetch(metric_name).fetch(0).should include(
          key: metric_name,
          value: value,
        )
      end
    end

    test_report_metric("services.plans.low_water", "low_water", 100)
    test_report_metric("services.plans.high_water", "high_water", 1400)
    test_report_metric("services.plans.score", "score", 150)
    test_report_metric("services.plans.allow_over_provisioning", "allow_over_provisioning", 0)
    test_report_metric("services.plans.used_capacity", "used_capacity", 50)
    test_report_metric("services.plans.max_capacity", "max_capacity", 500)
    test_report_metric("services.plans.available_capacity", "available_capacity", 450)

  end

  describe :process_online_nodes do
    it "should report online nodes number to TSDB server" do
      historian = mock("Historian")
      historian.should_receive(:send_data).
        with({
        key: "services.online_nodes",
        timestamp: 10_000,
        value: 2,
        tags: hash_including({
          component: "gateway",
          index: 1,
          job: "Test",
          service_type: 'unknown'
        })
      })
      varz = {
        "nodes" => {
          "node_0" => {
            "available_capacity" => 50,
            "plan" => "free"
          },
          "node_1" => {
            "available_capacity" => 50,
            "plan" => "free"
          }
        }
      }
      handler = Collector::ServiceGatewayHandler.new(historian, "Test", 1, 10000, varz)
      handler.process_online_nodes
    end
  end

end