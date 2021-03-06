#!/usr/bin/env rspec

# Copyright (c) [2017] SUSE LLC
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

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::MdRaids do
  before { devicegraph_stub(scenario) }

  subject { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "md_raid" }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:scenario) { "nested_md_raids" }

    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) } }
    let(:buttons_set) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceButtonsSet) } }

    let(:items) { column_values(table, 0) }

    it "shows a button to add a raid" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::MdAddButton) }
      expect(button).to_not be_nil
    end

    it "shows a set of buttons to manage the selected device" do
      expect(buttons_set).to_not be_nil
    end

    it "shows a table with the RAIDs and their partitions" do
      expect(table).to_not be_nil

      raids = current_graph.software_raids
      parts = raids.map(&:partitions).flatten.compact
      devices_name = raids.map(&:name) + parts.map(&:basename)
      items_name = column_values(table, 0)

      expect(items_name.sort).to eq(devices_name.sort)
    end

    it "associates the table and the set of buttons" do
      # Inspecting the value of #buttons_set may not be fully correct but is the
      # most straightforward and clear way of implementing this check
      expect(table.send(:buttons_set)).to eq buttons_set
    end

    context "when there are Software RAIDs" do
      let(:scenario) { "md_raid" }

      before do
        Y2Storage::Md.create(current_graph, "/dev/md1")
      end

      it "contains all Software RAIDs" do
        expect(items).to include(
          "/dev/md/md0",
          "/dev/md1"
        )
      end
    end

    context "when there are partitioned software RAIDs" do
      let(:scenario) { "nested_md_raids" }

      it "contains all software RAIDs and its partitions" do
        expect(items).to include("/dev/md0", "md0p1", "md0p2", "/dev/md1", "/dev/md2")
      end
    end

    context "when there is no Software RAID" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }

      it "does not contain any device" do
        expect(items).to be_empty
      end
    end
  end
end
