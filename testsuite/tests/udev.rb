# encoding: utf-8

#***************************************************************************
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
#**************************************************************************
module Yast
  class UdevClient < Client
    def main
      Yast.import "UI"
      Yast.import "Assert"
      Yast.import "Testsuite"

      @READ = { "probe" => { "architecture" => "i386" } }

      @EXEC = {
        "target" => {
          "bash_output" => { "stdout" => "", "stderr" => "", "exit" => 0 }
        }
      }

      Testsuite.Init([@READ, {}, @EXEC], nil)

      Yast.import "LanItems"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/lan/udev.rb"

      # valid
      Assert.Equal(true, ValidNicName("eth0"))
      Assert.Equal(true, ValidNicName("eth_0"))
      Assert.Equal(true, ValidNicName("eth-0"))
      Assert.Equal(true, ValidNicName("eth.0"))
      Assert.Equal(true, ValidNicName("eth:0"))
      # invalid: too long
      Assert.Equal(false, ValidNicName("0123456789012345"))
      # invalid: wrong char
      Assert.Equal(false, ValidNicName("eth0?"))

      # create Items hash, it's easier to create by hand than use LanItems::Read
      # due to embedded ReadHardware and co (too many faked inputs which are not
      # in fact needed).
      Ops.set(
        LanItems.Items,
        0,
        {
          "ifcfg" => "eth1",
          "udev"  => {
            "net"    => [
              "KERNELS=\"invalid\"",
              "KERNEL=\"eth*\"",
              "NAME=\"eth1\""
            ],
            "driver" => nil
          }
        }
      )

      LanItems.FindAndSelect("eth1")

      @new_rules = LanItems.SetItemUdev("NAME", "nic_name")
      Assert.Equal(true, Builtins.contains(@new_rules, "NAME=\"nic_name\""))

      @new_rules = LanItems.SetItemUdev("KERNELS", "0000:00:19.x")
      Assert.Equal(
        true,
        Builtins.contains(@new_rules, "KERNELS==\"0000:00:19.x\"")
      )

      @new_rules = LanItems.ReplaceItemUdev(
        "KERNELS",
        "ATTR{address}",
        "xx:01:02:03:04:05"
      )
      Assert.Equal(
        true,
        Builtins.contains(@new_rules, "ATTR{address}==\"xx:01:02:03:04:05\"")
      )

      @rule = Ops.get_list(LanItems.Items, [0, "udev", "net"], [])
      @new_rules = RemoveKeyFromUdevRule(@rule, "KERNEL")
      Assert.Equal(false, Builtins.contains(@new_rules, "KERNEL=\"eth*\""))

      nil
    end
  end
end

Yast::UdevClient.new.main
