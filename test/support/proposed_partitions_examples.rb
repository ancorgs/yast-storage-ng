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

require "storage/refinements/size_casts"

RSpec.shared_examples "proposed boot partition" do
  using Yast::Storage::Refinements::SizeCasts

  it "requires /boot to be ext4 with at least 100 MiB" do
    expect(boot_part.filesystem_type).to eq ::Storage::FsType_EXT4
    expect(boot_part.min).to eq 100.MiB
  end

  it "requires /boot to be in the system disk out of LVM" do
    expect(boot_part.disk).to eq root_device
    expect(boot_part.can_live_on_logical_volume).to eq false
  end

  it "recommends /boot to be 200 MiB" do
    expect(boot_part.desired).to eq 200.MiB
  end
end

RSpec.shared_examples "proposed GRUB partition" do
  using Yast::Storage::Refinements::SizeCasts

  it "requires it to have the correct id" do
    expect(grub_part.partition_id).to eq ::Storage::ID_GPT_BIOS
  end

  it "requires it to be out of LVM" do
    expect(grub_part.can_live_on_logical_volume).to eq false
  end

  it "requires it to be between 256KiB and 8MiB, despite the alignment" do
    expect(grub_part.min).to eq 256.KiB
    expect(grub_part.max).to eq 8.MiB
    expect(grub_part.align).to eq :keep_size
  end

  it "recommends it to be 1 MiB" do
    expect(grub_part.desired).to eq 1.MiB
  end
end
