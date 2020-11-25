#!/usr/bin/env rspec

# Copyright (c) [2019-2020] SUSE LLC
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

require "y2partitioner/actions/edit_btrfs"

describe Y2Partitioner::Actions::EditBtrfs do
  subject { described_class.new(filesystem) }

  before do
    devicegraph_stub(scenario)
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { device_graph.find_by_name(device_name) }

  let(:filesystem) { device.filesystem }

  describe "#run" do
    before do
      allow(Y2Partitioner::Dialogs::BtrfsOptions).to receive(:new).and_return(dialog)

      allow(dialog).to receive(:run).and_return(dialog_result)

      allow(Y2Partitioner::Actions::Controllers::Filesystem).to receive(:new)
        .and_return(fs_controller)

      allow(fs_controller).to receive(:finish).and_return(:finish)
    end

    let(:dialog) { instance_double(Y2Partitioner::Dialogs::BtrfsOptions) }

    let(:dialog_result) { nil }

    let(:scenario) { "mixed_disks" }

    let(:device_name) { "/dev/sdb2" }

    let(:controller_class) { Y2Partitioner::Actions::Controllers::Filesystem }

    let(:fs_controller) { instance_double(controller_class) }

    it "shows the dialog for editing a BTRFS filesystem" do
      expect(dialog).to receive(:run)

      subject.run
    end

    it "includes the device base name in the title passed to the controller" do
      expect(controller_class).to receive(:new).with(filesystem, /sdb2/).and_return(fs_controller)

      subject.run
    end

    context "and the dialog is not accepted" do
      let(:dialog_result) { :abort }

      it "does not perform the final steps over the filesystem" do
        expect(fs_controller).to_not receive(:finish)

        subject.run
      end

      it "returns the result of the dialog" do
        expect(subject.run).to eq(:abort)
      end
    end

    context "and the dialog is accepted" do
      let(:dialog_result) { :next }

      it "performs the final steps over the filesystem" do
        expect(fs_controller).to receive(:finish)

        subject.run
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end
    end
  end
end
