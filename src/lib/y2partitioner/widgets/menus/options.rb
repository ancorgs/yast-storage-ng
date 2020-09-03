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
      class Options < Device
        def label
          _("Actions")
        end

        def items
          return [Item("---")] if device.nil?

          items = []
          items << Item(Id(:menu_create_ptable), _("Create New Partition Table..."))
          items << Item(Id(:menu_clone_ptable), _("Clone Partitions to Another Device..."))

          items
        end

        def disabled_items
          return [] if device.nil?

          disabled = []
          disabled << :menu_create_ptable unless device.is?(:software_raid, :disk_device)
          disabled << :menu_create_ptable unless device.is?(:disk_device)

          disabled
        end
      end
    end
  end
end
