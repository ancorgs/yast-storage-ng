#!/usr/bin/env rspec

# Copyright (c) [2017-2020] SUSE LLC
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

require_relative "../spec_helper"
require_relative "callbacks_examples"
require "y2storage/callbacks/commit"

describe Y2Storage::Callbacks::Commit do
  subject(:callbacks) { described_class.new }

  describe "#error" do
    include_examples "general #error examples"
    include_examples "default #error false examples"
  end

  describe "#message" do
    context "when a widget is given" do
      subject { described_class.new(widget: widget) }

      let(:widget) { double("Actions", add_action: nil) }

      let(:message) { "a message" }

      it "calls #add_action over the widget" do
        expect(widget).to receive(:add_action).with(message)

        subject.message(message)
      end
    end
  end
end
