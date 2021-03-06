# Copyright (c) [2020-2021] SUSE LLC
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

require "yast2/popup"
require "y2partitioner/ui_state"
require "y2partitioner/actions/delete_device"

module Y2Partitioner
  module Actions
    # Action for deleting a Btrfs subvolume
    #
    # @see DeleteDevice
    class DeleteBtrfsSubvolume < DeleteDevice
      def initialize(*args)
        textdomain "storage"

        super
      end

      private

      # Deletes the indicated Btrfs subvolume (see {DeleteDevice#device})
      def delete
        fs = filesystem

        fs.delete_btrfs_subvolume(device.path)
        UIState.instance.select_row(fs.sid)
      end

      # @see DeleteDevice#confirm
      def confirm
        # TRANSLATORS: Message when deleting a Btrfs subvolume, where %{name} is replaced by the Btrfs
        #   subvolume (e.g., "@/home").
        text = format(_("Really delete the Btrfs subvolume %{path}?"), path: device.path)

        Yast2::Popup.show(text, buttons: :yes_no) == :yes
      end

      # Filesystem holding the subvolume
      #
      # @return [Filesystems::Btrfs]
      def filesystem
        device.filesystem
      end
    end
  end
end
