#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require_relative "../spec_helper"
require "y2storage"

RSpec.shared_examples "boot disk in devicegraph" do
  context "if no there is no filesystem mounted at '/' in the devicegraph" do
    it "returns a Disk object" do
    end

    it "returns the first disk in the system" do
    end

    context "if a partition is mounted as '/' in the devicegraph" do
      it "returns a Disk object" do
      end

      it "returns the disk containing the '/' partition" do
      end
    end

    context "if a LVM LV is mounted as '/' in the devicegraph" do
      it "returns a Disk object" do
      end

      it "returns the first disk containing a PV of the involved LVM VG" do
      end
    end
  end
end

describe Y2Storage::BootRequirementsStrategies::Analyzer do
  let(:scenario) { "mixed_disks" }
  let(:devicegraph) { fake_devicegraph }
  let(:planned_devs) { [] }
  let(:boot_name) { "" }

  before { fake_scenario(scenario) }

  describe ".new" do
    let(:planned_devs) do
      [ planned_partition(mount_point: "/"), planned_partition(mount_point: "/boot") ]
    end

    # There was such a bug, test added to avoid regression"
    it "does not modify the passed collections" do
      initial_graph = devicegraph.dup
      described_class.new(devicegraph, planned_devs, boot_name)

      expect(planned_devs.map(&:mount_point)).to eq ["/", "/boot"]
      expect(devicegraph.actiongraph(from: initial_graph)).to be_empty
    end
  end

  describe "#boot_disk" do
    subject(:analyzer) { described_class.new(devicegraph, planned_devs, boot_name) }

    context "if the name of the boot disk is known and the disk exists" do
      let(:boot_name) { "/dev/sdb" }

      it "returns a Disk object" do
        expect(analyzer.boot_disk).to be_a Y2Storage::Disk
      end

      it "returns the disk matching the given name" do
        expect(analyzer.boot_disk.name).to eq boot_name
      end
    end

    context "if no name is given or there is no such disk" do
      context "but '/' is in the list of planned devices" do
        context "and the disk to allocate the planned device is known" do
          context "and disk exists" do
            it "returns a Disk object" do
            end

            it "returns the disk bla" do
            end
          end

          context "but the disk does not exist" do
            include_examples "boot disk in devicegraph"
          end
        end

        context "and the disk for '/' is not decided" do
          include_examples "boot disk in devicegraph"
        end
      end

      context "/ not in planned" do
        include_examples "boot disk in devicegraph"
      end
    end
  end

  describe "#root_in_lvm?" do
    pending
  end

  describe "#encrypted_root?" do
    pending
  end

  describe "#btrfs_root?" do
    pending
  end

  describe "#boot_ptable_type?" do
    pending
  end
end
