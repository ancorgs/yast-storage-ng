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
require "y2partitioner/actions/delete_partition"
require "y2partitioner/actions/add_partition"

module Y2Partitioner
  module Widgets
    module Menus
      class Partitions < Device
        def label
          _("&Partition")
        end

        def id
          :m_partitions
        end

        def items
          items = []

          items << Item(Id(:menu_part_add), _("Add Partition..."))
          items << Item(Id(:menu_part_edit), _("Edit..."))
          items << Item(Id(:menu_part_resize), "Resize...")
          items << Item(Id(:menu_part_move), _("&Move..."))
          items << Item(Id(:menu_part_delete), _("&Delete"))
          items
        end

        def disabled_items
          return [] if device.nil? || device.is?(:partition)

          disabled = [:menu_part_edit, :menu_part_resize, :menu_part_move, :menu_part_delete]

          if !device.is?(:disk_device, :software_raid, :partition, :bcache)
            disabled << :menu_part_add
          end

          disabled
        end

        def action_for(event)
          case event
          when :menu_part_delete
            Actions::DeletePartition.new(device)
          when :menu_part_add
            dev = device.is?(:partition) ? device.partitionable : device
            Actions::AddPartition.new(dev)
          end
        end
      end
    end
  end
end
