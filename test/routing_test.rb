#!/usr/bin/env rspec

# The test is currently not started automatically because of missing rspec.rpm
# in OpenSUSE:Factory

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

include Yast
include UIShortcuts

# This is needed bcs of Yast.includ(ed) dialog in UI tests
include I18n

Yast.import "Routing"

describe Routing do

  SYSCTL_IPV4_PATH = path( RoutingClass::SYSCTL_IPV4_PATH)
  SYSCTL_IPV6_PATH = path( RoutingClass::SYSCTL_IPV6_PATH)

  # This describes how Routing should behave independently on the way how its
  # internal state was reached
  shared_examples_for "routing setter" do

    before( :each) do
      @value4 = forward_v4 ? "1" : "0"
      @value6 = forward_v6 ? "1" : "0"

      SCR.stub( :Execute) { nil }
    end

    def fw_independent_write_expects
      expect( SCR)
        .to receive( :Execute)
        .with( 
          path(".target.bash"),
          "echo #{@value4} > /proc/sys/net/ipv4/ip_forward"
        )
      expect( SCR)
        .to receive( :Execute)
        .with( 
          path(".target.bash"),
          "echo #{@value6} > /proc/sys/net/ipv6/conf/all/forwarding",
        )
    end

    context "when Firewall is enabled" do

      before( :each) do
        SuSEFirewall.stub( :IsEnabled) { true }
      end

      describe "#WriteIPForwarding" do
        it "Delegates setup to SuSEFirewall2" do
          expect(SuSEFirewall)
            .to receive(:SetSupportRoute)
            .with(forward_v4)

          fw_independent_write_expects

          expect( Routing.WriteIPForwarding).to be_equal nil
        end
      end
    end

    context "when Firewall is disabled" do

      before( :each) do
        SuSEFirewall.stub( :IsEnabled) { false }
      end

      describe "#WriteIPForwarding" do
        it "Updates IPv4 and IPv6 forwarding in sysctl.conf" do
          SCR.stub( :Write) { nil }
          expect( SCR)
            .to receive( :Write)
            .with( SYSCTL_IPV4_PATH, @value4)
          expect( SCR)
            .to receive( :Write)
            .with( SYSCTL_IPV6_PATH, @value6)

          fw_independent_write_expects

          expect( Routing.WriteIPForwarding).to be_equal nil
        end
      end
    end
  end

  # Various contexts which mocks different setup sources follows.
  #
  # 1) Test if it behaves correctly when data were obtained from dialog
  #
  context "when set up via dialog" do

    CONFIGS_UI = [
      { ip_forward_v4: false, ip_forward_v6: false },
      { ip_forward_v4: false, ip_forward_v6: true },
      { ip_forward_v4: true, ip_forward_v6: true },
      { ip_forward_v4: true, ip_forward_v6: false }
    ]

    CONFIGS_UI.each do |config|

      ipv4 = config[ :ip_forward_v4]
      ipv6 = config[ :ip_forward_v6]

      context "when user sets IPv4 Forwarding to #{ipv4} and IPv6 to #{ipv6}" do
        before(:each) do

          Wizard.as_null_object
          Label.as_null_object
          Netmask.as_null_object
          Popup.as_null_object

          Yast.import "UI"
          UI.stub( :QueryWidget) { "" }
          expect( UI)
            .to receive( :QueryWidget)
            .with( Id(:forward_v4), :Value) { ipv4 }
          expect( UI)
            .to receive( :QueryWidget)
            .with( Id(:forward_v6), :Value) { ipv6 }
          expect( UI)
            .to receive( :WaitForEvent) { {"ID" => :ok}  }

          Yast.include self, "network/services/routing.rb"
          RoutingMainDialog()
        end

        it_should_behave_like "routing setter" do
          let( :forward_v4) { ipv4 }
          let( :forward_v6) { ipv6 }
        end
      end
    end
  end

  #
  # 2) Test if it behaves correctly when data were imported by AutoYast
  #
  context "when working with AutoYast profile" do

    # list of inputs provided by AutoYast
    # keys has to be strings
    AY_CONFIGS = [
      { "ip_forward" => false },
      { "ip_forward" => true }
    ]

    AY_CONFIGS.each do |config|

      ipfw = config[ "ip_forward"]

      context "when ip_forward is #{ipfw} in AutoYast profile" do
        before(:all) do
          Routing.Import(config)
        end

        it_should_behave_like "routing setter" do
          # separate setup for IPv6 forwarding is not implemented in AutoYast 
          # yet, so it fallbacks to old behavior
          let( :forward_v4) { ipfw }
          let( :forward_v6) { ipfw }
        end
      end
    end

    describe "#Import" do

      it "Returns true for non nil settings" do
        expect( Routing.Import({})).to be_true
      end

      it "Returns true for nil settings" do
        expect( Routing.Import(nil)).to be_true
      end
    end

    describe "#Export" do

      # An array of hashes. Each hash should contain keys input: and keys: which
      # describes test this way
      # - input: a hash as provided by AutoYast. Interesting keys are "routes"
      #          and "ip_forward"
      # - keys: array of keys which are expected in obtained hash when above 
      #         imported data are exported consequently
      AY_TESTS = [
        {
          input: {},
          keys: ["ip_forward"]
        },
        {
          input: { "routes" => [{ "1" => "r1" }, { "2" => "r2" }] },
          keys: ["ip_forward", "routes"]
        },
        {
          input: { "ip_forward" => true, "routes" => [{ "1" => "r1" }, { "2" => "r2" }] },
          keys: ["ip_forward", "routes"]
        }
      ]

      AY_TESTS.each do |ay_test|
        it "Returns hash with proper values" do
          Routing.Import( ay_test[ :input])
          expect( Routing.Export).to include( *ay_test[ :keys])
        end
      end
    end
  end

  #
  # 3) Test if it behaves correctly when data were read from system
  #
  context "when working with configuration present in system" do

    CONFIGS_OS = [
      { ip_forward_v4: "0", ip_forward_v6: "0" },
      { ip_forward_v4: "0", ip_forward_v6: "1" },
      { ip_forward_v4: "1", ip_forward_v6: "1" },
      { ip_forward_v4: "1", ip_forward_v6: "0" },
    ]

    MOCKED_ROUTES = [{ "1" => "r1" }, { "2" => "r2" }]

    CONFIGS_OS.each do |config|
      
      ipv4 = config[ :ip_forward_v4]
      ipv6 = config[ :ip_forward_v6]

      context "when ipv4.ip_forward=#{ipv4} and .ipv6.conf.all.forwarding=#{ipv6}" do
        before(:each) do
          SCR.stub(:Read) { nil }
          expect(SCR)
            .to receive(:Read)
            .with(path(".routes")) { MOCKED_ROUTES }
          expect( SCR)
            .to receive( :Read)
            .with(path(".target.size"), "#{RoutingClass::ROUTES_FILE}") { 1 }
          expect( SCR)
            .to receive( :Read)
            .with(SYSCTL_IPV4_PATH) { ipv4 }
          expect( SCR)
            .to receive( :Read)
            .with(SYSCTL_IPV6_PATH) { ipv6 }

          Routing.Read
        end

        it_should_behave_like "routing setter" do
          let( :forward_v4) { ipv4 == "1" }
          let( :forward_v6) { ipv6 == "1" }
        end

        describe "#Read" do
          
          it "loads configuration from system" do
            NetworkInterfaces.as_null_object

            expect( Routing.Read).to be_true  
          end
        end
      end
    end
  end
end
