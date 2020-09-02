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
require "y2partitioner/actions/delete_md"
require "y2partitioner/actions/delete_partition"

module Y2Partitioner
  module Widgets
    module Menus
      class Modify < Device
        SUPPORTED_TYPES = [
          :partition, :software_raid, :lvm_vg, :lvm_lv, :disk_device, :btrfs
        ]
        private_constant :SUPPORTED_TYPES

        def label
          _("&Modify")
        end

        def items
          return [] if device.nil?

          SUPPORTED_TYPES.each do |type|
            return send(:"#{type}_items") if device.is?(type)
          end

          # Returns no items if the device is not supported
          []
        end

        private

        def subvolumes?
          device.is?(:blk_device) && device.formatted_as?(:btrfs)
        end

        def partition_items
          items = []

          items << Item(Id(:menu_edit), _("&Edit Partition..."))
          items << Item(Id(:menu_resize), "Resize Partition...")
          items << Item(Id(:menu_move), _("&Move Partition..."))
          items << Item(Id(:menu_delete), _("&Delete Partition"))
          items
        end

        def lvm_lv_items
          items = []

          items << Item(Id(:menu_edit), _("&Edit Logical Volume..."))
          items << Item(Id(:menu_resize), "Resize Logical Volume...")
          items << Item(Id(:menu_delete), _("&Delete Logical Volume"))
          items
        end

        def software_raid_items
          items = []

          items << Item(Id(:menu_edit), _("&Edit RAID..."))
          items << Item(Id(:menu_pvs), "Change RAID Devices...")
          items << Item(Id(:menu_delete), _("&Delete RAID"))
          items << Item(Id(:menu_create_ptable), _("&Create New Partition Table..."))
          items
        end
        

        def disk_device_items
          items = []

          items << Item(Id(:menu_edit), _("&Edit Disk..."))
          items << Item(Id(:menu_create_ptable), _("&Create New Partition Table..."))
          items
        end

        def lvm_vg_items
          items = []
          items << Item(Id(:menu_pvs), "Change Physical Volumes...")
          items << Item(Id(:menu_delete), "Delete Volume Group")
          items
        end

        def lvm_btrfs
          items = []

          items << Item(Id(:menu_edit), _("&Edit Btrfs..."))
          items << Item(Id(:menu_pvs), "Change Btrfs Devices...")
          items << Item(Id(:menu_delete), _("&Delete Btrfs"))
          items
        end

        def action_for(event)
          case event
          when :menu_delete
            if device.is?(:partition)
              Actions::DeletePartition.new(device)
            elsif device.is?(:md)
              Actions::DeleteMd.new(device)
            end
          end
        end
      end
    end
  end
end
