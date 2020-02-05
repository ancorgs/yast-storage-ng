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

describe Y2Partitioner::Widgets::Pages::System do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new("hostname", pager) }

  let(:pager) { double("OverviewTreePager", invalidated_pages: []) }

  let(:scenario) { "mixed_disks.yml" }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::Page"

  describe "#contents" do
    # Widget with the list of devices
    def find_table(widgets)
      widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) }
    end

    # Names from the devices in the list
    def row_names(table)
      table.items.map { |i| i[1] }
    end

    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    let(:table) { find_table(widgets) }

    let(:items) { row_names(table) }

    it "contains a button for rescanning devices" do
      button = widgets.find { |w| w.is_a?(Y2Partitioner::Widgets::RescanDevicesButton) }
      expect(button).to_not be_nil
    end

    it "contains a device buttons set" do
      device_buttons = widgets.find { |w| w.is_a?(Y2Partitioner::Widgets::DeviceButtonsSet) }
      expect(device_buttons).to_not be_nil
    end

    it "contains a widget for configuring storage technologies" do
      button = widgets.find { |w| w.is_a?(Y2Partitioner::Widgets::Configure) }
      expect(button).to_not be_nil
    end

    context "when it is running in installation mode" do
      before do
        allow(Yast::Mode).to receive(:installation).and_return(true)
      end

      it "contains a button for importing mount points" do
        button = widgets.find { |w| w.is_a?(Y2Partitioner::Widgets::ImportMountPointsButton) }
        expect(button).to_not be_nil
      end
    end

    context "when it is not running in installation mode" do
      before do
        allow(Yast::Mode).to receive(:installation).and_return(false)
      end

      it "does not contain a button for importing mount points" do
        button = widgets.find { |w| w.is_a?(Y2Partitioner::Widgets::ImportMountPointsButton) }
        expect(button).to be_nil
      end
    end

    context "when there are disks" do
      let(:scenario) { "mixed_disks.yml" }

      it "contains all disks and their partitions" do
        expect(remove_sort_keys(items)).to contain_exactly(
          "/dev/sda",
          "/dev/sda1",
          "/dev/sda2",
          "/dev/sdb",
          "/dev/sdb1",
          "/dev/sdb2",
          "/dev/sdb3",
          "/dev/sdb4",
          "/dev/sdb5",
          "/dev/sdb6",
          "/dev/sdb7",
          "/dev/sdc"
        )
      end
    end

    context "when there are DASDs devices" do
      let(:scenario) { "dasd_50GiB.yml" }

      it "contains all DASDs and their partitions" do
        expect(remove_sort_keys(items)).to contain_exactly(
          "/dev/dasda",
          "/dev/dasda1"
        )
      end
    end

    context "when there are DM RAIDs" do
      let(:scenario) { "empty-dm_raids.xml" }

      it "contains all DM RAIDs" do
        expect(remove_sort_keys(items)).to include(
          "/dev/mapper/isw_ddgdcbibhd_test1",
          "/dev/mapper/isw_ddgdcbibhd_test2"
        )
      end

      it "does not contain devices belonging to DM RAIDs" do
        expect(remove_sort_keys(items)).to_not include(
          "/dev/sdb",
          "/dev/sdc"
        )
      end

      it "contains devices that does not belong to DM RAIDs" do
        expect(remove_sort_keys(items)).to include(
          "/dev/sda",
          "/dev/sda1",
          "/dev/sda2"
        )
      end
    end

    context "when there are BIOS MD RAIDs" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }

      it "contains all BIOS MD RAIDs" do
        expect(remove_sort_keys(items)).to include(
          "/dev/md/a",
          "/dev/md/b"
        )
      end

      it "does not contain devices belonging to BIOS DM RAIDs" do
        expect(remove_sort_keys(items)).to_not include(
          "/dev/sdb",
          "/dev/sdc",
          "/dev/sdd"
        )
      end

      it "contains devices that does not belong to BIOS DM RAIDs" do
        expect(remove_sort_keys(items)).to include(
          "/dev/sda",
          "/dev/sda1",
          "/dev/sda2"
        )
      end
    end

    context "when there are Software RAIDs" do
      let(:scenario) { "md_raid" }

      before do
        Y2Storage::Md.create(current_graph, "/dev/md1")
      end

      it "contains all Software RAIDs" do
        expect(remove_sort_keys(items)).to include(
          "/dev/md/md0",
          "/dev/md1"
        )
      end

      it "contains devices belonging to Software RAIDs" do
        expect(remove_sort_keys(items)).to include(
          "/dev/sda"
        )
      end
    end

    context "when there are Volume Groups" do
      let(:scenario) { "lvm-two-vgs.yml" }

      before do
        vg = Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0")
        create_thin_provisioning(vg)
      end

      it "contains all Volume Groups and their logical volumes (including thin volumes)" do
        expect(remove_sort_keys(items)).to include(
          "/dev/vg0",
          "/dev/vg0/lv1",
          "/dev/vg0/lv2",
          "/dev/vg0/pool1",
          "/dev/vg0/thin1",
          "/dev/vg0/thin2",
          "/dev/vg0/pool2",
          "/dev/vg0/thin3",
          "/dev/vg1",
          "/dev/vg1/lv1"
        )
      end

      it "contains devices belonging to Volume Groups" do
        expect(remove_sort_keys(items)).to include(
          "/dev/sda5",
          "/dev/sda7",
          "/dev/sda9"
        )
      end
    end

    context "when there are NFS mounts" do
      let(:scenario) { "nfs1.xml" }

      it "contains all NFS mounts, represented by their share string" do
        expect(items).to include("srv:/home/a", "srv2:/home/b")
      end
    end

    context "when there are bcache devices" do
      let(:scenario) { "bcache1.xml" }

      it "contains all bcache devices" do
        expect(remove_sort_keys(items)).to include("/dev/bcache0", "/dev/bcache1", "/dev/bcache2")
      end
    end

    context "when there are multidevice filesystems" do
      let(:scenario) { "btrfs2-devicegraph.xml" }
      let(:multidevice_filesystems) { current_graph.btrfs_filesystems.select(&:multidevice?) }

      it "contains all multidevice filesystems" do
        expected_items = multidevice_filesystems.map do |fs|
          "#{fs.type.to_human_string} #{fs.blk_device_basename}"
        end

        expect(items).to include(*expected_items)
      end
    end

    describe "caching" do
      let(:scenario) { "empty_hard_disk_15GiB" }
      let(:pager) { Y2Partitioner::Widgets::OverviewTreePager.new("hostname") }
      let(:nfs_page) { Y2Partitioner::Widgets::Pages::NfsMounts.new(pager) }

      # Device names from the table
      def rows
        widgets = Yast::CWM.widgets_in_contents([subject])
        table = find_table(widgets)
        row_names(table)
      end

      it "caches the table content between calls" do
        expect(remove_sort_keys(rows)).to eq ["/dev/sda"]
        Y2Storage::Filesystems::Nfs.create(current_graph, "new", "/device")
        # The new device is not included
        expect(remove_sort_keys(rows)).to eq ["/dev/sda"]
      end

      it "refreshes the cached content if the NFS page was visited" do
        expect(remove_sort_keys(rows)).to eq ["/dev/sda"]
        Y2Storage::Filesystems::Nfs.create(current_graph, "new", "/device")
        expect(remove_sort_keys(rows)).to eq ["/dev/sda"]
        # Leave the NFS page
        nfs_page.store
        # Now the device is there
        expect(remove_sort_keys(rows)).to eq ["/dev/sda", "new:/device"]
        Y2Storage::Filesystems::Nfs.create(current_graph, "another", "/device")
        # Still cached
        expect(remove_sort_keys(rows)).to eq ["/dev/sda", "new:/device"]
      end
    end
  end
end
