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

require "yast"
require "storage"
require "y2storage/simple_etc_crypttab_entry"

module Y2Storage
  # Class to represent a crypttab file
  class Crypttab
    include Yast::Logger

    CRYPTTAB_PATH = "/etc/crypttab"
    private_constant :CRYPTTAB_PATH

    # @return [Filesystems::Base] filesystem to which the crypttab file belongs to
    attr_reader :filesystem

    # @return [Array<SimpleEtcCrypttabEntry>]
    attr_reader :entries

    # Constructor
    #
    # @param path [String] path to crypttab file
    # @param filesystem [Filesystems::Base]
    def initialize(path = CRYPTTAB_PATH, filesystem = nil)
      @path = path
      @filesystem = filesystem
      @entries = read_entries
    end

    private

    # @return [String] crypttab file path
    attr_reader :path

    # Reads a crypttab file and returns its entries
    #
    # @return [Array<SimpleEtcCrypttabEntry>]
    def read_entries
      entries = Storage.read_simple_etc_crypttab(path)
      entries.map { |e| SimpleEtcCrypttabEntry.new(e) }
    rescue Storage::Exception
      log.error("Not possible to read the crypttab file: #{path}")
      []
    end
  end
end
