#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::AutoinstProfile::PartitioningSection do
  describe ".new_from_hashes" do
    it "returns a new PartitioningSection object" do
    end

    it "creates an entry in #drives for every valid hash in the array" do
    end

    # In fact, I don't think DriveSection.new_from_hashes can return nil, but
    # just in case...
    it "ignores hashes that couldn't be converted into DriveSection objects" do
    end
  end

  describe ".new_from_storage" do
    it "returns a new PartitioningSection object" do
    end

    it "creates an entry in #drives for every relevant disk and DASD" do
    end

    it "ignores irrelevant drives" do
    end
  end

  describe "#to_hashes" do
    it "returns an array of hashes" do
    end

    it "includes a hash for every drive" do
    end
  end
end
