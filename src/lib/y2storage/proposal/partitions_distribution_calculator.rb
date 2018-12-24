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

require "yast"
require "storage"
require "y2storage/disk_size"
require "y2storage/planned"
require "y2storage/proposal/phys_vol_calculator"

module Y2Storage
  module Proposal
    # Class to find the optimal distribution of planned partitions into the
    # existing disk spaces
    class PartitionsDistributionCalculator
      include Yast::Logger

      def initialize(lvm_helper = nil)
        @lvm_helper = lvm_helper
      end

      # Best possible distribution, nil if the planned partitions don't fit
      #
      # If it's necessary to provide LVM space (according to lvm_helper),
      # the result will include one or several extra planned partitions to host
      # the LVM physical volumes that need to be created in order to reach
      # that size (within the max limits provided by lvm_helper).
      #
      # @param partitions [Array<Planned::Partition>]
      # @param spaces [Array<FreeDiskSpace>]
      #
      # @return [Planned::PartitionsDistribution]
      def best_distribution(partitions, spaces)
        log.info "Calculating best space distribution for #{partitions.inspect}"
        # First, make sure the whole attempt makes sense
        return nil if impossible?(partitions, spaces)

        begin
          dist_hashes = distribute_partitions(partitions, spaces)
        rescue NoDiskSpaceError
          return nil
        end
        candidates = distributions_from_hashes(dist_hashes)

        if lvm?
          log.info "Calculate LVM posibilities for the #{candidates.size} candidate distributions"
          pv_calculator = PhysVolCalculator.new(spaces, lvm_helper)
          candidates.map! { |dist| pv_calculator.add_physical_volumes(dist) }
        end
        candidates.compact!

        best_candidate(candidates)
      end

      def distribute_partitions(partitions, spaces)
        log.info "Selecting the candidate spaces for each planned partition"
        disk_spaces_by_part = candidate_disk_spaces(partitions, spaces)

        log.info "Calculate all the possible distributions of planned partitions into spaces"
        dist_hashes = distribution_hashes(disk_spaces_by_part)
        add_unused_spaces(dist_hashes, spaces)
        dist_hashes
      end

      # Space that should be freed when resizing an existing partition in
      # order to have a good chance of creating a valid PartitionsDistribution
      # (by means of #best_distribution).
      #
      # Used when resizing windows in order to know how much space to remove
      # from the partition, although it's an oversimplyfication because being
      # able to generate a valid distribution is not just a matter of size.
      #
      # @param partition [Partition] partition to resize
      # @param planned_partitions [Array<Planned::Partition>] planned
      #     partitions to make space for
      # @param free_spaces [Array<FreeDiskSpace>] all free spaces in the system
      # @return [DiskSize]
      def resizing_size(partition, planned_partitions, free_spaces)
        # We are going to resize this partition only once, so let's assume the
        # worst case:
        #  - several planned partitions (and maybe one of the new PVs) will
        #    be logical
        #  - resizing produces a new space
        #  - the LVM must be spread among all the available spaces
        align_grain = partition.partition_table.align_grain
        needed = DiskSize.sum(planned_partitions.map(&:min), rounding: align_grain)

        disk = partition.partitionable
        max_logical = max_logical(disk, planned_partitions)
        needed += Planned::AssignedSpace.overhead_of_logical(disk) * max_logical

        if lvm?
          pvs_to_create = free_spaces.size + 1
          needed += lvm_space_to_make(pvs_to_create)
        end

        # The exact amount of available free space is hard to predict.
        #
        # Resizing can introduce a misaligned free space blob. Take this
        # into account by reducing the free space by the disk's alignment
        # granularity. This is slightly too pessimistic (we could check the
        # alignment) - but good enough.
        #
        # A good example of such a block is the free space at the end of a
        # GPT which is practically guaranteed to be misaligned due to the
        # GPT meta data stored at the disk's end.
        #
        available = [available_space(free_spaces) - align_grain, DiskSize.zero].max

        needed - available
      end

      # NOTE: ahora mismo estoy considerando que el redimensionado da lugar a un
      # nuevo espacio. Habría que añadir un test para casos en que no es así.
      def resizing2(partition, planned_partitions, free_spaces)
        # We are going to resize this partition only once, so let's assume the
        # worst case:
        #  - resizing produces a new space
        #  - several planned partitions (and maybe one of the new PVs) will
        #    be logical
        #  - the LVM must be spread among all the available spaces
        ptable = partition.partition_table
        grain = ptable.align_grain
        overhead_of_logical = Planned::AssignedSpace.overhead_of_logical(ptable.partitionable)

        planned_in_space = parts_in_new_space(planned_partitions, free_spaces, grain)
        needed = DiskSize.sum(planned_in_space.map(&:min), rounding: grain)

        if ptable.extended_possible?
          # If the space is not actually new (it gets added to an existing one),
          # this number can be bigger
          max_logical_count = planned_in_space.size
          max_logical_count += 1 unless lvm_helper.missing_space.zero?
          needed += overhead_of_logical * max_logical_count
        end

        if lvm?
          pvs_to_create = free_spaces.size + 1
          needed += lvm_space_to_make(pvs_to_create)
        end

        # Resizing can introduce a misaligned free space blob.
        # A good example of such a block is the free space at the end of a
        # GPT which is practically guaranteed to be misaligned due to the
        # GPT meta data stored at the disk's end.
        needed += grain
        needed
      end

      def resizing3(partition, planned_partitions, free_spaces)
        # Estas dos hacen falta?
        ptable = partition.partition_table
        grain = ptable.align_grain

        all_spaces = add_or_mark(free_spaces, partition)
        all_planned =
          if lvm?
            # In the LVM case, assume there will be only one big PV, so we have to
            # make room for it as well.
            planned_partitions + [new_pv]
          else
            planned_partitions
          end

        begin
          dist_hashes = distribute_partitions(all_planned, all_spaces)
        rescue NoDiskSpaceError
          return partition.size
        end

        # Group all the distributions based on the partitions assigned
        # to the new space
        alternatives_for_new_space = group_dist_hashes_by_new_space2(dist_hashes)

        sorted_keys = alternatives_for_new_space.keys.sort do |parts_in_a, parts_in_b|
          compare_planned_parts_sets_size(parts_in_a, parts_in_b, grain)
        end

        sorted_keys.each do |parts|
          distros = distributions_from_hashes(alternatives_for_new_space[parts])
          next if distros.empty?

          assigned = distros.map {|i| i.spaces.find {|a| a.disk_space.growing? } }


          pepe = assigned.map(&:nueva_mierda).min
          the_growing = all_spaces.find(&:growing?)
          result = pepe + the_growing.region.end_overhead(grain) # por la alineación
          if the_growing.region != partition.region
            result -= the_growing.disk_size
          end
          return result
        end

        partition.size
      end

      def add_or_mark(free_spaces, partition)
        result = free_spaces.map do |space|
          if space.disk == partition.disk && space.region.start == partition.region.end + 1
            new_space = space.dup
            new_space.growing = true
            new_space
          else
            space
          end
        end
        if result.none?(&:growing?)
          # Use partition.region.... because we have to use something
          # Maybe we could create a super-small region at the end of the
          # partition...
          new_space = FreeDiskSpace.new(partition.disk, partition.region)
          new_space.growing = true
          result << new_space
        end
        result
      end

      def new_pv
        res = Planned::Partition.new(nil)
        res.min_size = lvm_space_to_make(1)
        res
      end

      def parts_in_new_space(planned_partitions, spaces, align_grain)
        ### Worst case, all the partitions that can end up in this disk will do so
        ### and will be candidates to be logical
        ###max_partitions = planned_partitions.select { |v| v.disk.nil? || v.disk == disk.name }

        return planned_partitions if spaces.empty?

        spaces_by_part = candidate_disk_spaces(planned_partitions, spaces, raise_if_empty: false)
        spaces_by_part.values.each { |spaces| spaces << :future_new_space }
        dist_hashes = distribution_hashes(spaces_by_part)

        # Group all the distributions for which the content of :future_new_space
        # is the same
        alternatives_for_new_space = group_dist_hashes_by_new_space(dist_hashes, :future_new_space)

        sorted_keys = alternatives_for_new_space.keys.sort do |parts_in_a, parts_in_b|
          compare_planned_parts_sets_size(parts_in_a, parts_in_b, align_grain)
        end

        sorted_keys.each do |parts|
          # Actually, introducing "parts" into the mix could invalidate a
          # distribution considered valid right now
          return parts if any_valid_distribution?(alternatives_for_new_space[parts])
        end

        planned_partitions
      end

      def compare_planned_parts_sets_size(parts_a, parts_b, align_grain)
        size_in_a = DiskSize.sum(parts_a.map(&:min), rounding: align_grain)
        size_in_b = DiskSize.sum(parts_b.map(&:min), rounding: align_grain)
        result_by_size = size_in_a <=> size_in_b
        return result_by_size unless result_by_size.zero?

        # Fallback to guarantee stable sorting
        ids_in_a = parts_a.map(&:planned_id).join
        ids_in_b = parts_b.map(&:planned_id).join
        ids_in_a <=> ids_in_b
      end

      def group_dist_hashes_by_new_space(dist_hashes, marker)
        result = {}
        dist_hashes.each do |dist|
          key = dist[marker]
          result[key] ||= []
          result[key] << dist
          dist.delete(marker)
        end
        result
      end

      def group_dist_hashes_by_new_space2(dist_hashes)
        result = {}
        dist_hashes.each do |dist|
          key = dist.find {|k, v| k.growing? }.last
          result[key] ||= []
          result[key] << dist
        end
        result
      end

      def any_valid_distribution?(dist_hashes)
        dist_hashes.any? do |dist_hash|
          begin
            Planned::PartitionsDistribution.new(dist_hash)
            true
          rescue Error
            false
          end
        end
      end

    protected

      # @return [Proposal::LvmHelper, nil] nil if LVM is not involved
      attr_reader :lvm_helper

      # Whether LVM should be taken into account
      #
      # @return [Boolean]
      def lvm?
        !!(lvm_helper && lvm_helper.missing_space > DiskSize.zero)
      end

      # Checks whether there is any chance of producing a valid
      # PartitionsDistribution to accomodate the planned partitions and the
      # missing LVM part in the free spaces
      def impossible?(planned_partitions, free_spaces)
        needed = DiskSize.sum(planned_partitions.map(&:min))
        if lvm?
          # Let's assume the best possible case - if we need to create a PV it
          # will be only one
          pvs_to_create = 1
          needed += lvm_space_to_make(pvs_to_create)
        end
        needed > available_space(free_spaces)
      end

      # Space that needs to be dedicated to new physical volumes in order to
      # have a chance to calculate an acceptable space distribution. The result
      # depends on the number of PV that would be created, since every PV
      # introduces an overhead.
      #
      # @param new_pvs [Integer] max number of PVs that would be created,
      #     if needed. This is by definition an estimation (you never know the
      #     exact number of PVs until you calculate the space distribution)
      # @return [DiskSize]
      def lvm_space_to_make(new_pvs)
        return DiskSize.zero unless lvm?
        lvm_helper.missing_space + lvm_helper.useless_pv_space * new_pvs
      end

      # Returns the sum of available spaces
      #
      # @param free_spaces [Array<FreeDiskSpace>] List of free disk spaces
      # @return [DiskSize] Available disk space
      #
      # NOTE: growing?
      def available_space(free_spaces)
        DiskSize.sum(free_spaces.map(&:disk_size))
      end

      # For each planned partition, it returns a list of the disk spaces
      # that could potentially host it.
      #
      # Of course, each disk space can appear on several lists.
      #
      # @param planned_partitions [Array<Planned::Partition>]
      # @param free_spaces [Array<FreeDiskSpace>]
      # @param raise_if_empty [Boolean] raise a {NoDiskSpaceError} if there is
      #   any planned partition that doesn't fit in any of the spaces
      # @return [Hash{Planned::Partition => Array<FreeDiskSpace>}]
      def candidate_disk_spaces(planned_partitions, free_spaces, raise_if_empty: true)
        planned_partitions.each_with_object({}) do |partition, hash|
          spaces = free_spaces.select { |space| suitable_disk_space?(space, partition) }
          if spaces.empty? && raise_if_empty
            log.error "No suitable free space for #{partition}"
            raise NoDiskSpaceError, "No suitable free space for the planned partition"
          end
          hash[partition] = spaces
        end
      end

      # All possible combinations of spaces and planned partitions.
      #
      # The result is an array in which each entry represents a potential
      # distribution of partitions into spaces taking into account the
      # restrictions set by disk_spaces_by_partition.
      #
      # @param disk_spaces_by_partition [Hash{Planned::Partition => Array<FreeDiskSpace>}]
      #     which spaces are acceptable for each planned partition
      # @return [Array<Hash{FreeDiskSpace => <Planned::Partition>}>]
      def distribution_hashes(disk_spaces_by_partition)
        return [{}] if disk_spaces_by_partition.empty?

        hash_product(disk_spaces_by_partition).map do |combination|
          # combination looks like this
          # {partition1 => space1, partition2 => space1, partition3 => space2 ...}
          inverse_hash(combination)
        end
      end

      def suitable_disk_space?(space, partition)
        return false if partition.disk && partition.disk != space.disk_name
        return false unless pepe(space, partition)
        max_offset = partition.max_start_offset
        return false if max_offset && space.start_offset > max_offset
        true
      end

      def pepe(space, partition)
        space.growing? ? true : space.disk_size >= partition.min_size
      end

      # Cartesian product (that is, all the possible combinations) of hash
      # whose values are arrays.
      #
      # @example
      #   hash = {
      #     vol1: [:space1, :space2],
      #     vol2: [:space1],
      #     vol3: [:space2, :space3]
      #   }
      #   hash_product(hash) #=>
      #   # [
      #   #  {vol1: :space1, vol2: :space1, vol3: :space2},
      #   #  {vol1: :space1, vol2: :space1, vol3: :space3},
      #   #  {vol1: :space2, vol2: :space1, vol3: :space2},
      #   #  {vol1: :space2, vol2: :space1, vol3: :space3}
      #   # ]
      #
      # @param hash [Hash{Object => Array}]
      # @return [Array<Hash>]
      def hash_product(hash)
        keys = hash.keys
        # Ensure same order
        arrays = keys.map { |key| hash[key] }
        product = arrays[0].product(*arrays[1..-1])
        product.map { |p| Hash[keys.zip(p)] }
      end

      # Inverts keys and values of a hash
      #
      # @example
      #   hash = {vol1: :space1, vol2: :space1, vol3: :space2}
      #   inverse_hash(hash) #=> {space1: [:vol1, :vol2], space2: [:vol3]}
      #
      # @return [Hash] original values as keys and arrays of original
      #     keys as values
      def inverse_hash(hash)
        hash.each_with_object({}) do |(key, value), out|
          out[value] ||= []
          out[value] << key
        end
      end

      # Transforms a set of hashes containing tentative partition distributions
      # into proper {Planned::PartitionsDistribution} objects.
      #
      # Hashes describing invalid distributions are discarded, so the resulting
      # array can have less elements than the original list.
      #
      # @param dist_hashes [Array<Hash{FreeDiskSpace => Array<Planned::Partition>}>]
      # @return [Array<Planned::PartitionsDistribution>]
      def distributions_from_hashes(dist_hashes)
        dist_hashes.each_with_object([]) do |distribution_hash, array|
          begin
            dist = Planned::PartitionsDistribution.new(distribution_hash)
          rescue Error
            next
          end
          array << dist
        end
      end

      # Best partitions distribution
      #
      # @param candidates [Array<Planned::PartitionsDistribution>]
      # @return [Planned::PartitionsDistribution]
      def best_candidate(candidates)
        log.info "Comparing #{candidates.size} distributions"
        result = candidates.sort { |a, b| a.better_than(b) }.first
        log.info "best_for result: #{result}"
        result
      end

      # Add unused spaces to a distributions hash
      #
      # @param dist_hashes [Array<Hash{FreeDiskSpace => <Planned::Partition>}>]
      #   Distribution hashes
      # @param spaces      [Array<FreeDiskSpace>] Free spaces
      # @return [Array<Hash{FreeDiskSpace => <Planned::Partition>}>]
      #   Distribution hashes considering all free disk spaces.
      def add_unused_spaces(dist_hashes, spaces)
        spaces_hash = Hash[spaces.product([[]])]
        dist_hashes.map! { |d| spaces_hash.merge(d) }
      end
    end
  end
end
