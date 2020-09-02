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
          _("Device")
        end

        def id
          :m_modify
        end

        def items
          return [] if device.nil?

          items = []

          items << Item(Id(:menu_edit), _("&Edit..."))
          items << Item(Id(:menu_resize), "Resize...")
          items << Item(Id(:menu_devices), "Change Used Devices...")
          items << Item(Id(:menu_move), _("&Move..."))
          items << Item(Id(:menu_delete), _("&Delete"))
          items << Item(Id(:menu_create_ptable), _("Create New Partition Table..."))
          items
        end

        def disabled_items
          return [] if device.nil?

          disabled = []
          disabled << :menu_edit if device.is?(:lvm_vg)
          disabled << :menu_resize unless device.is?(:partition, :lvm_lv)
          disabled << :menu_devices unless device.is?(:software_raid, :btrfs, :lvm_vg)
          disabled << :menu_move unless device.is?(:partition)
          disabled << :menu_delete if device.is?(:disk_device)
          disabled << :menu_create_ptable unless device.is?(:software_raid, :disk_device)

          disabled
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
          items << Item(Id(:menu_create_ptable), _("Create New Partition Table..."))
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
