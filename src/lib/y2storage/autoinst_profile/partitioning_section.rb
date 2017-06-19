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

require "yast"
require "y2storage/autoinst_profile/drive_section"

module Y2Storage
  module AutoinstProfile
    class PartitioningSection
      attr_accessor :drives

      def initialize
        @drives = []
      end

      def self.new_from_storage(devicegraph)
        result = new
        # TODO: consider also LVM, NFS and TMPFS
        result.drives = devicegraph.disk_devices.each_with_object([]) do |dev, array|
          drive = DriveSection.new_from_storage(dev)
          array << drive if drive
        end
        result
      end

      def self.new_from_hashes(drives_array)
        result = new
        result.drives = drives_array.each_with_object([]) do |hash, array|
          drive = DriveSection.new_from_hashes(hash)
          array << drive if drive
        end
        result
      end

      def to_hashes
        drives.map(&:to_hashes)
      end

      def disk_drives
        drives.select { |drive| drive.type == :CT_DISK }
      end
    end
  end
end
