# Copyright (c) [2019] SUSE LLC
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

require "fileutils"
require "yast2/execute"
require "y2storage/encryption_processes/secure_key_volume"

module Y2Storage
  module EncryptionProcesses
    # Class representing the secure AES keys managed by the Crypto Express CCA
    # coprocessors found in the system.
    #
    # For more information, see
    # https://www.ibm.com/support/knowledgecenter/linuxonibm/com.ibm.linux.z.lxdc/lxdc_zkey_reference.html
    class SecureKey
      # Location of the zkey command
      ZKEY = "/usr/bin/zkey".freeze
      # Location of the lszcrypt command
      LSZCRYPT = "/sbin/lszcrypt".freeze
      private_constant :ZKEY, :LSZCRYPT
      ZKEY_CONFIG_DIR = "/etc/zkey"

      # @return [String] name of the secure key
      attr_reader :name

      # Constructor
      #
      # @note: creating a SecureKey object does not generate a new record for it
      # in the keys database. See {#generate}.
      #
      # @param name [String] see {#name}
      def initialize(name)
        @name = name
        @volume_entries = []
      end

      # Whether the key contains an entry in its list of volumes referencing the
      # given device
      #
      # @param device [BlkDevice, Encryption] it can be the plain device being
      #   encrypted or the resulting encryption device
      # @return [Boolean]
      def for_device?(device)
        !!volume_entry(device)
      end

      # DeviceMapper name registered in this key for the given device
      #
      # @param device [BlkDevice, Encryption] it can be the plain device being
      #   encrypted or the resulting encryption device
      # @return [String, nil] nil if the current key contain no information
      #   about the device or whether it does not specify a DeviceMapper name
      #   for it
      def dm_name(device)
        volume_entry(device)&.dm_name
      end

      # For the given device, name with which the plain device is registered
      # in this key
      #
      # @param device [BlkDevice, Encryption] it can be the plain device being
      #   encrypted or the resulting encryption device
      # @return [String, nil] nil if the current key contain no information
      #   about the device
      def plain_name(device)
        volume_entry(device)&.plain_name
      end

      # Adds the given device to the list of volumes registered for this key
      #
      # @note This only modifies the current object in memory, it does not imply
      #   saving the volume entry in the keys database.
      #
      # @param device [Encryption]
      def add_device(device)
        @volume_entries << SecureKeyVolume.new_from_encryption(device)
      end

      # Registers the key in the keys database by invoking "zkey generate"
      #
      # The generated key will have the name and the list of volumes from this
      # object. The rest of attributes will be set at the convenient values for
      # pervasive LUKS2 encryption.
      def generate
        args = [
          "--name", name,
          "--xts",
          "--keybits", "256",
          "--volume-type", "LUKS2",
          "--sector-size", "4096"
        ]
        args += ["--volumes", volume_entries.map(&:to_s).join(",")] if volume_entries.any?

        Yast::Execute.locally(ZKEY, "generate", *args)
      end

      # Parses the representation of a secure key, in the format used by
      # "zkey list", and adds the corresponding volume entries to the list of
      # volumes registered for this key
      #
      # @note This only modifies the current object in memory, it does not imply
      #   saving the volume entries in the keys database.
      #
      # @param string [String] portion of the output of "zkey list" that
      #   represents a concrete secure key
      def add_zkey_volumes(string)
        # TODO: likely this method could be better implemented with
        # StringScanner

        vol_pattern = "\s+\/[^\s]*\s*\n"
        match_data = /\s* Volumes\s+:((#{vol_pattern})+)/.match(string)
        return [] unless match_data

        volumes_str = match_data[1]
        volumes = volumes_str.split("\n").map(&:strip)

        @volume_entries += volumes.map { |str| SecureKeyVolume.new_from_str(str) }
      end

      private

      # @return [Array<SecureKeyVolume>] entries in the "volumes" section of
      #   this key
      attr_accessor :volume_entries

      # Volume entry associated to the given device
      #
      # @param device [BlkDevice, Encryption] it can be the plain device being
      #   encrypted or the resulting encryption device
      # @return [SecureKeyVolume, nil] nil if this key is not associated to the
      #   device
      def volume_entry(device)
        volume_entries.find { |vol| vol.match_device?(device) }
      end

      class << self
        # Whether it's possible to use secure AES keys in this system
        #
        # @return [Boolean]
        def available?
          device_list = Yast::Execute.locally!(LSZCRYPT, "--verbose", stdout: :capture)
          device_list&.match?(/\sonline\s/) || false
        rescue StandardError
          false
        end

        # Registers a new secure key in the system's key database
        #
        # The name of the resulting key may be different (a numbered suffix is
        # added) if the given name is already taken.
        #
        # @param name [String] temptative name for the new key
        # @param volumes [Array<Encryption>] encryption devices to register in
        #   the "volumes" section of the new key
        # @return [SecureKey] an object representing the new key
        def generate(name, volumes: [])
          name = exclusive_name(name)
          key = new(name)
          volumes.each { |vol| key.add_device(vol) }
          key.generate
          key
        end

        # Finds an existing secure key that references the given device in
        # one of its "volumes" entries
        #
        # @return [SecureKey, nil] nil if no key is found for the device
        def for_device(device)
          all.find { |key| key.for_device?(device) }
        end

        def copy_repository(destdir)
          if File.exist?(credentials_d) && destdir != "/"
            log.warn "bla"
            return
          end

          target = File.join(destdir, zkey_directory)
          log.info "Copying zkey repository to #{target}"
          FileUtils.cp_r(zkey_directory, target, preserve: true, remove_destination: true)
        end

        private

        # All secure keys registered in the system
        #
        # @return [Array<SecureKey>]
        def all
          output = Yast::Execute.locally(ZKEY, "list", stdout: :capture)
          return [] if output&.empty?

          entries = output&.split("\n\n") || []
          entries.map { |entry| new_from_zkey(entry) }
        end

        # Parses the representation of a secure key, in the format used by
        # "zkey list", and returns a SecureKey object representing it
        #
        # @param string [String] portion of the output of "zkey list" that
        #   represents a concrete secure key
        def new_from_zkey(string)
          lines = string.lines
          name = lines.first.strip.split(/\s/).last
          key = new(name)
          key.add_zkey_volumes(string)
          key
        end

        # Returns the name that is available for a new key taking original_name
        # as a base. If the name is already taken by an existing key in the
        # system, the returned name will have a number appended.
        #
        # @param original_name [String]
        # @return [String]
        def exclusive_name(original_name)
          existing_names = all.map(&:name)
          return original_name unless existing_names.include?(original_name)

          suffix = 0
          name = "#{original_name}_#{suffix}"
          while existing_names.include?(name)
            suffix += 1
            name = "#{original_name}_#{suffix}"
          end
          name
        end
      end
    end
  end
end
