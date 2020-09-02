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
      class Bcache < Device
        def label
          _("Bcache")
        end

        def id
          :m_bcache
        end

        def items
          items = []

          items << Item(Id(:menu_bcache_add), _("Add Bcache..."))
          items << Item(Id(:menu_bcache_edit), _("Edit..."))
          items << Item(Id(:menu_bcache_devices), _("Change Caching"))
          items << Item(Id(:menu_bcache_delete), _("Delete"))
          items << Item("---")
          items << Item(Id(:menu_bcache_partitions), _("Partitions"))
          items << Item(Id(:menu_bcache_new_ptable), _("&Create New Partition Table..."))
          items
        end

        def disabled_items
          return [] unless device

          return [] if device.is?(:bcache)

          return [] if device.is?(:partition) && device.partitionable.is?(:bcache)

          [
            :menu_bcache_edit, :menu_bcache_devices, :menu_bcache_delete,
            :menu_bcache_partitions, :menu_bcache_new_ptable
          ]
        end
      end
    end
  end
end
