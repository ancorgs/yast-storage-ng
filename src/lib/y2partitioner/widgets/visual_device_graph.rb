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
require "y2storage"
require "tempfile"

module Y2Partitioner
  module Widgets
    class VisualDeviceGraph < CWM::CustomWidget
      # Configuration of the Graphviz export (information in the vertices)
      LABEL_FLAGS = Storage::GraphvizFlags_NAME

      # Configuration of the Graphviz export (tooltips)
      TOOLTIP_FLAGS = Storage::GraphvizFlags_PRETTY_CLASSNAME |
        Storage::GraphvizFlags_SIZE | Storage::GraphvizFlags_NAME

      private_constant :LABEL_FLAGS, :TOOLTIP_FLAGS

      # Constructor
      def initialize(device_graph, pager)
        textdomain "storage"

        @device_graph = device_graph
        @pager = pager
        @widget_id = "#{widget_id}_#{device_graph.object_id}"
      end

      # @macro seeCustomWidget
      def contents
        ReplacePoint(replace_point_id, Empty(graph_id))
      end

      def init
        tmp = Tempfile.new("graph.gv")
        device_graph.write_graphviz(tmp.path, LABEL_FLAGS, TOOLTIP_FLAGS)
        content = ReplacePoint(
          replace_point_id,
          Yast::Term.new(:Graph, graph_id, Opt(:notify), tmp.path, "dot")
        )
        Yast::UI.ReplaceWidget(replace_point_id, content)
      ensure
        tmp.close!
      end

      def handle(event)
        node = Yast::UI.QueryWidget(graph_id, :Item)
        device = device_graph.find_device(node.to_i)
        return nil unless device

        page = find_target_page(device)
        return nil unless page

        pager.switch_page(page)
      end

    private

      attr_reader :device_graph
      attr_reader :pager

      def replace_point_id
        Id(:"#{widget_id}_content")
      end

      def graph_id
        Id(:"#{widget_id}_graph")
      end

      def find_target_page(device)
        page = pager.device_page(device)
        return page if page

        parents = device.parents
        return nil if parents.empty?

        parents.each do |parent|
          page = find_target_page(parent)
          break if page
        end
        page
      end
    end
  end
end
