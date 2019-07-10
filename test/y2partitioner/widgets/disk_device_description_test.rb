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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/disk_device_description"

describe Y2Partitioner::Widgets::DiskDeviceDescription do
  before { devicegraph_stub("mixed_disks.yml") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:disk) { current_graph.disks.first }

  subject { described_class.new(disk) }

  include_examples "CWM::RichText"

  describe "#init" do
    it "runs without failure" do
      expect { subject.init }.to_not raise_error
    end
  end
end
