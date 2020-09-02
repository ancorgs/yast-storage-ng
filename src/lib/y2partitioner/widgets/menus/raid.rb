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
require "y2partitioner/actions/add_md"
require "y2partitioner/actions/delete_md"
require "y2partitioner/actions/go_to_device_tab"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Widgets
    module Menus
      class Raid < Device
        def label
          _("RAID")
        end

        def id
          :m_raid
        end

        def items
          items = []

          items << Item(Id(:menu_raid_add), _("Add RAID..."))
          items << Item(Id(:menu_raid_edit), _("Edit..."))
          items << Item(Id(:menu_raid_devices), _("Used Devices"))
          items << Item(Id(:menu_raid_delete), _("Delete"))
          items << Item("---")
          items << Item(Id(:menu_raid_partitions), _("View Partitions"))
          items << Item(Id(:menu_raid_new_ptable), _("&Create New Partition Table..."))
          items
        end

        def disabled_items
          return [] unless device

          return [] if device.is?(:software_raid)

          return [] if device.is?(:partition) && device.partitionable.is?(:software_raid)

          [
            :menu_raid_edit, :menu_raid_devices, :menu_raid_delete,
            :menu_raid_partitions, :menu_raid_new_ptable
          ]
        end

        def action_for(event)
          dev = device.is?(:partition) ? device.partitionable : device
          case event
          when :menu_raid_delete
            Actions::DeleteMd.new(device)
          when :menu_raid_add
            Actions::AddMd.new
          when :menu_raid_partitions
            pager = UIState.instance.overview_tree_pager
            Actions::GoToDeviceTab.new(dev, pager, _("&Partitions"))
          end
        end
      end
    end
  end
end
