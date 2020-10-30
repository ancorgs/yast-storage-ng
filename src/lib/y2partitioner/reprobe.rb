# Copyright (c) [2017-2018] SUSE LLC
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
require "y2partitioner/device_graphs"
require "y2partitioner/exceptions"
require "y2storage/storage_manager"

Yast.import "Stage"
Yast.import "Popup"

module Y2Partitioner
  # Mixin for widgets and actions that need to trigger a hardware reprobe
  module Reprobe
  private

    # Reprobes and updates devicegraphs for the partitioner. During
    # installation, a reactivation is performed before reprobing.
    #
    # @note A message is shown during the reprobing action.
    #
    # @raise [Y2Partitioner::ForcedAbortError] When there is an error during probing
    #   and the user decides to abort, or probed devicegraph contains errors and the
    #   user decides to not sanitize.
    #
    # @param activate [Boolean, nil] whether to perform an activation, if nil
    #   the (re)activation will be done only during installation
    def reprobe(activate: nil)
      textdomain "storage"

      # By default, (re)activation is only done during installation.
      # In installed systems, activation is only triggered for actions that
      # explicitly force it.
      activate = !!Yast::Stage.initial if activate.nil?

      Yast::Popup.Feedback("", _("Rescanning disks...")) do
        raise Y2Partitioner::ForcedAbortError unless activate_and_probe?(activate)

        probed = storage_manager.probed
        staging = storage_manager.staging
        DeviceGraphs.create_instance(probed, staging)
      end
    end

    # @return [Y2Storage::StorageManager]
    def storage_manager
      Y2Storage::StorageManager.instance
    end

    # Performs storage reactivation (if needed) and reprobing
    #
    # @param activate [Boolean] whether to perform a reactivation of devices
    #   before the reprobing
    # @return [Boolean] false if something went wrong
    def activate_and_probe?(activate)
      success = true
      success &&= storage_manager.activate if activate
      success &&= storage_manager.probe
      success
    end
  end
end
