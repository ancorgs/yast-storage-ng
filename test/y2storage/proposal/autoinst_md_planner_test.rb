#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2storage/proposal/autoinst_md_planner"
require "y2storage/autoinst_issues/list"
require "y2storage/autoinst_profile/drive_section"

describe Y2Storage::Proposal::AutoinstMdPlanner do
  using Y2Storage::Refinements::SizeCasts

  subject(:planner) { described_class.new(fake_devicegraph, issues_list) }
  let(:scenario) { "md_raid.xml" }
  let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

  before do
    fake_scenario(scenario)
  end

  describe "#planned_devices" do
    let(:drive) { Y2Storage::AutoinstProfile::DriveSection.new_from_hashes(raid) }

    let(:raid) do
      { "device" => "/dev/md", "partitions" => [home_spec] }
    end

    let(:home_spec) do
      {
        "mount" => "/home", "filesystem" => "xfs", "size" => "max", "partition_nr" => 1,
        "raid_options" => raid_options
      }
    end

    let(:raid_options) do
      { "raid_type" => "raid5" }
    end

    it "returns a planned RAID using /dev/md + partition_nr as device name" do
      md = planner.planned_devices(drive).first
      expect(md.name).to eq("/dev/md1")
    end

    it "returns a planned RAID of the wanted type" do
      md = planner.planned_devices(drive).first
      expect(md.md_level).to eq(Y2Storage::MdLevel::RAID5)
    end

    it "returns a planned RAID including filesystem settings" do
      md = planner.planned_devices(drive).first
      expect(md.mount_point).to eq("/home")
      expect(md.filesystem_type).to eq(Y2Storage::Filesystems::Type::XFS)
    end

    context "when using a named RAID" do
      let(:raid_options) do
        { "raid_name" => "/dev/md/data", "raid_type" => "raid5" }
      end

      it "uses the name instead of a number" do
        md = planner.planned_devices(drive).first
        expect(md.name).to eq("/dev/md/data")
      end
    end
  end
end