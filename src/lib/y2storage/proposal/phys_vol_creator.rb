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

require "y2storage/disk_size"
require "byebug"

module Y2Storage
  class Proposal
    # TODO
    #
    # Used by SpaceDistribution to propose all the possibilities of creating
    # physical volumes.
    class PhysVolCreator

      # Initialize.
      #
      # @param lvm_helper [Proposal::LvmHelper] contains information about the
      #     LVM planned volumes and how to make space for them
      def initialize(lvm_helper)
        @lvm_helper = lvm_helper
      end

      # TODO
      #
      # All possible distributions of physical volumes in a given set of disk
      # spaces.
      #
      # NOTE: in partition tables without restrictions (no MS-DOS), we
      # could limit the options we need to explore. Take that into account if
      # perfomance becomes a problem.
      #
      # @param space_sizes [Hash{FreeDiskSpace => DiskSize}] As keys, all the
      #     spaces that could potentially contain a PV. As values the max size
      #     of such PV, since some space could already be reserved for other
      #     (no LVM) planned volumes.
      # @param lvm_helper [Proposal::LvmHelper]
      #
      # @return [Array<PhysVolDistribution>]
      def distributions_for(distribution, all_spaces)
        all_spaces.permutation.each_with_object([]) do |sorted_spaces, result|
          new_dist = processed(distribution, sorted_spaces)
          next unless new_dist
          result << new_dist unless result.include?(distribution)
        end
      end

    protected

      attr_reader :lvm_helper

      # Returns a new PhysVolDistribution created by assigning a physical volume
      # to each space, following the given order, until the goal is reached.
      #
      # Returns nil if it's not possible to create a distribution of physical
      # volumes that guarantees the requirements set by lvm_helper.
      #
      # @param sorted_spaces [Array<FreeDiskSpace>]
      # @param max_sizes [Hash{FreeDiskSpace => DiskSize}] for every space,
      #     the max size usable for creating a physical volume
      # @param lvm_helper [Proposal::LvmHelper]
      #
      # @return [PhysVolDistribution, nil]
      #def new_for_order(sorted_spaces, max_sizes, lvm_helper)
      def processed(distribution, sorted_spaces)
        volumes = {}
        missing_size = lvm_helper.missing_space
        result = nil

        sorted_spaces.each do |space|
          available_size = estimated_available_size(space, distribution)
          next unless available_size > lvm_helper.min_pv_size

          pv_vol = new_planned_volume(lvm_helper.min_pv_size)
          volumes[space] = pv_vol
          useful_space = lvm_helper.useful_pv_space(available_size)

          if useful_space < missing_size
            # Still not enough, let's assume we will use the whole space
            missing_size -= useful_space
          else
            # This space is, hopefully, the last one we need to fill.
            # Let's consolidate and check if it was indeed enough
            begin
              result = distribution.add_volumes(volumes)
            rescue
              # Adding PVs in this order leads to an invalid distribution
              return nil
            end
            if potential_lvm_size(result) >= lvm_helper.missing_space
              # We did it
              adjust_sizes(result, space)
              adjust_weights(result)
              break
            else
              # Our estimation was too optimistic. The overhead of logical
              # partitions fooled us. Let's keep trying.
              missing_size -= useful_space
              result = nil
            end
          end
        end

        result
      end

      def estimated_available_size(space, distribution)
        assigned_space = distribution.space_at(space)
        return space.disk_size unless assigned_space

        size = assigned_space.extra_size
        size -= assigned_space.overhead_of_logical if assigned_space.partition_type == :logical
        # If partition_type is nil there is still a chance of logical
        # overhead, but we cannot know in advance
        size
      end

      def potential_lvm_size(distribution)
        total = DiskSize.zero
        distribution.spaces.each do |space|
          pv_vol = space.volumes.detect { |v| v.partition_id == Storage::ID_LVM }
          next unless pv_vol

          usable_size = space.usable_extra_size + pv_vol.min_disk_size
          total += lvm_helper.useful_pv_space(usable_size)
        end
        total
      end

      # Volume representing a LVM physical volume
      #
      # @return [PlannedVolume]
      def new_planned_volume(size)
        res = PlannedVolume.new(nil)
        res.partition_id = Storage::ID_LVM
        res.min_disk_size = res.desired_disk_size = size
        res
      end

      def adjust_sizes(distribution, last_disk_space)
        missing_size = lvm_helper.missing_space

        distribution.spaces.each do |space|
          pv_vol = space.volumes.detect { |v| v.partition_id == Storage::ID_LVM }
          next unless pv_vol
          next if space.disk_space == last_disk_space

          usable_size = space.usable_extra_size + pv_vol.min_disk_size
          pv_vol.min_disk_size = pv_vol.desired_disk_size = usable_size
          pv_vol.max_disk_size = usable_size
          missing_size -= lvm_helper.useful_pv_space(usable_size)
        end

        space = distribution.space_at(last_disk_space)
        pv_vol = space.volumes.detect { |s| s.partition_id == Storage::ID_LVM }
        pv_size = lvm_helper.real_pv_size(missing_size)
        pv_vol.min_disk_size = pv_vol.desired_disk_size = pv_size

        other_pvs_size = lvm_helper.missing_space - missing_size
        pv_vol.max_disk_size = lvm_helper.real_pv_size(lvm_helper.max_extra_space - other_pvs_size)
      end

      def adjust_weights(distribution)
        distribution.spaces.each do |space|
          pv_vol = space.volumes.detect { |v| v.partition_id == Storage::ID_LVM }
          next unless pv_vol
          
          other_volumes = space.volumes.reject { |v| v == pv_vol }
          pv_vol.weight = other_volumes.map(&:weight).reduce(0, :+)
          pv_vol.weight = 1 if pv_vol.weight.zero?
        end
      end
    end
  end
end
