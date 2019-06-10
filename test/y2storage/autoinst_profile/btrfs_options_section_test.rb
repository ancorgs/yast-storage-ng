#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../spec_helper"
require_relative "#{TEST_PATH}/support/autoinst_profile_sections_examples"
require "y2storage"

describe Y2Storage::AutoinstProfile::BtrfsOptionsSection do
  include_examples "autoinst section"

  let(:spec) do
    {
      "data_raid_level"     => "single",
      "metadata_raid_level" => "raid1"
    }
  end

  describe ".new_from_hashes" do
    subject { described_class.new_from_hashes(spec) }

    it "initializes data_raid_level" do
      expect(subject.data_raid_level).to eq("single")
    end

    it "initializes metadata_raid_level" do
      expect(subject.metadata_raid_level).to eq("raid1")
    end

    context "when data_raid_level is not specified" do
      let(:spec) { {} }

      it "sets data_raid_level to nil" do
        expect(subject.data_raid_level).to be_nil
      end
    end

    context "when metadata_raid_level is not specified" do
      let(:spec) { {} }

      it "sets metadata_raid_level to nil" do
        expect(subject.metadata_raid_level).to be_nil
      end
    end
  end

  describe ".new_from_storage" do
    subject(:section) { described_class.new_from_storage(filesystem) }

    let(:filesystem) do
      instance_double(
        Y2Storage::Filesystems::Btrfs,
        data_raid_level:     Y2Storage::BtrfsRaidLevel::RAID1,
        metadata_raid_level: Y2Storage::BtrfsRaidLevel::SINGLE
      )
    end

    it "initializes data_raid_level" do
      expect(section.data_raid_level).to eq("raid1")
    end

    it "initializes metadata_raid_level" do
      expect(section.metadata_raid_level).to eq("single")
    end
  end
end
