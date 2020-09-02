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

module Y2Partitioner
  module Widgets
    module Menus
      class Add < Device
        def label
          _("&Add")
        end

        def items
          items = [
            Item(Id(:menu_add_raid), _("RAID")),
            Item(Id(:menu_add_vg), _("LVM Volume Group")),
            Item(Id(:menu_add_btrfs), _("Btrfs")),
            Item(Id(:menu_add_bcache), _("Bcache")),
          ]
          if device.is?(:disk_device, :software_raid, :partition)
            items << Item("---")
            items << Item(Id(:menu_add_partition), _("Partition"))
            if subvolumes?
              items << Item(Id(:menu_add_subvolume), _("Btrfs Subvolume"))
            end
          elsif device.is?(:lvm_vg, :lvm_lv)
            items << Item("---")
            items << Item(Id(:menu_add_lv), _("Logical Volume"))
            if subvolumes?
              items << Item(Id(:menu_add_subvolume), _("Btrfs Subvolume"))
            end
          elsif device.is?(:btrfs)
            items << Item("---")
            items << Item(Id(:menu_add_subvolume), _("Btrfs Subvolume"))
          end

          items
        end

        def subvolumes?
          device.is?(:blk_device) && device.formatted_as?(:btrfs)
        end
      end
    end
  end
end
