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
require "y2partitioner/icons"
require "y2partitioner/widgets/pages/base"
require "y2storage/filesystems/mount_by_type"
require "y2storage/storage_manager"
require "y2storage/sysconfig_storage"

module Y2Partitioner
  module Widgets
    module Pages
      # A page for displaying the Partitioner settings
      class Settings < Base
        include Yast::I18n

        # Constructor
        def initialize
          textdomain "storage"
        end

        # @macro seeAbstractWidget
        def label
          _("Settings")
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          @contents = VBox(
            Left(
              HBox(
                Image(Icons::SETTINGS, ""),
                # TRANSLATORS: Heading for the expert partitioner page
                Heading(_("Settings"))
              )
            ),
            Left(
              VBox(
                MountBySelector.new
              )
            ),
            VStretch()
          )
        end

        # Selector for the mount by option
        class MountBySelector < CWM::ComboBox
          def initialize
            textdomain "storage"
          end

          # @macro seeAbstractWidget
          def label
            _("Default Mount by")
          end

          # @macro seeAbstractWidget
          def help
            _("<p><b>Default Mount by:</b> This is the method " \
              "how newly created filesystems are mounted.</p>")
          end

          # @macro seeAbstractWidget
          def init
            self.value = configuration.default_mount_by.to_s
          end

          def items
            sorted_mount_bys = Y2Storage::Filesystems::MountByType.all.sort_by(&:to_human_string)
            sorted_mount_bys.map { |m| [m.to_s, m.to_human_string] }
          end

          # @return [Y2Storage::Filesystems::MountByType]
          def value
            Y2Storage::Filesystems::MountByType.find(super)
          end

          def opt
            [:notify]
          end

          # @macro seeAbstractWidget
          # Stores the given mount_by and immediately saves it into the sysconfig file
          #
          # @note #store is not used to save the values because we need to register the
          #   change just after selecting the value.
          def handle(event)
            return unless event["ID"] == widget_id

            configuration.default_mount_by = value
            configuration.update_sysconfig

            nil
          end

          private

          # Object handling the Y2Storage configuration
          #
          # @return [Y2Storage::Configuration]
          def configuration
            Y2Storage::StorageManager.instance.configuration
          end
        end
      end
    end
  end
end
