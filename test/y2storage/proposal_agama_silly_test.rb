#!/usr/bin/env rspec
# Copyright (c) [2023] SUSE LLC
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

require_relative "spec_helper"
require "storage"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::MinGuidedProposal do
  describe "#propose with settings in the Agama style" do
    subject(:proposal) { described_class.new(settings: settings) }

    include_context "proposal"
    let(:architecture) { :x86 }
    let(:settings_format) { :ng }
    let(:separate_home) { true }
    let(:control_file_content) do
      { "partitioning" => { "proposal" => { "windows_delete_mode" => :none }, "volumes" => volumes } }
    end

    # Several disks fully used by Windows partitions
    let(:scenario) { "lvm-two-vgs" }
    let(:resize_info) do
      instance_double("Y2Storage::ResizeInfo", resize_ok?: true, reasons: 0, reason_texts: [],
        min_size: Y2Storage::DiskSize.GiB(4), max_size: Y2Storage::DiskSize.TiB(2))
    end

    # Let's define some volumes to shuffle them around among the disks
    let(:volumes) { [root_vol, home_vol, srv_vol, swap_vol] }
    let(:root_vol) do
      { "mount_point" => "/", "fs_type" => "xfs", "min_size" => "10 GiB", "max_size" => "30 GiB" }
    end
    let(:home_vol) do
      { "mount_point" => "/home", "fs_type" => "xfs", "min_size" => "15 GiB" }
    end
    let(:srv_vol) do
      { "mount_point" => "/srv", "fs_type" => "xfs", "min_size" => "5 GiB", "max_size" => "10 GiB" }
    end
    let(:swap_vol) do
      { "mount_point" => "swap", "fs_type" => "swap", "min_size" => "4 GiB", "max_size" => "6 GiB" }
    end

    before do
      # Speed-up things by avoiding calls to hwinfo
      allow_any_instance_of(Y2Storage::Disk).to receive(:hwinfo).and_return(Y2Storage::HWInfoDisk.new)

      # Install into /dev/sdb by default
      settings.candidate_devices = ["/dev/sda"]
      settings.root_device = "/dev/sda"

      # Agama uses homogeneous weights for all volumes and prevents swap reusing
      settings.volumes.each { |v| v.weight = 100 }
      settings.swap_reuse = :none
      # Activate support for separate LVM VGs
      settings.separate_vgs = true
    end

    context "when reusing existing partitions" do
      before do
        # Hack
        settings.volumes.find { |v| v.mount_point == "/srv" }.reuse_name = "/dev/sda8"
        settings.volumes.find { |v| v.mount_point == "/srv" }.reformat = false
      end

      #let(:expected_scenario_filename) { "agama-basis-single_disk" }

      it "proposes the expected layout" do
        proposal.propose
        byebug
        expect(proposal.devices.to_str).to eq expected.to_str
      end
    end

    context "when reusing existing logical volumes" do
      before do
        # Hack
        settings.volumes.find { |v| v.mount_point == "/home" }.reuse_name = "/dev/vg1/lv1"
        settings.volumes.find { |v| v.mount_point == "/home" }.reformat = false
      end

      #let(:expected_scenario_filename) { "agama-basis-single_disk" }

      it "proposes the expected layout" do
        proposal.propose
        byebug
        expect(proposal.devices.to_str).to eq expected.to_str
      end
    end
  end
end
