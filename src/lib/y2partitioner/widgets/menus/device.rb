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
require "y2partitioner/widgets/menus/base"

module Y2Partitioner
  module Widgets
    module Menus
      class Device < Base
        def initialize(device)
          @device_sid = device.sid unless device.nil?
        end

        private

        # @return [Integer] device sid
        attr_reader :device_sid

        # Current devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def working_graph
          DeviceGraphs.instance.current
        end

        # Device on which to act
        #
        # @return [Y2Storage::Device]
        def device
          return nil unless device_sid

          working_graph.find_device(device_sid)
        end
      end
    end
  end
end
