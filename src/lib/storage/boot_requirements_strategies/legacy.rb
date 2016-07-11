#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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

require "storage/boot_requirements_strategies/base"

module Yast
  module Storage
    module BootRequirementsStrategies
      # Strategy to calculate the boot requirements in a legacy system (x86
      # without EFI)
      class Legacy < Base
        def needed_partitions
          volumes = super
          if mbr_gap_needed?
            mbr_gap = disk_analyzer.mbr_gap[settings.root_device]
            # fail if gap is too small
            raise Error if mbr_gap < DiskSize.KiB(256)
          end
          volumes
        end

      protected

        def grub_partition_needed?
          # Always create the partition in GPT, ignore any additional
          # requisite from Base
          root_ptable_type?(:gpt)
        end

        # only relevant for DOS partition table
        def mbr_gap_needed?
          root_ptable_type?(:msdos)
        end
      end
    end
  end
end
