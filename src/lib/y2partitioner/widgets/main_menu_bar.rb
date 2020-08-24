# Copyright (c) [2020] SUSE LLC
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
require "cwm"
require "y2partitioner/widgets/execute_and_redraw"
require "y2partitioner/actions/rescan_devices"

module Y2Partitioner
  module Widgets
    # Main menu bar of the partitioner
    class MainMenuBar < CWM::CustomWidget
      include Yast::Logger
      include ExecuteAndRedraw

      # Constructor
      def initialize
        textdomain "storage"
        self.handle_all_events = true
        super
      end

      # Widget contents
      def contents
        @contents ||= MenuBar(Id(:menu_bar), main_menus)
      end

      # Event handler for the main menu.
      #
      # @param event [Hash] UI event
      #
      def handle(event)
        return nil unless menu_event?(event)

        call_menu_item_handler(event["ID"])
      end

      private

      # Check if a UI event is a menu event
      def menu_event?(event)
        event["EventType"] == "MenuEvent"
      end

      # Call a method "handle_id" for a menu item with ID "id" if such a method
      # is defined in this class.
      def call_menu_item_handler(id)
        return nil if id.nil?

        # log.info("Handling menu event: #{id}")
        handler = "handle_#{id}"
        if respond_to?(handler, true)
          log.info("Calling #{handler}()")
          send(handler)
        else
          log.info("No method #{handler}")
          nil
        end
      end

      #----------------------------------------------------------------------
      # Menu Definitions
      #----------------------------------------------------------------------

      def main_menus
        [
          # TRANSLATORS: Pulldown menus in the partitioner
          Menu(_("&System"), system_menu),
          Menu(_("&Edit"), edit_menu),
          Menu(_("&View"), view_menu),
          Menu(_("&Configure"), configure_menu),
          Menu(_("&Options"), options_menu)
        ].freeze
      end

      def system_menu
        # For each item with an ID "xy", write a "handle_xy" method.
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:rescan_devices), _("R&escan Devices")),
          Item(Id(:settings), _("Se&ttings...")),
          Item("---"),
          Item(Id(:abort), _("&Abort (Abandon Changes)")),
          Item("---"),
          Item(Id(:next), _("&Finish (Save and Exit)"))
        ].freeze
      end

      def edit_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:add), _("&Add...")),
          Item(Id(:edit), _("&Edit...")),
          Item(Id(:delete), _("&Delete")),
          Item(Id(:delete_all), _("Delete A&ll")),
          Item("---"),
          Item(Id(:resize), _("Resi&ze...")),
          Item(Id(:move), _("&Move..."))
        ].freeze
      end

      def view_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:device_graphs), _("Device &Graphs...")),
          Item(Id(:installation_summary), _("Installation &Summary..."))
        ].freeze
      end

      def configure_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:provide_crypt_passwords), _("Provide &Crypt Passwords...")),
          Item(Id(:configure_iscsi), _("Configure &iSCSI...")),
          Item(Id(:configure_fcoe), _("Configure &FCoE..."))
        ].freeze
      end

      def options_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:create_partition_table), _("Create New Partition &Table...")),
          Item(Id(:clone_partitions), _("&Clone Partitions to Other Devices..."))
        ].freeze
      end

      #----------------------------------------------------------------------
      # Handlers for the menu actions
      #
      # For each menu item with ID xy, write a method handle_xy.
      # The methods are found via introspection in the event handler.
      #----------------------------------------------------------------------

      def handle_rescan_devices
        execute_and_redraw { Actions::RescanDevices.new.run }
      end

      def handle_abort
        # This is handled by the CWM base classes as the "Abort" wizard button.
        nil
      end

      def handle_next
        # This is handled by the CWM base classes as the "Next" wizard button.
        nil
      end
    end
  end
end