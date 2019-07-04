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
# with this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2storage"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Class used in {SelectFilesystem::Ng} to draw each widget representing
      # a single volume and to handle its UI events.
      #
      # That dialog is basically a collection of such widgets, one for every
      # volume that can be configured.
      class DiskSelectorWidget
        include Yast::UIShortcuts
        include Yast::I18n

        # @param settings [ProposalSettings] see {#settings}
        # @param index [Integer] see {#index}
        # @param candidate_disks [Array<Disk>]
        def initialize(settings, index, candidate_disks)
          textdomain "storage"

          @settings        = settings
          @index           = index
          @volume_set      = settings.volumes_sets[index]
          @volumes         = volume_set.volumes
          @candidate_disks = candidate_disks
        end

        # Widget term for the volume, including widgets for everything the
        # user can configure
        #
        # @return [WidgetTerm]
        def content
          VBox(
            Left(label),
            Left(
              ComboBox(
                Id(widget_id),
                "",
                disk_items
              )
            )
          )
        end

        # The id for the widget, based in its position within the settings
        # @return [String]
        def widget_id
          "disk_for_volume_set_#{index}"
        end

        # Items for the selector
        # @return [Array<Item>]
        def disk_items
          candidate_disks.map do |disk|
            selected = volume_set.device == disk.name

            Item(Id(disk.name), "#{disk.name}, #{disk.size}", selected)
          end
        end

        # Updates the volume with the values from the UI
        def store
          volume_set.device = Yast::UI.QueryWidget(Id(widget_id), :Value)

          nil
        end

        protected

        # Proposal settings being defined by the user
        # @return [ProposalSettings]
        attr_reader :settings

        # Available disks
        # @return [Array<Disk>]
        attr_reader :candidate_disks

        # Volume specification set to be configured by the user
        # @return [VolumeSpecificationSet]
        attr_reader :volume_set

        # Volume specifications in the set
        # @return [Array<VolumeSpecification>]
        attr_reader :volumes

        # Position of #volume_set within the volumes_sets list at #settings.
        #
        # Useful to relate UI elements to the corresponding volume
        attr_reader :index

        # Widget term for the title of the volume in case it's always
        # proposed
        #
        # @return [WidgetTerm]
        def label
          text =
            case volume_set.type
            when :lvm
              # _("Disk for system LVM\n(#{volumes.mount_points.join(', ')})")
              _("Disk for the system LVM")
            when :separate_lvm
              _("Disk for #{volume_set.vg_name} Volume Group")
            when :partition
              label_for_partition
            end

          Label(Id("label_of_#{widget_id}"), text)
        end

        # @see #header_term
        def label_for_partition
          mount_point = volumes.first.mount_point

          case mount_point
          when "/"
            _("Disk for the Root Partition")
          when "/home"
            _("Disk for the Home Partition")
          when "swap"
            _("Disk for Swap Partition")
          when nil
            # TRANSLATORS: "Additional" because it will be created but not mounted
            _("Disk for Additional Partition")
          else
            # TRANSLATORS: %s is a mount point (e.g. /var/lib)
            _("Disk for the %s Partition") % mount_point
          end
        end
      end
    end
  end
end
