#!/usr/bin/env rspec
# Copyright (c) [2019] SUSE LLC
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

xdescribe Y2Storage::MinGuidedProposal do
  describe "#propose with settings in the Agama style" do
    include_context "proposal"

    subject(:proposal) { described_class.new(settings: settings) }

    let(:architecture) { :x86 }
    let(:settings_format) { :ng }
    let(:control_file) { "agama_resize.xml" }
    let(:scenario) { "not_so_empty_disks" }
    let(:hwinfo) { Y2Storage::HWInfoDisk.new }
    let(:vols) { settings.volumes }

    before do
      allow_any_instance_of(Y2Storage::Disk).to receive(:hwinfo).and_return(hwinfo)

      # Let's play with this settings to find the right combination
      settings.allocate_volume_mode = :auto
      settings.separate_vgs = lvm

      # /dev/sdb is selected as boot disk
      settings.candidate_devices = ["/dev/sdb"]
      settings.root_device = "/dev/sdb"
    end

    context "when ProposalSettings#lvm is set to false" do
      let(:lvm) { false }

      context "if all partitions must be located in the boot disk" do
        let(:expected_scenario) { "volumes-one_disk" }

        #include_examples "proposed layout"
        it "does stuff" do
          proposal.propose
          Y2Storage::YamlWriter.write(proposal.devices, "/tmp/agama-parts-sdb.yml")
        end
      end

      context "if some partitions are assigned to different disks" do
        let(:expected_scenario) { "volumes-three_disks" }

        before do
          vols.each do |vol|
            vol.device = "/dev/sda" if vol.mount_point == "/var/lib"
            vol.device = "/dev/sdc" if vol.mount_point == "/srv"
          end
        end

        it "does stuff" do
          proposal.propose
          Y2Storage::YamlWriter.write(proposal.devices, "/tmp/agama-parts-distributed.yml")
        end
      end

      context "if all partitions (even the root one) are assigned to a different disk" do
        let(:expected_scenario) { "volumes-three_disks" }

        before do
          vols.each { |v| v.device = "/dev/sda" }
        end

        it "does stuff" do
          proposal.propose
          Y2Storage::YamlWriter.write(proposal.devices, "/tmp/agama-parts-boot_from_sdb.yml")
        end
      end
    end

    context "when ProposalSettings#lvm is set to true" do
      let(:lvm) { true }

      context "if all volumes must be located in the system VG" do
        let(:expected_scenario) { "volumes-one_disk" }
        before do
          vols.each { |v| v.separate_vg_name = nil }
        end

        context "and the system VG must be located in the boot disk" do
          it "does stuff" do
            proposal.propose
            Y2Storage::YamlWriter.write(proposal.devices, "/tmp/agama-lvm-sdb.yml")
          end
        end

        context "and the system VG is allowed to use several disks" do
          before do
            settings.candidate_devices = ["/dev/sdb", "/dev/sdc"]
          end

          context "if all volumes fit when using only a disk" do
            it "does stuff" do
              proposal.propose
              Y2Storage::YamlWriter.write(proposal.devices, "/tmp/agama-lvm-sdb-sdc-small.yml")
            end
          end

          context "if several disks must be used for the volumes to fit" do
            before do
              root = vols.find { |v| v.mount_point == "/" }
              root.min_size = Y2Storage::DiskSize.GiB(380)
              root.desired_size = Y2Storage::DiskSize.GiB(380)
              root.max_size = Y2Storage::DiskSize.GiB(380)
            end

            it "does stuff" do
              proposal.propose
              Y2Storage::YamlWriter.write(proposal.devices, "/tmp/agama-lvm-sdb-sdc.yml")
            end
          end
        end
      end

      context "if some volumes must be located in their own separate VG" do
        before do
          vols.each do |vol|
            if vol.mount_point == "/var/lib"
              vol.separate_vg_name = "lib"
              vol.device = "/dev/sda"
            elsif vol.mount_point == "/srv"
              vol.separate_vg_name = "srv"
              vol.device = "/dev/sdc"
            end
          end
        end

        it "does stuff" do
          proposal.propose
          Y2Storage::YamlWriter.write(proposal.devices, "/tmp/agama-lvm-distributed.yml")
        end
      end
    end
  end
end
