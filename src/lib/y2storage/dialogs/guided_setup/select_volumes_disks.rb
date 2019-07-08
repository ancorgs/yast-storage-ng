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
require "y2storage/dialogs/guided_setup/base"
require "y2storage/dialogs/guided_setup/disk_selector_widget"

module Y2Storage
  module Dialogs
    class GuidedSetup
      # Dialog for volumes disks selection for the proposal.
      class SelectVolumesDisks < Base
        def initialize(*params)
          textdomain "storage"
          super
        end

        # This dialog has to be skipped when there is only
        # one candidate disk for installing.
        def skip?
          analyzer.candidate_disks.size == 1
        end

        # Before skipping, settings should be assigned.
        def before_skip
          settings.candidate_devices = analyzer.candidate_disks.map(&:name)
        end

        protected

        def dialog_title
          _("Select Hard Disk(s)")
        end

        def dialog_content
          content = volume_widgets.each_with_object(VBox()) do |widget, vbox|
            vbox << VSpacing(1.4) unless vbox.empty?
            vbox << widget.content
          end

          HVCenter(
            HSquash(
              content
            )
          )
        end

        # Set of widgets to display, one for every volume specification set in the settings that is
        # configurable by the user
        def volume_widgets
          @volume_widgets ||=
            settings.volumes_sets.to_enum.with_index.map do |vs, idx|
              next unless vs.proposed?

              DiskSelectorWidget.new(settings, idx, analyzer.candidate_disks)
            end.compact
        end

        # Update the settings: Fetch the current widget values and store them in the settings.
        def update_settings!
          volume_widgets.each(&:store)
        end

        def help_text
          # TRANSLATORS: Help text for guided storage setup
          # TODO: write the help
        end

        private

        def valid?
          true
        end
      end
    end
  end
end
