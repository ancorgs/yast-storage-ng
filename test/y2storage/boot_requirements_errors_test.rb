#!/usr/bin/env rspec

# Copyright (c) [2018-2019] SUSE LLC
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
require "y2storage"

describe Y2Storage::BootRequirementsChecker do
  using Y2Storage::Refinements::SizeCasts

  subject(:checker) { described_class.new(fake_devicegraph) }

  before do
    fake_scenario(scenario)

    allow(storage_arch).to receive(:efiboot?).and_return(efiboot)
    allow(storage_arch).to receive(:ppc_power_nv?).and_return(power_nv)
    allow_any_instance_of(Y2Storage::BootRequirementsStrategies::Analyzer).to receive(:boot_in_thin_lvm?)
      .and_return(use_thin_lvm)
    allow_any_instance_of(Y2Storage::BootRequirementsStrategies::Analyzer).to receive(:boot_in_bcache?)
      .and_return(use_bcache)
    allow_any_instance_of(Y2Storage::BootRequirementsStrategies::Analyzer)
      .to receive(:boot_encryption_type)
      .and_return(enc_type)
  end

  let(:storage_arch) { instance_double(Storage::Arch) }
  let(:architecture) { :x86_64 }
  let(:power_nv) { false }
  let(:efiboot) { false }
  let(:use_thin_lvm) { false }
  let(:use_bcache) { false }
  let(:enc_type) { Y2Storage::EncryptionType::NONE }

  let(:scenario) { "trivial" }

  describe "#valid?" do
    let(:errors) { [] }
    let(:warnings) { [] }

    before do
      allow(checker).to receive(:errors).and_return(errors)
      allow(checker).to receive(:warnings).and_return(warnings)
    end

    context "when there are errors" do
      let(:errors) { [Y2Storage::SetupError.new(message: "test")] }

      it "returns false" do
        expect(checker.valid?).to eq(false)
      end
    end

    context "when there are warnings" do
      let(:warnings) { [Y2Storage::SetupError.new(message: "test")] }

      it "returns false" do
        expect(checker.valid?).to eq(false)
      end
    end

    context "when there are no errors neither warnings" do
      let(:errors) { [] }
      let(:warnings) { [] }

      it "returns true" do
        expect(checker.valid?).to eq(true)
      end
    end
  end

  context "#errors and #warnings when using NFS for the root filesystem" do
    before do
      fs = Y2Storage::Filesystems::Nfs.create(fake_devicegraph, "server", "/path")
      fs.create_mount_point("/")
    end

    context "in a diskless system" do
      let(:scenario) { "nfs1.xml" }

      # Regression test for bug#1090752
      it "does not crash" do
        expect { checker.warnings }.to_not raise_error
        expect { checker.errors }.to_not raise_error
      end

      it "returns no warnings or errors" do
        expect(checker.warnings).to be_empty
        expect(checker.errors).to be_empty
      end
    end

    context "in a system with local disks" do
      let(:scenario) { "empty_hard_disk_50GiB" }

      # This used to consider the local disk as the one to boot from, so it
      # reported wrong errors assuming "/" was going to be there.
      it "returns no warnings or errors" do
        expect(checker.warnings).to be_empty
        expect(checker.errors).to be_empty
      end
    end
  end

  def format_dev(name, type, path)
    fs = fake_devicegraph.find_by_name(name).create_filesystem(type)
    fs.mount_path = path
  end

  def format_zipl(name)
    format_dev(name, Y2Storage::Filesystems::Type::EXT4, "/boot/zipl")
  end

  describe "#errors" do
    RSpec.shared_examples "unknown boot disk" do
      it "contains an fatal error for unknown boot disk" do
        expect(checker.errors.size).to eq(1)
        expect(checker.errors).to all(be_a(Y2Storage::SetupError))

        message = checker.errors.first.message
        expect(message).to match(/no device mounted at '\/'/)
      end
    end

    let(:efiboot) { false }

    context "/boot is too small" do
      let(:scenario) { "small_boot" }

      before do
        allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem).to receive(:detect_space_info)
          .and_return(double(free: Y2Storage::DiskSize.MiB(1)))
      end

      it "contains an error when there is /boot that is not big enough" do
        expect(checker.errors.size).to eq(1)
        expect(checker.errors).to all(be_a(Y2Storage::SetupError))

        message = checker.errors.first.message
        expect(message).to match(/does not have enough space/)
      end
    end

    context "/boot is in a BCache" do
      let(:use_bcache) { true }

      it "contains an error that /boot cannot be in a BCache" do
        expect(checker.errors.size).to eq(1)
        expect(checker.errors).to all(be_a(Y2Storage::SetupError))

        message = checker.errors.first.message
        expect(message).to match(/boot.*BCache/)
      end
    end

    context "in a x86 system not using UEFI (legacy PC)" do
      let(:architecture) { :x86 }
      let(:efiboot) { false }

      context "when there is no root" do
        let(:scenario) { "false-swaps" }
        include_examples "unknown boot disk"
      end
    end

    context "in a PPC64 system" do
      let(:architecture) { :ppc }
      let(:efiboot) { false }
      let(:power_nv) { false }

      context "when there is no root" do
        let(:scenario) { "false-swaps" }
        include_examples "unknown boot disk"
      end
    end

    context "in a S/390 system" do
      let(:architecture) { :s390 }
      let(:efiboot) { false }
      let(:scenario) { "several-dasds" }

      context "when there is no root" do
        include_examples "unknown boot disk"
      end

      context "if / is in the plain implicit partition of an FBA device" do
        before { format_dev(root_name, root_type, "/") }

        let(:root_name) { "/dev/dasdc3" }
        let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }
        let(:root_name) { "/dev/dasdb1" }

        # Regression test for bug#1070265. It wrongly claimed booting
        # from FBA DASDs was not supported. See the similar test for #warnings
        # below
        it "contains no error about unsupported disk" do
          expect(checker.errors).to be_empty
        end
      end
    end
  end

  describe "#warnings" do
    RSpec.shared_examples "no warnings" do
      it "does not contain any warning" do
        expect(checker.warnings).to be_empty
      end
    end

    context "/boot is in a thin LVM volume" do
      let(:use_thin_lvm) { true }

      it "contains a warning warning /boot should not be in a thin LVM volume" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        message = checker.warnings.first.message
        expect(message).to match(/boot.*thin.*LVM/)
      end
    end

    RSpec.shared_examples "missing boot partition" do
      it "contains an error for missing boot partition" do
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))
        messages = checker.warnings.map(&:message)
        expect(messages).to include(
          match(/Missing device for \/boot/)
        )
      end
    end

    RSpec.shared_examples "missing mbr gap" do
      it "contains an error for missing/too small mbr gap" do
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))
        messages = checker.warnings.map(&:message)
        expect(messages).to include(
          match(/Not enough space before the first partition/)
        )
      end
    end

    RSpec.shared_examples "missing prep partition" do
      it "contains an error for missing PReP partition" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        message = checker.warnings.first.message
        expect(message).to match(/Missing device.* partition id prep/)
      end
    end

    RSpec.shared_examples "missing zipl partition" do
      it "contains an error for missing ZIPL partition" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        msg = checker.warnings.first.message
        expect(msg).to match(/Missing device for \/boot\/zipl/)
      end
    end

    RSpec.shared_examples "unsupported boot disk" do
      it "contains an error for unsupported boot disk" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        message = checker.warnings.first.message
        expect(message).to match(/is not supported/)
      end
    end

    RSpec.shared_examples "efi partition" do
      context "when there is no /boot/efi partition in the system" do
        let(:scenario) { "trivial" }

        it "contains an error for the efi partition" do
          expect(checker.warnings.size).to eq(1)
          expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

          message = checker.warnings.first.message
          expect(message).to match(/Missing device for \/boot\/efi/)
        end
      end

      context "when there is a /boot/efi partition in the system" do
        let(:scenario) { "efi" }

        include_examples("no warnings")
      end
    end

    context "when /boot is encrypted" do
      context "and grub can decrypt it" do
        let(:enc_type) { Y2Storage::EncryptionType::LUKS1 }
        it "does not contain any warning" do
          expect(checker.warnings).to be_empty
        end
      end

      context "and grub cannot decrypt it" do
        let(:enc_type) { Y2Storage::EncryptionType::LUKS2 }
        it "shows a warning that grub cannot access /boot" do
          expect(checker.warnings.size).to eq(1)
          expect(checker.warnings.first.message).to match(/cannot access/)
        end
      end
    end

    context "in a x86 system" do
      let(:architecture) { :x86 }

      context "using UEFI" do
        let(:efiboot) { true }
        include_examples "efi partition"

        context "/boot/efi lays on md raid level 1" do
          let(:scenario) { "raid_efi" }

          it "contains warning" do
            expect(checker.warnings.size).to eq(1)
            expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

            message = checker.warnings.first.message
            expect(message).to match(/software RAID/)
          end
        end
      end

      context "not using UEFI (legacy PC)" do
        let(:efiboot) { false }

        RSpec.shared_examples "unsupported bootloader setup" do
          it "shows a warning that the setup is not supported" do
            expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

            messages = checker.warnings.map(&:message)
            expect(messages).to include(match(/setup is not supported/))
          end
        end

        RSpec.shared_examples "invalid bootloader setup" do
          it "shows a warning that the bootloader cannot be installed" do
            expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

            messages = checker.warnings.map(&:message)
            expect(messages).to include(match(/not be possible to install/))
          end
        end

        context "when boot device has a GPT partition table" do
          context "and there is no a grub partition in the system" do
            let(:scenario) { "gpt_without_grub" }

            it "contains an error for missing grub partition" do
              expect(checker.warnings).to all(be_a(Y2Storage::SetupError))
              messages = checker.warnings.map(&:message)
              expect(messages).to include(
                match(/partition of type BIOS Boot/)
              )
            end
          end

          context "and there is a grub partition in the system" do
            it "does not contain warnings" do
              expect(checker.warnings).to be_empty
            end
          end
        end

        context "with a MS-DOS partition table" do
          context "with a too small MBR gap (no room to allocate Grub there)" do
            before do
              allow(checker.send(:strategy).boot_disk).to receive(:mbr_gap_for_grub?).and_return(false)
            end

            context "in a plain btrfs setup" do
              let(:scenario) { "dos_btrfs" }

              include_examples "missing mbr gap"
              include_examples "unsupported bootloader setup"
            end

            context "in a LVM-based setup" do
              let(:scenario) { "dos_lvm" }

              context "if there is no separate /boot" do
                include_examples "missing mbr gap"
                include_examples "invalid bootloader setup"
              end

              context "if there is separate /boot" do
                let(:scenario) { "dos_lvm_boot_partition" }

                include_examples "missing mbr gap"
                include_examples "unsupported bootloader setup"
              end
            end

            context "in an encrypted setup" do
              let(:scenario) { "dos_encrypted" }

              context "if there is no separate /boot" do
                include_examples "missing mbr gap"
                include_examples "invalid bootloader setup"
              end

              context "if there is separate /boot" do
                let(:scenario) { "dos_encrypted_boot_partition" }

                include_examples "missing mbr gap"
                include_examples "unsupported bootloader setup"
              end
            end
          end

          context "if the MBR gap is big enough to embed Grub" do
            before do
              allow(checker.send(:strategy).boot_disk).to receive(:mbr_gap_for_grub?).and_return(true)
            end

            context "in a partitions-based setup" do
              let(:scenario) { "dos_btrfs" }

              include_examples "no warnings"
            end

            context "in a LVM-based setup" do
              # examples define own gap
              let(:scenario) { "dos_lvm" }

              include_examples "no warnings"
            end

            context "in an encrypted setup" do
              let(:scenario) { "dos_encrypted" }

              include_examples "no warnings"
            end
          end
        end

        context "with a separate boot (/boot) file-system" do
          context "and the /boot is over a partition" do
            let(:scenario) { "separate_boot_partition" }

            include_examples "no warnings"
          end

          context "and the /boot is directly on disk (no partition table)" do
            let(:scenario) { "separate_boot_disk" }

            it "shows a warning that the boot device has no partition table" do
              expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

              messages = checker.warnings.map(&:message)
              expect(messages).to include(match(/has no partition table/))
            end
          end
        end

        context "with the root (/) file-system directly on disk (no partition table)" do
          context "if / is not encrypted" do
            context "and the / file-system can embed grub (ext2/3/4 or btrfs)" do
              let(:scenario) { "btrfs_on_disk" }

              include_examples "unsupported bootloader setup"
            end

            context "and the / file-system cannot embed grub (eg. XFS)" do
              let(:scenario) { "xfs_on_disk" }

              include_examples "invalid bootloader setup"
            end
          end

          context "if / is encrypted" do
            before do
              fake_devicegraph.disks.first.create_encryption("cr_device")
            end

            context "and the / file-system can embed grub (ext2/3/4 or btrfs)" do
              let(:scenario) { "btrfs_on_disk" }

              include_examples "invalid bootloader setup"
            end

            context "and the / file-system cannot embed grub (eg. XFS)" do
              let(:scenario) { "xfs_on_disk" }

              include_examples "invalid bootloader setup"
            end
          end
        end
      end
    end

    context "in an aarch64 system" do
      let(:architecture) { :aarch64 }
      # it's always UEFI
      let(:efiboot) { true }
      include_examples "efi partition"
    end

    context "in a PPC64 system" do
      let(:architecture) { :ppc }
      let(:efiboot) { false }
      let(:power_nv) { false }

      context "in a non-PowerNV system (KVM/LPAR)" do
        let(:power_nv) { false }

        context "with a partitions-based proposal" do

          context "there is a PReP partition" do
            let(:scenario) { "prep" }
            include_examples "no warnings"
          end

          context "there is too big PReP partition" do
            let(:scenario) { "prep_big" }

            it "contains a warning for too big PReP partition" do
              expect(checker.warnings.size).to eq(1)
              expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

              message = checker.warnings.first.message
              expect(message).to match(/partition is too big/)
            end
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial" }
            include_examples "missing prep partition"
          end
        end

        context "with a LVM-based proposal" do
          context "there is a PReP partition" do
            let(:scenario) { "prep_lvm" }
            include_examples "no warnings"
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial_lvm" }
            include_examples "missing prep partition"
          end
        end

        context "with an encrypted proposal" do
          context "there is a PReP partition" do
            let(:scenario) { "prep_encrypted" }
            include_examples "no warnings"
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial_encrypted" }
            include_examples "missing prep partition"
          end
        end
      end

      context "in bare metal (PowerNV)" do
        let(:power_nv) { true }

        context "with a partitions-based proposal" do
          let(:scenario) { "trivial" }

          include_examples "no warnings"
        end

        context "with a LVM-based proposal" do
          context "and there is no /boot partition in the system" do
            let(:scenario) { "trivial_lvm" }

            include_examples "missing boot partition"
          end

          context "and there is a /boot partition in the system" do
            let(:scenario) { "lvm_with_boot" }

            include_examples "no warnings"
          end
        end

        context "with an encrypted proposal" do
          context "and there is no /boot partition in the system" do
            let(:scenario) { "trivial_encrypted" }

            include_examples "missing boot partition"
          end

          context "and there is a /boot partition in the system" do
            let(:scenario) { "encrypted_with_boot" }

            include_examples "no warnings"
          end
        end
      end
    end

    context "in a S/390 system" do
      let(:architecture) { :s390 }
      let(:efiboot) { false }
      let(:scenario) { "several-dasds" }

      RSpec.shared_examples "zipl needed if missing" do
        context "and there is a /boot/zipl partition" do
          before { format_zipl("/dev/dasdc2") }

          include_examples "no warnings"
        end

        context "and there is no /boot/zipl partition" do
          include_examples "missing zipl partition"
        end
      end

      RSpec.shared_examples "zipl not needed" do
        context "and there is a /boot/zipl partition" do
          before { format_zipl("/dev/dasdc2") }

          include_examples "no warnings"
        end

        context "and there is no /boot/zipl partition" do
          include_examples "no warnings"
        end
      end

      RSpec.shared_examples "zipl separate boot" do
        context "and /boot uses a non-readable filesystem type (e.g. btrfs)" do
          let(:boot_type) { Y2Storage::Filesystems::Type::BTRFS }

          include_examples "zipl needed if missing"
        end

        context "with /boot formatted in a readable filesystem type (XFS or extX)" do
          let(:boot_type) { Y2Storage::Filesystems::Type::XFS }

          include_examples "zipl not needed"
        end
      end

      RSpec.shared_examples "zipl not accessible root" do
        context "and / uses a non-readable filesystem type (e.g. btrfs)" do
          let(:root_type) { Y2Storage::Filesystems::Type::BTRFS }

          include_examples "zipl needed if missing"
        end

        context "and / is formatted in a readable filesystem type (XFS or extX)" do
          let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }

          include_examples "zipl needed if missing"
        end
      end

      context "if / is in a plain partition" do
        before { format_dev(root_name, root_type, "/") }

        let(:root_name) { "/dev/dasdc3" }
        let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }

        context "in a (E)CKD DASD disk formatted as LDL" do
          let(:root_name) { "/dev/dasda1" }

          include_examples "unsupported boot disk"
        end

        context "in the implicit partition table of an FBA device" do
          let(:root_name) { "/dev/dasdb1" }

          # Regression test for bug#1070265. It wrongly claimed booting from FBA DASDs
          # was not supported. See also similar test above for #errors
          it "contains no error about unsupported disk" do
            expect(checker.warnings).to be_empty
          end
        end

        context "and there is a separate /boot partition" do
          before { format_dev("/dev/dasdc1", boot_type, "/boot") }

          include_examples "zipl separate boot"
        end

        context "if there is no separate /boot partition" do
          context "and / uses a non-readable filesystem type (e.g. btrfs)" do
            let(:root_type) { Y2Storage::Filesystems::Type::BTRFS }

            include_examples "zipl needed if missing"
          end

          context "and / is formatted in a readable filesystem type (XFS or extX)" do
            let(:root_type) { Y2Storage::Filesystems::Type::XFS }

            include_examples "zipl not needed"
          end
        end
      end

      context "and / is in a encrypted partition" do
        before do
          enc = fake_devicegraph.find_by_name(root_name).create_encryption("enc")
          format_dev(enc.name, root_type, "/")
        end

        let(:root_name) { "/dev/dasdc3" }
        let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }

        context "in a (E)CKD DASD disk formatted as LDL" do
          let(:root_name) { "/dev/dasda1" }

          include_examples "unsupported boot disk"
        end

        context "and there is a separate /boot partition" do
          before { format_dev("/dev/dasdc1", boot_type, "/boot") }

          include_examples "zipl separate boot"
        end

        context "if there is no separate /boot partition" do
          include_examples "zipl not accessible root"
        end
      end

      context "and / is in an LVM logical volume" do
        before { format_dev("/dev/vg0/lv1", root_type, "/") }
        let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }

        context "and there is a separate /boot partition" do
          before { format_dev("/dev/dasdc1", boot_type, "/boot") }

          include_examples "zipl separate boot"
        end

        context "if there is no separate /boot partition" do
          include_examples "zipl not accessible root"
        end
      end

      context "and / is in an MD RAID" do
        before do
          md = Y2Storage::Md.create(fake_devicegraph, "/dev/md0")
          md.md_level = Y2Storage::MdLevel::RAID0
          md.add_device(fake_devicegraph.find_by_name("/dev/dasdc3"))
          md.add_device(fake_devicegraph.find_by_name("/dev/dasdd2"))
          format_dev(md.name, root_type, "/")
        end

        let(:root_type) { Y2Storage::Filesystems::Type::EXT4 }

        context "and there is a separate /boot partition" do
          before { format_dev("/dev/dasdc1", boot_type, "/boot") }

          include_examples "zipl separate boot"
        end

        context "if there is no separate /boot partition" do
          include_examples "zipl not accessible root"
        end
      end
    end
  end
end
