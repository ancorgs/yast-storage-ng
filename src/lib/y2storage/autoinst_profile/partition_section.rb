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
require "y2storage/autoinst_profile/section_with_attributes"

module Y2Storage
  module AutoinstProfile
    class PartitionSection < SectionWithAttributes
      # Literal historically used at AutoinstPartPlan
      CRYPT_KEY_VALUE = "ENTER KEY HERE"
      private_constant :CRYPT_KEY_VALUE

      # Partitions with these IDs are historically marked with format=false
      # NOTE: "Dell Utility" was included here, but there is no such ID in the
      # new libstorage.
      NO_FORMAT_IDS = [PartitionId::PREP, PartitionId::DOS16]
      private_constant :NO_FORMAT_IDS

      # Partitions with these IDs are historically marked with create=false
      # NOTE: "Dell Utility" was the only entry here. See above.
      NO_CREATE_IDS = []
      private_constant :NO_CREATE_IDS

      def self.attributes
        [
          {name: :create},
          {name: :filesystem},
          {name: :format},
          {name: :label},
          {name: :uuid},
          {name: :lv_name},
          {name: :lvm_group},
          {name: :mount},
          {name: :mountby},
          {name: :filesystem},
          {name: :partition_id},
          {name: :partition_nr},
          {name: :partition_type},
          {name: :subvolumes},
          {name: :size},
          {name: :crypt_fs},
          {name: :loop_fs},
          {name: :crypt_key}
        ]
      end

      define_attr_accessors

      def initialize
        @subvolumes = []
      end

      def self.new_from_storage(device)
        result = new
        initialized = result.init_from_partition(device)
        initialized ? result : nil
      end

      def init_from_partition(partition)
        @create = !NO_CREATE_IDS.include?(partition.id)
        @partition_nr = partition.number
        @partition_type = "primary" if partition.type.is?(:primary)
        @partition_id = partition_id_from(partition)

        init_encryption_fields(partition)
        init_filesystem_fields(partition)

        # NOTE: The old AutoYaST exporter does not report the real size here.
        # It intentionally reports one cylinder less. Cylinders is an obsolete
        # unit (that equals to 8225280 bytes in my experiments).
        # According to the comments there, that was done due to bnc#415005 and
        # bnc#262535.
        @size = partition.size.to_i.to_s if create

        true
      end

      def type_for_filesystem
        return nil unless filesystem
        Filesystems::Type.find(filesystem)
      end

      def id_for_partition
        return PartitionId.new_from_legacy(partition_id) if partition_id
        return PartitionId::SWAP if type_for_filesystem && type_for_filesystem.is?(:swap)
        PartitionId::LINUX
      end

    protected

      # Uses legacy ids for backwards compatibility. For example, BIOS Boot
      # partitions in the old libstorage were represented by the internal
      # code 259 and, thus, systems cloned with the old exporter
      # (AutoinstPartPlan) use 259 instead of the current 257.
      def partition_id_from(partition)
        id = enforce_bios_boot?(partition) ? PartitionId::BIOS_BOOT : partition.id
        id.to_i_legacy
      end

      def init_encryption_fields(partition)
        return unless partition.encrypted?

        @crypt_fs = true
        @loop_fs = true
        @crypt_key = CRYPT_KEY_VALUE
      end

      def init_filesystem_fields(partition)
        @format = false
        fs = partition.filesystem
        return unless fs

        @format = true unless NO_FORMAT_IDS.include?(partition.id)
        @filesystem = fs.type.to_sym
        @label = fs.label unless fs.label.empty?
        @mount = fs.mountpoint if fs.mountpoint && !fs.mountpoint.empty?
        @fstab_options = fs.fstab_options.join(",") unless fs.fstab_options.empty?
        @mkfs_options = fs.mkfs_options unless fs.mkfs_options.empty?
        @mountby = fs.mount_by.to_sym
      end

      # Whether the given existing partition should be reported as GRUB (GPT
      # Bios Boot) in the cloned profile.
      #
      # NOTE: to ensure backward compatibility, this method implements the
      # logic present in the old AutoYaST exporter (that used to live in
      # AutoinstPartPlan#ReadHelper). So it returns true for any partition with
      # a Windows-related ID that is configured to be mounted in /boot*
      # See commit 54e236cd428636b3bf8f92d2ac2914e5b1d67a90
      #
      # @param partition [Y2Storage::Partition]
      # @return [Boolean]
      def enforce_bios_boot?(partition)
        return false if partition.filesystem_mountpoint.nil?
        partition.id.is?(:windows_system) && partition.filesystem_mountpoint.include?("/boot")
      end
    end
  end
end
