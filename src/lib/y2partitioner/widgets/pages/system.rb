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
require "y2partitioner/icons"
require "y2partitioner/ui_state"
require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/device_buttons_set"
require "y2partitioner/widgets/columns"

Yast.import "Mode"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for all storage devices in the system
      class System < Base
        include Yast::I18n

        # Constructor
        #
        # @param [String] hostname of the system, to be displayed
        # @param pager [CWM::TreePager]
        def initialize(hostname, pager)
          textdomain "storage"

          @pager = pager
          @hostname = hostname
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: label of the first element of the Partitioner left tree
          _("All Devices")
        end

        # @macro seeCustomWidget
        def contents
          invalidate_cached_content
          return @contents if @contents

          @contents = VBox(
            Left(header),
            table,
            Left(device_buttons)
          )
        end

        private

        # @return [String]
        attr_reader :hostname

        # @return [CWM::TreePager]
        attr_reader :pager

        # Invalidates cached content if needed according to
        # {OverviewTreePager#invalidated_views}
        def invalidate_cached_content
          return unless pager.invalidated_pages.delete(:system)

          @contents = nil
          @table = nil
        end

        # Page header
        #
        # @return [Yast::UI::Term]
        def header
          HBox(
            Image(Icons::ALL, ""),
            # TRANSLATORS: Heading. String followed by the hostname
            Heading(format(_("Available Storage on %s"), hostname))
          )
        end

        # The table contains all storage devices, including Software RAIDs and LVM Vgs
        #
        # @return [ConfigurableBlkDevicesTable]
        def table
          return @table unless @table.nil?

          @table = ConfigurableBlkDevicesTable.new(devices, @pager, device_buttons)
          @table.remove_columns(Columns::RegionStart, Columns::RegionEnd)
          @table
        end

        # Widget with the dynamic set of buttons for the selected row
        #
        # @return [DeviceButtonsSet]
        def device_buttons
          @device_buttons ||= DeviceButtonsSet.new(pager)
        end

        # Returns all storage devices
        #
        # @note Software RAIDs and LVM Vgs are included.
        #
        # @return [Array<Y2Storage::Device>]
        def devices
          disk_devices + software_raids + lvm_vgs + nfs_devices + bcaches + multidevice_filesystems
        end

        # @return [Array<Y2Storage::Device>]
        def disk_devices
          # Since XEN virtual partitions are listed at the end of the "Hard
          # Disks" section, let's do the same in the general storage table
          all = device_graph.disk_devices + device_graph.stray_blk_devices
          all.each_with_object([]) do |disk, devices|
            devices << disk
            devices.concat(disk.partitions) if disk.respond_to?(:partitions)
          end
        end

        # Returns all LVM volume groups and their logical volumes, including thin pools
        # and thin volumes
        #
        # @see Y2Storage::LvmVg#all_lvm_lvs
        #
        # @return [Array<Y2Storage::LvmVg, Y2Storage::LvmLv>]
        def lvm_vgs
          device_graph.lvm_vgs.reduce([]) do |devices, vg|
            devices << vg
            devices.concat(vg.all_lvm_lvs)
          end
        end

        # @return [Array<Y2Storage::Device>]
        def software_raids
          device_graph.software_raids.reduce([]) do |devices, raid|
            devices << raid
            devices.concat(raid.partitions)
          end
        end

        # @return [Array<Y2Storage::Device>]
        def nfs_devices
          device_graph.nfs_mounts
        end

        # @return [Array<Y2Storage::Device>]
        def bcaches
          all = device_graph.bcaches
          all.each_with_object([]) do |bcache, devices|
            devices << bcache
            devices.concat(bcache.partitions)
          end
        end

        # @return [Array<Y2Storage::Filesystems::Base>]
        def multidevice_filesystems
          device_graph.blk_filesystems.select(&:multidevice?)
        end

        def device_graph
          DeviceGraphs.instance.current
        end
      end
    end
  end
end
