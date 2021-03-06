#!/usr/bin/env rspec

# Copyright (c) [2017-2020] SUSE LLC
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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/format_and_mount"
require "y2partitioner/actions/controllers"

describe Y2Partitioner::Widgets do
  before do
    devicegraph_stub(scenario)
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:blk_device) { current_graph.find_by_name(device_name) }

  let(:scenario) { "lvm-two-vgs.yml" }

  let(:device_name) { "/dev/sda1" }

  let(:controller) do
    Y2Partitioner::Actions::Controllers::Filesystem.new(blk_device, "")
  end

  describe Y2Partitioner::Widgets::FormatOptions do
    subject { described_class.new(controller, parent) }

    let(:parent) { double("FormatMountOptions") }

    include_examples "CWM::CustomWidget"

    describe "#handle" do
      before do
        allow(Y2Partitioner::Widgets::BlkDeviceFilesystem).to receive(:new).and_return(fs_selector)

        allow(fs_selector).to receive(:value).and_return(selected_fs)
        allow(fs_selector).to receive(:refresh)
        allow(fs_selector).to receive(:disable)

        allow(parent).to receive(:refresh_others)
      end

      let(:fs_selector) { instance_double(Y2Partitioner::Widgets::BlkDeviceFilesystem) }

      let(:selected_fs) { :udf }

      context "when the format option is selected" do
        let(:event) { { "ID" => :format_device } }

        it "creates a new filesystem with the selected filesystem type" do
          expect(controller).to receive(:new_filesystem).with(:udf)

          subject.handle(event)
        end
      end
    end
  end

  describe Y2Partitioner::Widgets::MountOptions do
    let(:parent) { double("FormatMountOptions") }
    subject { described_class.new(controller, parent) }

    include_examples "CWM::CustomWidget"

    describe "#validate" do
      before do
        allow(Yast2::Popup).to receive(:show)
      end

      context "when the device is not formatted" do
        before do
          blk_device.delete_filesystem
        end

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end

      context "when the device is formatted" do
        context "and it is not mounted" do
          it "returns true" do
            expect(subject.validate).to eq(true)
          end
        end

        context "and it is mounted" do
          before do
            blk_device.filesystem.create_mount_point("/")
          end

          let(:filesystem) { blk_device.filesystem }

          let(:mount_point) { filesystem.mount_point }

          context "and it is not mounted by label" do
            before do
              mount_point.mount_by = Y2Storage::Filesystems::MountByType::UUID
            end

            it "returns true" do
              expect(subject.validate).to eq(true)
            end
          end

          context "and it is mounted by label" do
            before do
              mount_point.mount_by = Y2Storage::Filesystems::MountByType::LABEL
            end

            context "and the filesystem has no label" do
              before do
                filesystem.label = ""
              end

              it "shows an error popup" do
                expect(Yast2::Popup).to receive(:show)
                subject.validate
              end

              it "returns false" do
                expect(subject.validate).to eq(false)
              end
            end

            context "and the filesystem has a label" do
              before do
                filesystem.label = "foo"
              end

              it "returns true" do
                expect(subject.validate).to eq(true)
              end
            end
          end
        end
      end

      context "when there are no errors" do
        let(:scenario) { "mixed_disks" }

        let(:device_name) { "/dev/sdb2" }

        shared_examples "no action" do
          it "does not modofy the current value about restoring the default list of subvolumes" do
            controller.restore_btrfs_subvolumes = true

            subject.validate

            expect(controller.restore_btrfs_subvolumes?).to eq(true)
          end

          it "does not ask to the user about restoring or removing subvolumes" do
            expect(Yast2::Popup).to_not receive(:show)

            subject.validate
          end
        end

        context "and the currently edited filesystem is a Btrfs that does not exist on disk yet" do
          before do
            blk_device.remove_descendants
            blk_device.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
            blk_device.filesystem.mount_path = "/"
          end

          context "and the mount path has not been modified" do
            before do
              allow(controller).to receive(:mount_path_modified?).and_return(false)
            end

            include_examples "no action"
          end

          context "and the filesystem does not contain subvolumes" do
            it "sets the controller to restore the default list of subvolumes" do
              expect(controller.restore_btrfs_subvolumes?).to eq(false)

              subject.validate

              expect(controller.restore_btrfs_subvolumes?).to eq(true)
            end

            it "does not ask to the user about restoring or removing subvolumes" do
              expect(Yast2::Popup).to_not receive(:show)

              subject.validate
            end
          end

          context "and the filesystem contains subvolumes" do
            before do
              blk_device.filesystem.create_btrfs_subvolume("foo", false)
              blk_device.filesystem.create_btrfs_subvolume("bar", false)

              allow(Y2Storage::VolumeSpecification).to receive(:for)
              allow(Y2Storage::VolumeSpecification).to receive(:for).with("/").and_return(volume_spec)
              allow(volume_spec).to receive(:subvolumes).and_return(subvolumes)
              allow(Yast2::Popup).to receive(:show).and_return(restore)
            end

            let(:volume_spec) do
              Y2Storage::VolumeSpecification.new(
                "btrfs_default_subvolume" => default_subvolume,
                "btrfs_read_only"         => false
              )
            end

            let(:subvolumes) { [] }

            let(:default_subvolume) { "" }

            let(:restore) { nil }

            shared_examples "user decision" do
              context "and the user accepts" do
                let(:restore) { :yes }

                it "sets the controller to restore the default list of subvolumes" do
                  subject.validate

                  expect(controller.restore_btrfs_subvolumes?).to eq(true)
                end
              end

              context "and the user refuses" do
                let(:restore) { false }

                it "sets the controller to not restore the default list of subvolumes" do
                  subject.validate

                  expect(controller.restore_btrfs_subvolumes?).to eq(false)
                end
              end
            end

            context "and there is a default list of subvolumes for the filesystem" do
              let(:default_subvolume) { "@" }

              let(:subvolumes) do
                [
                  Y2Storage::SubvolSpecification.new("home"),
                  Y2Storage::SubvolSpecification.new("var")
                ]
              end

              it "ask to the user whether to restore the default list of subvolumes" do
                expect(Yast2::Popup).to receive(:show).with(/create the suggested/, anything)

                subject.validate
              end

              include_examples "user decision"
            end

            context "and there is not a default list of subvolumes for the filesystem" do
              before do
                blk_device.filesystem.mount_path = "/foo"
              end

              it "ask to the user whether to delete the current subvolumes" do
                expect(Yast2::Popup).to receive(:show).with(/delete the current/, anything)

                subject.validate
              end

              include_examples "user decision"
            end
          end
        end

        context "and the currently edited filesystem is not a new Btrfs" do
          let(:device_name) { "/dev/sda2" }

          include_examples "no action"
        end
      end
    end
  end

  describe Y2Partitioner::Widgets::FstabOptionsButton do
    before do
      allow(Y2Partitioner::Dialogs::FstabOptions)
        .to receive(:new).and_return(double(run: :next))

      blk_device.filesystem.create_mount_point("/")
    end

    let(:blk_device) { Y2Storage::Partition.find_by_name(current_graph, "/dev/sda6") }

    subject { described_class.new(controller) }

    include_examples "CWM::PushButton"
  end

  describe Y2Partitioner::Widgets::BlkDeviceFilesystem do
    subject { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"

    describe "#items" do
      let(:options) { subject.items.map(&:first) }

      it "contains swap option" do
        expect(options).to include(:swap)
      end

      it "contains btrfs option" do
        expect(options).to include(:btrfs)
      end

      it "contains ext2 option" do
        expect(options).to include(:ext2)
      end

      it "contains ext3 option" do
        expect(options).to include(:ext3)
      end

      it "contains ext4 option" do
        expect(options).to include(:ext4)
      end

      it "contains vfat option" do
        expect(options).to include(:vfat)
      end

      it "contains xfs option" do
        expect(options).to include(:xfs)
      end

      it "contains udf option" do
        expect(options).to include(:udf)
      end
    end
  end

  describe Y2Partitioner::Widgets::MountPoint do
    before do
      devicegraph_stub("mixed_disks_btrfs.yml")
    end

    subject { described_class.new(controller) }

    include_examples "CWM::ComboBox"

    describe "#validate" do
      before do
        allow(subject).to receive(:enabled?).and_return(enabled)
        allow(subject).to receive(:value).and_return(value)
        allow(Yast2::Popup).to receive(:show)
      end

      let(:value) { nil }

      context "when the widget is not enabled" do
        let(:enabled) { false }

        it "returns true" do
          expect(subject.validate).to be(true)
        end
      end

      context "when the widget is enabled" do
        let(:enabled) { true }

        context "and the mount point is not indicated" do
          let(:value) { "" }

          it "shows an error message" do
            expect(Yast2::Popup).to receive(:show)
            subject.validate
          end

          it "returns false" do
            expect(subject.validate).to be(false)
          end
        end

        context "and the mount point is not 'swap' and already exists" do
          let(:value) { "/home" }

          it "shows an error message" do
            expect(Yast2::Popup).to receive(:show)
            subject.validate
          end

          it "returns false" do
            expect(subject.validate).to be(false)
          end
        end

        context "and the mount point is 'swap', that already exists" do
          let(:value) { "swap" }

          it "does not show any error message" do
            expect(Yast2::Popup).to_not receive(:show)
            subject.validate
          end

          it "returns true" do
            expect(subject.validate).to be(true)
          end
        end

        context "and the mount point does not exist" do
          context "and the mount point does not shadow any subvolume" do
            let(:value) { "/foo" }

            it "returns true" do
              expect(subject.validate).to be(true)
            end
          end
        end
      end
    end
  end

  describe Y2Partitioner::Widgets::InodeSize do
    let(:format_options) do
      double("Format Options")
    end

    subject { described_class.new(format_options) }

    include_examples "CWM::ComboBox"
  end

  describe Y2Partitioner::Widgets::BlockSize do
    subject { described_class.new(controller) }

    include_examples "CWM::ComboBox"
  end

  describe Y2Partitioner::Widgets::EncryptBlkDevice do
    subject { described_class.new(controller) }

    include_examples "CWM::CheckBox"

    describe "#validate" do
      before do
        allow(subject).to receive(:value).and_return(true)
      end

      context "encrypt is not checked" do
        it "returns true" do
          allow(subject).to receive(:value).and_return(false)

          expect(subject.validate).to eq true
        end
      end

      context "encrypt is checked and the partition is bigger than 2MiB" do
        it "returns true" do
          expect(subject.validate).to eq true
        end
      end

      context "encrypt is checked and the partition is equal or smaller than 2MiB" do
        before do
          expect(controller).to receive(:blk_device)
            .and_return(double(size: Y2Storage::DiskSize.MiB(1)))
          allow(Yast2::Popup).to receive(:show)
        end

        it "returns false" do
          expect(subject.validate).to eq false
        end

        it "shows an error popup" do
          expect(Yast2::Popup).to receive(:show).with(anything, headline: :error)

          subject.validate
        end
      end
    end
  end

  describe Y2Partitioner::Widgets::PartitionId do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::CustomWidget"

    let(:combo) do
      widget.contents.nested_find { |i| i.is_a?(Y2Partitioner::Widgets::PartitionIdComboBox) }
    end

    context "when working with a partition" do
      let(:blk_device) { Y2Storage::Partition.find_by_name(fake_devicegraph, "/dev/sda1") }

      describe "#contents" do
        it "includes a combo box for the partition id" do
          expect(combo).to_not be_nil
        end
      end

      describe "#value" do
        it "returns the value of the combo box" do
          allow(combo).to receive(:value).and_return :some_value
          expect(widget.value).to eq :some_value
        end
      end

      describe "#event_id" do
        it "returns the widget_id of the combo box" do
          expect(widget.event_id).to eq combo.widget_id
        end
      end

      describe "#enable" do
        it "forwards the call to the combo box" do
          expect(combo).to receive(:enable)
          widget.enable
        end
      end

      describe "#disable" do
        it "forwards the call to the combo box" do
          expect(combo).to receive(:disable)
          widget.disable
        end
      end
    end

    context "when working with another type of device (e.g. LVM LV)" do
      let(:blk_device) { Y2Storage::LvmLv.find_by_name(fake_devicegraph, "/dev/vg0/lv1") }

      describe "#contents" do
        it "does not include a combo box for the partition id" do
          expect(combo).to be_nil
        end
      end

      describe "#value" do
        it "returns nil" do
          expect(widget.value).to be_nil
        end
      end

      describe "#event_id" do
        it "returns nil" do
          expect(widget.event_id).to be_nil
        end
      end

      describe "#enable" do
        it "does nothing and does not fail" do
          expect { widget.enable }.to_not raise_error
        end
      end

      describe "#disable" do
        it "does nothing and does not fail" do
          expect { widget.disable }.to_not raise_error
        end
      end
    end
  end

  describe Y2Partitioner::Widgets::PartitionIdComboBox do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"
  end

  describe Y2Partitioner::Widgets::Snapshots do
    subject { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"
  end

  describe Y2Partitioner::Widgets::FormatOptionsArea do
    subject(:widget) { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"

    describe "#refresh" do
      let(:options_button) { double("FormatOptionsButton", enable: nil, disable: nil) }
      let(:snapshots_checkbox) { double("Snapshots", refresh: nil) }

      before do
        allow(Y2Partitioner::Widgets::FormatOptionsButton).to receive(:new).and_return options_button
        allow(Y2Partitioner::Widgets::Snapshots).to receive(:new).and_return snapshots_checkbox
        allow(controller).to receive(:snapshots_supported?).and_return snapshots_supported
        allow(controller).to receive(:format_options_supported?).and_return options_supported
      end

      context "if snapshots are supported for the current block device" do
        let(:snapshots_supported) { true }

        context "and format options are also supported" do
          let(:options_supported) { true }

          it "shows the snapshot checkbox in sync with the value from the controller" do
            expect(widget).to receive(:show).with(snapshots_checkbox).ordered
            expect(snapshots_checkbox).to receive(:refresh).ordered
            widget.refresh
          end
        end

        context "and format options are not supported" do
          let(:options_supported) { false }

          it "shows the snapshot checkbox in sync with the value from the controller" do
            expect(widget).to receive(:show).with(snapshots_checkbox).ordered
            expect(snapshots_checkbox).to receive(:refresh).ordered
            widget.refresh
          end
        end
      end

      context "if snapshots are not supported for the current block device" do
        let(:snapshots_supported) { false }

        context "and format options are supported" do
          let(:options_supported) { true }

          it "shows the enabled options button" do
            expect(widget).to receive(:show).with(options_button).ordered
            expect(options_button).to receive(:enable).ordered
            widget.refresh
          end
        end

        context "and format options are not supported either" do
          let(:options_supported) { false }

          it "shows the disabled options button" do
            expect(widget).to receive(:show).with(options_button).ordered
            expect(options_button).to receive(:disable).ordered
            widget.refresh
          end
        end
      end
    end
  end
end
