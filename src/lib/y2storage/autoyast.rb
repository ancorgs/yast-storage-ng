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

require "yast"
require "y2storage/storage_manager"
require "y2storage/disk_analyzer"
# TODO: no nos dejemos esto atrás
require "byebug"

module Y2Storage
  # Class to guarrear
  class Autoyast
    include Yast::Logger

    def doit(devicegraph, partitioning)
      drives = {}

      disks = partitioning.select { |i| i.fetch("type", :CT_DISK) == :CT_DISK }
      # First, assign fixed drives
      fixed_disks, flexible_disks = disks.partition { |i| i["device"] && !i["device"].empty? }
      fixed_disks.each do |disk|
        drives[disk["device"]] = disk
      end

      flexible_disks.each do |disk|
        disk_name = first_usable_disk(disk, devicegraph, drives)
        drives[disk_name] = disk
      end

      planned_partitions = []
      drives.each do |name, description|
        disk = Disk.find_by_name(devicegraph, name)
        delete_stuff(disk, description)
        planned_partitions.concat(plan_partitions(disk, description))
      end

      # if planned_partitions.empty?
      #   Proposal con ciertas settings
      #     (no separate home, max_root = unlimited, delete_x :none...)
      #   return
      # end
      #
      # Añadir particiones necesarias para arrancar

      calculator = Proposal::PartitionsDistributionCalculator.new # lvm_helper nil
      disks = drives.map { |name, _x| Disk.find_by_name(devicegraph, name) }
      spaces = disks.map(&:free_disk_spaces).flatten
      dist = calculator.best_distribution(planned_partitions, spaces)

      part_creator = Proposal::PartitionCreator.new(devicegraph)
      part_creator.create_partitions(dist)
    end

    def first_usable_disk(disk_description, devicegraph, drives)
      devicegraph.disks.each do |disk|
        next if drives.keys.include?(disk.name)
        next if skipped?(disk_description, disk)

        return disk.name
      end
      nil
    end

    def skipped?(a, b)
      false
    end

    def delete_stuff(disk, description)
      if description["initialize"]
        disk.remove_descendants
        return
      end

      # TODO: resizing of partitions

      case description["use"]
      when "all"
        disk.partition_table.remove_descendants if disk.partition_table
      when "linux"
        # TODO, SpaceMaker#delete_unwanted_partitions cannot work in just one
        # chosen disk. Maybe refactor or copy some code
        # space_maker.send(:delete_candidates!)
      end
    end

    def plan_partitions(disk, description)
      result = []
      description["partitions"].each do
        # TODO: fix Planned::Partition.initialize
        part = Y2Storage::Planned::Partition.new(nil, nil)
        part.disk = disk.name
        # part.bootable no está en el perfil (¿existe lógica?)
        part.filesystem_type = type_for(description["filesystem"])
        part.partition_id = 131 # El que venga. Si nil, swap o linux
        if description["crypt_fs"]
          part.encryption_password = description["crypt_key"]
        end
        part.mount_point = description["mount"]

        if description["create"]
          part.label = description["label"]
          part.uuid = description["uuid"]
        else
          # TODO
          # TODO: tener en cuenta reusar PERO FORMATEANDO
          part.reuse = "/dev/sda2"
        end

        # Sizes: leave out reducing fixed sizes and 'auto'
        if description["size"].is_a_number__?
          size = DiskSize.parse(description["size"], legacy_units: true)
          part.min_size = size
          part.max_size = size
        elsif description["size"].is_percentAAAJE?
          percent = description["size"].strip[0..-1].to_f
          size = (disk.size * percent) / 100.0
          part.min_size = size
          part.max_size = size
        elsif description["size"] == "max"
          part.min_size = disk.min_grain
          part.max_size = DiskSize.unlimited
        end
        result << part
      end

      result
    end
  end
end
