# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require "y2partitioner/icons"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/device_graph_with_buttons"

module Y2Partitioner
  module Widgets
    module Pages
      class DeviceGraph < CWM::Page
        include Yast::I18n

        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(pager)
          textdomain "storage"

          @pager = pager
        end

        # @macro seeAbstractWidget
        def label
          _("Device Graph")
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          icon = Icons.small_icon(Icons::GRAPH)
          @tabs = Tabs.new(current_tab, system_tab)
          @contents = VBox(
            Left(
              HBox(
                Image(icon, ""),
                # TRANSLATORS: Heading for the expert partitioner page
                Heading(_("Device Graphs"))
              )
            ),
            @tabs
          )
        end

        def init
          # Start always in the first tab
          @tabs.switch_page(@tabs.initial_page)
        end

      private

        # @return [CWM::TreePager]
        attr_reader :pager

        def current_tab
          DeviceGraphTab.new(
            _("Planned Devices"),
            DeviceGraphs.instance.current,
            _(
              "Final result that will be committed to the system.\n" \
              "This graph is updated on every user action."
            ),
            pager
          )
        end

        def system_tab
          DeviceGraphTab.new(
            _("Current System Devices"),
            DeviceGraphs.instance.system,
            _(
              "Layout of the current system, before any of the scheduled changes.\n" \
              "This graph is created at startup."
            ),
            pager
          )
        end

        class DeviceGraphTab < CWM::Tab
          attr_reader :label

          def initialize(label, device_graph, description, pager)
            @label = label
            @device_graph = device_graph
            @widget_id = "#{widget_id}_#{device_graph.object_id}"
            @description = description
            @pager = pager
          end

          def contents
            return @contents if @contents

            @contents = VBox(
              Left(Label(description)),
              DeviceGraphWithButtons.new(device_graph, pager)
            )
          end

        private

          attr_reader :description
          attr_reader :device_graph
          attr_reader :pager
        end
      end
    end
  end
end
