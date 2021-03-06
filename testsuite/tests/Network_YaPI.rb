# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# **************************************************************************
module Yast
  class NetworkYaPIClient < Client
    def main
      Yast.import "Testsuite"
      Yast.import "Assert"

      @READ = {
        "target"    => {
          "size"   => 27,
          "string" => "laptop.suse.cz",
          "stat"   => { "exists" => true }
        },
        "probe"     => { "architecture" => "i386" },
        "sysconfig" => {
          "console" => { "CONSOLE_ENCODING" => "UTF-8" },
          "network" => {
            "config" => {
              "NETCONFIG_DNS_STATIC_SERVERS"    => "208.67.222.222 208.67.220.220",
              "NETCONFIG_DNS_STATIC_SEARCHLIST" => "suse.cz suse.de"
            },
            "dhcp"   => {
              "DHCLIENT_SET_HOSTNAME"   => "yes",
              "WRITE_HOSTNAME_TO_HOSTS" => "no"
            }
          }
        },
        "network"   => {
          "section" => {
            "eth0"    => {},
            "eth1"    => {},
            "eth2"    => {},
            "eth3"    => {},
            "eth4"    => {},
            "eth5"    => {},
            "eth5.23" => {}
          },
          "value"   => {
            "eth0"    => { "STARTMODE" => "manual", "BOOTPROTO" => "dhcp4" },
            "eth1"    => {
              "STARTMODE" => "auto",
              "BOOTPROTO" => "static",
              "IPADDR"    => "1.2.3.4/24",
              "MTU"       => "1234"
            },
            "eth2"    => {
              "STARTMODE" => "auto",
              "BOOTPROTO" => "static",
              "IPADDR"    => "1.2.3.5/24",
              "PREFIXLEN" => ""
            },
            "eth3"    => {
              "STARTMODE" => "auto",
              "BOOTPROTO" => "static",
              "IPADDR"    => "1.2.3.6",
              "PREFIXLEN" => "24"
            },
            "eth4"    => {
              "STARTMODE" => "auto",
              "BOOTPROTO" => "static",
              "IPADDR"    => "1.2.3.7",
              "NETMASK"   => "255.255.255.0"
            },
            "eth5"    => { "STARTMODE" => "auto", "BOOTPROTO" => "static" },
            "eth5.23" => {
              "STARTMODE"   => "auto",
              "BOOTPROTO"   => "static",
              "IPADDR"      => "1.2.3.8/24",
              "VLAN_ID"     => "23",
              "ETHERDEVICE" => "eth5"
            }
          }
        },
        "routes"    => [
          { "destination" => "default", "gateway" => "10.20.30.40" }
        ],
        "etc"       => { "sysctl_conf" => { "net.ipv4.ip_forward" => nil } }
      }

      @EXEC = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "laptop.suse.cz",
            "stderr" => ""
          },
          "bash"        => 0
        }
      }

      # mock /etc/sysconfig/network/ifroute-* files. It was not supported
      # at time of writing the testsuite and if not mocked causes false
      # positives
      ifroutes = {}
      @READ["network"]["section"].keys.each do |devname|
        ifroutes["ifroute-#{devname}"] = []
      end
      @READ.merge!(ifroutes)

      Testsuite.Init([@READ, {}, @EXEC], nil)

      Yast.import "YaPI::NETWORK"

      # Test Read
      Testsuite.Dump("Testing YaPI Read")

      Testsuite.Test(-> { YaPI::NETWORK.Read }, [@READ, {}, @EXEC], nil)

      # Test various writes. Writing is done as stateless in YaPI so it cannot be checked by rereading values.
      @write_succeeded = { "error" => "", "exit" => "0" }

      Testsuite.Dump("Testing YaPI Write")

      Assert.Equal(@write_succeeded, YaPI::NETWORK.Write({}))

      # test manipulation of the startmode
      Assert.Equal(
        @write_succeeded,
        YaPI::NETWORK.Write(
          "interface" => {
            "eth0" => { "bootproto" => "dhcp4", "STARTMODE" => "auto" }
          }
        )
      )

      # test correct default route
      Assert.Equal(
        @write_succeeded,
        YaPI::NETWORK.Write(
          "route" => { "default" => { "via" => "10.20.30.40" } }
        )
      )

      # test incorrect default route (invalid gw IP)
      @write_ip_fails = {
        "error" => "A valid IP address consists of four integers\nin the range 0-255 separated by dots.",
        "exit"  => "-1"
      }

      Assert.Equal(
        @write_ip_fails,
        YaPI::NETWORK.Write(
          "route" => { "default" => { "via" => "10.20.30" } }
        )
      )

      # test setting the network prefix length for an interface that was previously configured via netmask
      Assert.Equal(
        @write_succeeded,
        YaPI::NETWORK.Write(
          "interface" => {
            "eth3" => { "bootproto" => "static", "ipaddr" => "1.2.3.7/24" }
          }
        )
      )

      # test vlan_id change
      Assert.Equal(
        @write_succeeded,
        YaPI::NETWORK.Write(
          "interface" => {
            "eth5.23" => {
              "bootproto"        => "static",
              "ipaddr"           => "1.2.3.8/24",
              "vlan_etherdevice" => "eth5",
              "vlan_id"          => "42"
            }
          }
        )
      )

      nil
    end
  end
end

Yast::NetworkYaPIClient.new.main
