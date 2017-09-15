require "yast"
require "y2partitioner/widgets/format_and_mount"

module Y2Partitioner
  module Dialogs
    # Which filesystem (and options) to use and where to mount it (with options).
    # Part of {Sequences::AddPartition} and {Sequences::EditBlkDevice}.
    # Formerly MiniWorkflowStepFormatMount
    class FormatAndMount < CWM::Dialog
      # @param options [Sequences::FilesystemController]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
        @format_options = Widgets::FormatOptions.new(controller)
        @mount_options = Widgets::MountOptions.new(controller)
      end

      def title
        "Edit Partition #{@controller.blk_device.name}"
      end

      def contents
        HVSquash(
          HBox(
            @format_options,
            HSpacing(5),
            @mount_options
          )
        )
      end

=begin
      def cwm_show
        ret = nil

        loop do
          ret = super

          case ret
          when @format_options.widget_id.to_sym
            @mount_options.refresh
          else
            break
          end
        end

        ret
      end
=end
    end
  end
end
