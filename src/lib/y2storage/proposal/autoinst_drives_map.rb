#!/usr/bin/env ruby
#
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

module Y2Storage
  module Proposal
    # Utility class to map disk names to the corresponding AutoYaST <drive>
    # specification that will be applied to that disk.
    class AutoinstDrivesMap
      extend Forwardable

      def_delegators :@drives, :each, :each_pair

      def initialize(devgraph, partitioning)
        # By now, consider only regular disks
        disks = partitioning.select { |i| i.fetch("type", :CT_DISK) == :CT_DISK }

        # First, assign fixed drives
        fixed_drives, flexible_drives = disks.partition { |i| i["device"] && !i["device"].empty? }
        @drives = fixed_drives.each_with_object({}) do |disk, memo|
          memo[disk["device"]] = disk
        end

        flexible_drives.each do |drive|
          disk_name = first_usable_disk(drive, devgraph)
          # TODO: what happens if there is no suitable disk?
          @drives[disk_name] = drive
        end
      end

      def disk_names
        @drives.keys
      end

    protected

      def first_usable_disk(drive_spec, devicegraph)
        skip_list = SkipList.from_profile(drive_spec.fetch("skip_list", []))

        devicegraph.disks.each do |disk|
          next if disk_names.include?(disk.name)
          next if skip_list.matches?(disk)

          return disk.name
        end
        nil
      end
    end
  end
end
