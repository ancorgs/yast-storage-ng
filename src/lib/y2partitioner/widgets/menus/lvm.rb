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
      class Lvm < Device
        def label
          _("LVM")
        end

        def id
          :m_lvm
        end

        def items
          items = []

          items << Item(Id(:menu_vg_add), _("Add Volume Group..."))
          items << Item(Id(:menu_pvs), _("View Physical Volumes"))
          items << Item(Id(:menu_lvs), _("View Logical Volumes"))
          items << Item(Id(:menu_vg_delete), _("Delete Volume Group"))
          items << Item("---")
          items << Item(Id(:menu_lv_add), _("Add Logical Volume..."))
          items << Item(Id(:menu_lv_edit), "Edit Logical Volume...")
          items << Item(Id(:menu_lv_resize), "Resize Logical Volume...")
          items << Item(Id(:menu_lv_delete), _("Delete Logical Volume"))
          items
        end

        def disabled_items
          return [] unless device

          return [] if device.is?(:lvm_lv)

          if device.is?(:lvm_vg)
            [:menu_lv_edit, :menu_lv_resize, :menu_lv_delete]
          else
            [
              :menu_pvs, :menu_lvs, :menu_vg_delete,
              :menu_lv_add, :menu_lv_edit, :menu_lv_resize, :menu_lv_delete
            ]
          end
        end
      end
    end
  end
end
