# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2partitioner/widgets/device_button"
require "y2partitioner/actions/add_lvm_lv"

module Y2Partitioner
  module Widgets
    # Button for opening the workflow to add a logical volume to a volume group
    class LvmLvAddButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to add a logical volume
        _("Add...")
      end

    private

      # Returns the proper Actions class to perform the action for adding a
      # logical volume
      #
      # @see DeviceButton#actions
      # @see Actions::AddLvmLv
      def actions_class
        Actions::AddLvmLv
      end
    end
  end
end
