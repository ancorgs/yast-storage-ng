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
        def label
          _("&Edit")
        end

        def items
          return [Item("---")] if device.nil?

          add_types = [
            Item("RAID"), Item("LVM Volume Group"), Item("Btrfs"), Item("Bcache")
          ]
          add_types += [
            Item("---"),
            Item(Id(:add_partition), "Partition"),
            Item(Id(:add_lv), "LVM Logical Volume"),
            Item(Id(:add_subvolume), "Btrfs Subvolume")
          ]

          items = []
          items << Menu(Id(:menu_add), _("Add"), add_types)
          items << Item(Id(:menu_edit), _("&Edit..."))
          items << Item(Id(:menu_delete), _("&Delete"))
          items << Item(Id(:menu_delete_all), _("&Delete All"))
          items << Item("---")
          items << Item(Id(:menu_resize), _("&Resize"))
          items << Item(Id(:menu_move), _("&Move"))
          items << Item(Id(:menu_devices), "Change Used Devices...")

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
          disabled << :add_partition unless device.is?(:software_raid, :disk_device, :partition)
          disabled << :add_lv unless device.is?(:lvm_vg, :lvm_lv)
          disabled << :add_subvolume unless subvolumes?

          disabled
        end

        private

        def subvolumes?
          return true if device.is?(:btrfs)

          device.is?(:blk_device) && device.formatted_as?(:btrfs)
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
