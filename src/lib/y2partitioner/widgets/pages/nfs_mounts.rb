# encoding: utf-8

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

require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/yast_nfs_client"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for NFS handling. It relies in the dialog content provided
      # by yast2-nfs-client
      #
      # @see YastNfsClient
      class NfsMounts < CWM::Page
        include Yast::I18n

        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(pager)
          textdomain "storage"

          @pager = pager
        end

        # @macro seeAbstractWidget
        def label
          _("NFS")
        end

        # @macro seeCustomWidget
        def contents
          icon = Icons.small_icon(Icons::NFS)
          VBox(
            Left(
              HBox(
                Image(icon, ""),
                # TRANSLATORS: Heading for the expert partitioner page
                Heading(_("Network File System (NFS)"))
              )
            ),
            nfs_client.init_ui || fallback_ui
          )
        end

        # @macro seeAbstractWidget
        def handle(event)
          nfs_client.handle_input(event)
          nil
        end

      private

        # @return [CWM::TreePager]
        attr_reader :pager

        # User interface to display if the NFS client is not available
        #
        # @return [Yast::Term]
        def fallback_ui
          pkg = nfs_client.package_name

          VBox(
            VSpacing(0.6),
            Left(
              Label(
                # TRANSLATORS: %s is the name of a package (i.g. 'yast2-nfs-client')
                _("NFS configuration is not available. Check %s package installation.") % pkg
              )
            ),
            VStretch()
          )
        end

        # @return [NfsClient]
        def nfs_client
          @nfs_client ||= YastNfsClient.new
        end
      end
    end
  end
end
