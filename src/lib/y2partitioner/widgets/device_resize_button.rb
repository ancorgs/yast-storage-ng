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
require "y2partitioner/actions/resize_blk_device"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Button for resizing a block device
    class DeviceResizeButton < DeviceButton
      def initialize(args = {})
        super(**args)
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: label for button for resizing a device
        _("Resize...")
      end

      private

      # @see DeviceButton#actions
      def actions
        return nil unless device_validation

        super
      end

      # Checks whether the device supports resizing
      #
      # @note An error popup is shown when the device does not support resizing.
      #
      # @return [Boolean] true if the device supports resizing; false otherwise.
      def device_validation
        return true if device.is?(:partition, :lvm_lv)

        Yast::Popup.Error(
          _("Hard disks, BIOS RAIDs and multipath\n"\
            "devices cannot be resized.")
        )
        false
      end

      # Returns the proper Actions class to perform the resize action
      #
      # @return [Object] action for resizing the device
      def actions_class
        Actions::ResizeBlkDevice
      end
    end
  end
end
