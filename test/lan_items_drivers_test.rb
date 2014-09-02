#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"

describe "LanItemsClass#ReadHw" do
  it "passes driver mapping from SCR to Items/udev/driver" do
    probe = [
      { "modalias" => "modalias2", "dev_name" => "eth0" },
      { "modalias" => "modalias1", "dev_name" => "eth1" }
    ]
    scr_mapping = {
      "modalias1" => ['ENV{MODALIAS}=="modalias1"',
                      'ENV{MODALIAS}="driver1"'],
      "modalias2" => ['ENV{MODALIAS}=="modalias2"',
                      'ENV{MODALIAS}="driver2"']
    }
    expect(Yast::LanItems).to receive(:ReadHardware).
      with("netcard").and_return probe
    allow(Yast::LanItems).to receive(:ReadUdevDriverRules)
    expect(Yast::SCR).to receive(:Read).
      with(Yast::Path.new(".udev_persistent.drivers")).and_return scr_mapping

    Yast::LanItems.ReadHw

    expect(Yast::LanItems.Items[0]["udev"]["driver"]).to eq "driver2"
    expect(Yast::LanItems.Items[1]["udev"]["driver"]).to eq "driver1"
  end
end

describe "LanItems#WriteUdevDriverRules" do
  it "passes driver mapping from Items/udev/driver to SCR" do
    items = {
      0 => {
        "hwinfo" => { "modalias" => "modaliasA" },
        "udev" => { "driver" => "driverA" }
      },
      1 => {
        "hwinfo" => { "modalias" => "modaliasA" },
        "udev" => { }
      },
      2 => {
        "hwinfo" => { "modalias" => "modaliasB" },
        "udev" => { "driver" => "driverB" }
      },
      3 => {
        "hwinfo" => { "modalias" => "modaliasC" },
        "udev" => { }
      },
    }
    Yast::LanItems.Items = items
    Yast::LanItems.driver_options = {}

    expected_scr = {
      "driverA" => ['ENV{MODALIAS}=="modaliasA"', 'ENV{MODALIAS}="driverA"'],
      "driverB" => ['ENV{MODALIAS}=="modaliasB"', 'ENV{MODALIAS}="driverB"']
    }
    expect(Yast::SCR).to receive(:Write).
      with(Yast::Path.new(".udev_persistent.drivers"),
           expected_scr)
    allow(Yast::SCR).to receive(:Write).with(Yast::Path.new(".modules"), nil)

    Yast::LanItems.WriteUdevDriverRules
  end
end
