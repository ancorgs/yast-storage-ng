# Copyright (c) [2020] SUSE LLC
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
require "y2partitioner/widgets/menus/device"
require "y2partitioner/dialogs/summary_popup"
require "y2partitioner/dialogs/device_graph"

module Y2Partitioner
  module Widgets
    module Menus
      class View < Device
        def label
          _("&View")
        end

        def items
          items = []
          items << Item(Id(:view_used_devices), "Used Devices")
          items << Item(Id(:view_partitions), "Partitions")
          items << Item(Id(:view_lvs), "Logical Volumes")
          items << Item(Id(:view_subvolumes), "Btrfs Subvolumes")
          items << Item("---")
          # TRANSLATORS: Menu items in the partitioner
          items << Item(Id(:device_graphs), _("Device &Graphs...")) if Dialogs::DeviceGraph.supported?
          items << Item(Id(:installation_summary), _("Installation &Summary..."))
          items
        end

        def disabled_items
          return [] if device.nil?

          disabled = []
          disabled << :view_used_devices unless device.is?(:software_raid, :btrfs)
          disabled << :view_partitions unless device.is?(:software_raid, :disk_device)
          disabled << :view_lvs unless device.is?(:lvm_vg)
          disabled << :view_subvolumes unless subvolumes?
          disabled
        end

        private

        def subvolumes?
          return true if device.is?(:btrfs)

          device.is?(:blk_device) && device.formatted_as?(:btrfs)
        end

        def dialog_for(event)
          case event
          when :device_graphs
            Dialogs::DeviceGraph.new
          when :installation_summary
            Dialogs::SummaryPopup.new
          end
        end
      end
    end
  end
end
