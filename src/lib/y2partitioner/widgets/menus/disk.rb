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
      class Disk < Device
        def label
          _("Hard Disk")
        end

        def id
          :m_disk
        end

        def items
          items = []

          items << Item(Id(:menu_disk_edit), _("Edit..."))
          items << Item("---")
          items << Item(Id(:menu_disk_partitions), _("View Partitions"))
          items << Item(Id(:menu_disk_new_ptable), _("&Create New Partition Table..."))
          items << Item(Id(:menu_disk_clone_ptable), _("Clone Partitions to Another Device..."))
          items
        end

        def disabled_items
          if enabled?
            []
          else
            [:menu_disk_edit, :menu_disk_partitions, :menu_disk_new_ptable, :menu_disk_clone_ptable]
          end
        end

        protected

        def action_for(event)
          case event
          when :menu_disk_partitions
            dev = device.is?(:partition) ? device.partitionable : device
            pager = UIState.instance.overview_tree_pager
            Actions::GoToDeviceTab.new(dev, pager, _("&Partitions"))
          end
        end

        def enabled?
          return false if device.nil?

          return true if device.is?(:disk_device)

          device.is?(:partition) && device.partitionable.is?(:disk_device)
        end
      end
    end
  end
end
