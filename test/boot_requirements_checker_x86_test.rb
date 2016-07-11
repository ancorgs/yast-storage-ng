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

require_relative "spec_helper"
require_relative "support/proposed_partitions_examples"
require_relative "support/boot_requirements_context"
require "storage/proposal"
require "storage/boot_requirements_checker"
require "storage/refinements/size_casts"

describe Yast::Storage::BootRequirementsChecker do
  describe "#needed_partitions in a x86 system" do
    using Yast::Storage::Refinements::SizeCasts

    include_context "boot requirements"

    let(:architecture) { :x86 }
    let(:grub_partitions) { {} }
    let(:efi_partitions) { {} }
    let(:use_lvm) { false }
    let(:sda_part_table) { pt_msdos }

    before do
      allow(analyzer).to receive(:mbr_gap).and_return("/dev/sda" => Yast::Storage::DiskSize.KiB(300))
      allow(analyzer).to receive(:grub_partitions).and_return grub_partitions

      allow(storage_arch).to receive(:efiboot?).and_return(efiboot)
      allow(analyzer).to receive(:efi_partitions).and_return efi_partitions
    end

    context "using UEFI" do
      let(:efiboot) { true }

      context "with a partitions-based proposal" do
        let(:use_lvm) { false }

        context "if there are no EFI partitions" do
          let(:efi_partitions) { {} }

          it "requires only a new /boot/efi partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_with_fields(mount_point: "/boot/efi", reuse: nil)
            )
          end
        end

        context "if there is already an EFI partition" do
          let(:efi_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

          it "only requires to use the existing EFI partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_with_fields(mount_point: "/boot/efi", reuse: "/dev/sda1")
            )
          end
        end
      end

      context "with a LVM-based proposal" do
        let(:use_lvm) { true }

        context "with GPT partition table containing a GRUB partition" do
          let(:sda_part_table) { pt_gpt }
          let(:grub_partitions) { { dev_sda.name => [analyzer_part(dev_sda.name + "2")] } }

          context "if there are no EFI partitions" do
            let(:efi_partitions) { {} }

            it "requires only a new /boot/efi partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot/efi", reuse: nil)
              )
            end
          end

          context "if there is already an EFI partition" do
            let(:efi_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

            it "requires only a reused /boot/efi partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot/efi", reuse: "/dev/sda1")
              )
            end
          end
        end

        context "with GPT partition table without a GRUB partition" do
          let(:sda_part_table) { pt_gpt }
          let(:grub_partitions) { {} }

          context "if there are no EFI partitions" do
            let(:efi_partitions) { {} }

            it "requires new /boot/efi and GRUB partitions" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(partition_id: ::Storage::ID_GPT_BIOS, reuse: nil),
                an_object_with_fields(mount_point: "/boot/efi", reuse: nil)
              )
            end
          end

          context "if there is already an EFI partition" do
            let(:efi_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

            it "requires a reused /boot/efi and a new GRUB partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(partition_id: ::Storage::ID_GPT_BIOS, reuse: nil),
                an_object_with_fields(mount_point: "/boot/efi", reuse: "/dev/sda1")
              )
            end
          end
        end

        context "with a MS-DOS partition table" do
          let(:sda_part_table) { pt_msdos }

          context "if there are no EFI partitions" do
            let(:efi_partitions) { {} }

            it "requires /boot and a new /boot/efi partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot", reuse: nil),
                an_object_with_fields(mount_point: "/boot/efi", reuse: nil)
              )
            end
          end

          context "if there is already an EFI partition" do
            let(:efi_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

            it "requires /boot and a reused /boot/efi partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot", reuse: nil),
                an_object_with_fields(mount_point: "/boot/efi", reuse: "/dev/sda1")
              )
            end
          end
        end
      end
    end

    context "not using UEFI (legacy PC)" do
      let(:efiboot) { false }

      context "with a MS-DOS partition table" do
        let(:grub_partitions) { {} }
        let(:sda_part_table) { pt_msdos }

        context "with sufficently large MBR gap" do
          context "in a partitions-based proposal" do
            let(:use_lvm) { false }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end

          context "in a LVM-based proposal" do
            let(:use_lvm) { true }

            it "requires only a /boot partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot")
              )
            end
          end
        end

        context "with too small MBR gap" do
          before do
            allow(analyzer).to receive(:mbr_gap).and_return(
              dev_sda.name => Yast::Storage::DiskSize.KiB(16)
            )
          end

          it "raises an exception" do
            expect { checker.needed_partitions }.to raise_error(
              Yast::Storage::BootRequirementsChecker::Error
            )
          end
        end

        context "with no MBR gap" do
          before do
            allow(analyzer).to receive(:mbr_gap).and_return(
              dev_sda.name => Yast::Storage::DiskSize.KiB(0)
            )
          end

          it "raises an exception" do
            expect { checker.needed_partitions }.to raise_error(
              Yast::Storage::BootRequirementsChecker::Error
            )
          end
        end
      end

      context "with GPT partition table" do
        let(:sda_part_table) { pt_gpt }

        context "if there is no GRUB partition" do
          let(:grub_partitions) { {} }

          context "in a partitions-based proposal" do
            let(:use_lvm) { false }

            it "requires a new GRUB partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(partition_id: ::Storage::ID_GPT_BIOS, reuse: nil)
              )
            end
          end

          context "in a LVM-based proposal" do
            let(:use_lvm) { true }

            it "requires a new GRUB partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(partition_id: ::Storage::ID_GPT_BIOS, reuse: nil)
              )
            end
          end
        end

        context "if there is already a GRUB partition" do
          let(:grub_partitions) { { dev_sda.name => [analyzer_part(dev_sda.name + "2")] } }

          context "in a partitions-based proposal" do
            let(:use_lvm) { false }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end

          context "in a LVM-based proposal" do
            let(:use_lvm) { true }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end
        end
      end

      context "when proposing a boot partition" do
        let(:boot_part) { find_vol("/boot", checker.needed_partitions) }
        # Default values to ensure the max num of proposed volumes
        let(:use_lvm) { true }
        let(:efi_partitions) { {} }

        include_examples "proposed boot partition"
      end

      context "when proposing an new GRUB partition" do
        let(:sda_part_table) { pt_gpt }
        let(:efiboot) { false }
        let(:grub_part) { find_vol(nil, checker.needed_partitions) }
        # Default values to ensure the max num of proposed volumes
        let(:use_lvm) { true }
        let(:grub_partitions) { {} }

        include_examples "proposed GRUB partition"
      end

      context "when proposing an new EFI partition" do
        let(:efiboot) { true }
        let(:efi_part) { find_vol("/boot/efi", checker.needed_partitions) }
        # Default values to ensure the max num of proposed volumes
        let(:use_lvm) { true }
        let(:efi_partitions) { {} }

        it "requires /boot/efi to be vfat with at least 33 MiB" do
          expect(efi_part.filesystem_type).to eq ::Storage::FsType_VFAT
          expect(efi_part.min).to eq 33.MiB
        end

        it "requires /boot/efi to be out of LVM" do
          expect(efi_part.can_live_on_logical_volume).to eq false
        end

        it "recommends /boot/efi to be 500 MiB" do
          expect(efi_part.desired).to eq 500.MiB
        end

        it "requires /boot/efi to be close enough to the beginning of disk" do
          expect(efi_part.max_start_offset).to eq 2.TiB
        end
      end
    end
  end
end
