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

require "yast"
require "cwm"
require "y2partitioner/widgets/visual_device_graph"

Yast.import "UI"

module Y2Partitioner
  module Widgets
    class DeviceGraphWithButtons < CWM::CustomWidget
      # Constructor
      def initialize(device_graph, pager)
        textdomain "storage"

        @device_graph = device_graph
        @pager = pager
      end

      # @macro seeCustomWidget
      def contents
        VBox(
          VisualDeviceGraph.new(device_graph, pager),
          Left(
            HBox(
              SaveButton.new(device_graph, :xml),
              SaveButton.new(device_graph, :gv)
            )
          )
        )
      end

    private

      attr_reader :device_graph
      attr_reader :pager

      class SaveButton < CWM::PushButton
        # Configuration of the Graphviz export (information in the vertices)
        LABEL_FLAGS = Storage::GraphvizFlags_NAME

        # Configuration of the Graphviz export (tooltips)
        TOOLTIP_FLAGS = Storage::GraphvizFlags_PRETTY_CLASSNAME |
          Storage::GraphvizFlags_SIZE | Storage::GraphvizFlags_SID |
          Storage::GraphvizFlags_ACTIVE | Storage::GraphvizFlags_IN_ETC

        private_constant :LABEL_FLAGS, :TOOLTIP_FLAGS

        def initialize(device_graph, format)
          textdomain "storage"

          @device_graph = device_graph
          @format = format
          @widget_id = "#{widget_id}_#{device_graph.object_id}_#{format}"
        end

        # @macro seeAbstractWidget
        def label
          if xml?
            _("Save as XML...")
          else
            _("Save as Graphviz...")
          end
        end

        def handle
          filename = Yast::UI.AskForSaveFileName("/tmp/yast.#{format}", "*.#{format}", "Save as...")
          return if filename.nil?
          return if save(filename)
          Yast::Popup.Error(_("Saving graph file failed."))
        end

      private

        attr_reader :device_graph
        attr_reader :format

        def xml?
          format == :xml
        end

        def save(filename)
          if xml?
            device_graph.save(filename)
          else
            device_graph.write_graphviz(filename, LABEL_FLAGS, TOOLTIP_FLAGS)
          end
          true
        rescue Storage::Exception
          false
        end
      end
    end
  end
end
