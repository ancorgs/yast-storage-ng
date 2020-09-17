#!/usr/bin/env rspec

# Copyright (c) [2018-2020] SUSE LLC
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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/partition_modify_button"

describe Y2Partitioner::Widgets::PartitionModifyButton do
  subject(:button) { described_class.new(device: device) }

  before do
    devicegraph_stub("mixed_disks")
    allow(Y2Partitioner::Actions::EditBlkDevice).to receive(:new).and_return sequence
  end

  let(:device) { current_graph.partitions.first }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:sequence) { instance_double(Y2Partitioner::Actions::TransactionWizard, run: nil) }

  include_examples "CWM::PushButton"

  describe "#label" do
    it "returns a string with keyboard shortcut" do
      expect(button.label).to be_a String
      expect(button.label).to include "&"
    end
  end

  describe "#handle" do
    it "opens the workflow for editing the device" do
      expect(Y2Partitioner::Actions::EditBlkDevice).to receive(:new)
      button.handle
    end

    it "returns :redraw if the workflow returns :finish" do
      allow(sequence).to receive(:run).and_return :finish
      expect(button.handle).to eq :redraw
    end

    it "returns nil if the workflow does not return :finish" do
      allow(sequence).to receive(:run).and_return :back
      expect(button.handle).to be_nil
    end

    context "when the device is suddenly not available" do
      before do
        # Ensure the subject is initialized
        button
        # And then force removing the partition
        device.partition_table.remove_descendants
      end

      it "shows an error popup" do
        expect(Yast::Popup).to receive(:Error)
        button.handle
      end

      it "returns nil" do
        allow(Yast::Popup).to receive(:Error)
        expect(button.handle).to be_nil
      end
    end
  end
end
