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
require "y2partitioner/execute_and_redraw"

module Y2Partitioner
  module Widgets
    module Menus
      class Base
        include Yast::I18n
        include Yast::UIShortcuts
        include ExecuteAndRedraw

        def disabled_items
          []
        end

        def id
          :menu
        end

        def handle(event)
          action = action_for(event)
          if action
            execute_and_redraw { action.run }
          else
            dialog = dialog_for(event)
            dialog&.run
            nil
          end
        end

        private

        def dialog_for(event)
          nil
        end

        def action_for(event)
          nil
        end
      end
    end
  end
end
