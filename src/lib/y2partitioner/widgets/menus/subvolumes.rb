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
      class Subvolumes < Device
        def label
          _("&Btrfs")
        end

        def id
          :m_btrfs
        end

        def items
          items = []

          items << Item(Id(:menu_btrfs_add), _("Add Btrfs"))
          items << Item(Id(:menu_btrfs_edit), _("Edit Btrfs..."))
          items << Item(Id(:menu_btrfs_devices), _("Used Devices"))
          items << Item(Id(:menu_btrfs_delete), _("Delete Btrfs"))
          items << Item(Id(:menu_btrfs_subvols), _("View Subvolumes"))
          items << Item("---")
          items << Item(Id(:menu_subvol_add), _("Add Subvolume..."))
          items << Item(Id(:menu_subvol_edit), _("&Edit Subvolume"))
          items << Item(Id(:menu_subvol_delete), _("&Delete Subvolume"))
          items
        end

        def disabled_items
          return [] if device.nil?

          if device.is?(:btrfs)
            [:menu_subvol_edit, :menu_subvol_delete]
          elsif device.is?(:blk_device) && device.formatted_as?(:btrfs)
            [ :menu_btrfs_devices, :menu_btrfs_delete, :menu_subvol_edit, :menu_subvol_delete ]
          else
            [
              :menu_btrfs_edit, :menu_btrfs_devices, :menu_btrfs_delete, :menu_btrfs_subvols,
              :menu_subvol_add, :menu_subvol_edit, :menu_subvol_delete
            ]
          end
        end
      end
    end
  end
end
