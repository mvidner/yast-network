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
# Author: Michal Zugec

# this file is for development only
# running this file starts the internet test dialogs
module Yast
  class TestNetTestClient < Client
    def main
      # include "../dialogs.ycp";
      Yast.import "Wizard"

      Wizard.CreateDialog
      if WFM.CallFunction("inst_ask_net_test") == :next
        WFM.CallFunction("inst_do_net_test")
      end
      Wizard.CloseDialog

      nil
    end
  end
end

Yast::TestNetTestClient.new.main
