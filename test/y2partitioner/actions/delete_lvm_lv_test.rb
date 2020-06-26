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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/actions/delete_lvm_lv"

describe Y2Partitioner::Actions::DeleteLvmLv do
  before do
    devicegraph_stub(scenario)
  end
  let(:scenario) { "lvm-two-vgs.yml" }

  subject { described_class.new(device) }

  let(:device) { Y2Storage::BlkDevice.find_by_name(current_graph, device_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:vg_name) { "vg1" }

  describe "#run" do
    before do
      vg = Y2Storage::LvmVg.find_by_vg_name(current_graph, vg_name)
      create_thin_provisioning(vg)

      allow(Yast2::Popup).to receive(:show).and_return(accept)
      allow(subject).to receive(:confirm_recursive_delete).and_return(accept == :yes)
    end

    let(:accept) { nil }

    context "when the logical volume is a normal one without snapshots" do
      let(:device_name) { "/dev/vg1/lv1" }

      it "shows a confirmation message with the device name" do
        expect(Yast2::Popup).to receive(:show) do |string, _anything|
          expect(string).to include(device_name)
        end
        subject.run
      end
    end

    context "when the logical volume is a used thin pool" do
      let(:device_name) { "/dev/vg1/pool1" }

      it "shows a detailed confirmation message including all the thin volumes over the pool" do
        expect(subject).to receive(:confirm_recursive_delete)
          .with(device, anything, anything, /pool1/)
          .and_call_original

        subject.run
      end
    end

    context "when the logical volume is a normal one with snapshots" do
      let(:scenario) { "lvm-types1.xml" }
      let(:device_name) { "/dev/vg0/normal2" }
      let(:vg_name) { "vg0" }

      it "shows a detailed confirmation message including all the snapshots" do
        expect(subject).to receive(:confirm_recursive_delete)
          .with(device, anything, anything, /normal2/)
          .and_call_original

        subject.run
      end
    end

    context "when the confirm message is not accepted" do
      let(:accept) { :no }

      let(:device_name) { "/dev/vg1/lv1" }

      it "does not delete the logical volume" do
        subject.run
        expect(device.exists_in_devicegraph?(current_graph)).to eq(true)
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end

      context "and the logical volume is a used thin pool" do
        let(:device_name) { "/dev/vg1/pool1" }

        it "does not delete the thin volumes over the thin pool" do
          thin_volumes = device.lvm_lvs
          subject.run

          expect(thin_volumes.all? { |v| v.exists_in_devicegraph?(current_graph) }).to eq(true)
        end
      end
    end

    context "when the confirm message is accepted" do
      let(:accept) { :yes }

      let(:device_name) { "/dev/vg1/lv1" }

      it "deletes the logical volume" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(current_graph, device_name)).to be_nil
      end

      it "refresh btrfs subvolumes shadowing" do
        expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
        subject.run
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end

      context "and the logical volume is a used thin pool" do
        let(:device_name) { "/dev/vg1/pool1" }

        it "deletes all thin volumes over the thin pool" do
          lv_names = device.lvm_lvs.map(&:name)
          subject.run

          lvs = lv_names.map { |n| current_graph.find_by_name(n) }.compact
          expect(lvs).to be_empty
        end
      end
    end
  end
end
