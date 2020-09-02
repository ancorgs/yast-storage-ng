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
      class Lvs < Device
        def label
          _("&Logical Volumes")
        end

        def items
          items = []

          items << Item(Id(:menu_add_part), _("Add Logical Volume..."))
          items << Item(Id(:menu_edit_part), _("&Edit Logical Volumes"))
          items << Item(Id(:menu_delete), _("&Delete All Logical Volumes"))
          items
        end
      end
    end
  end
end
