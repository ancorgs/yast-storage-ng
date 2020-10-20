#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../spec_helper"
require_relative "callbacks_examples"
require "y2storage/callbacks/probe"

describe Y2Storage::Callbacks::Probe do
  subject(:callbacks) { described_class.new }

  describe "#error" do
    include_examples "general #error examples"
    include_examples "default #error true examples"

    context "without LIBSTORAGE_IGNORE_PROBE_ERRORS" do
      before { mock_env(env_vars) }
      let(:env_vars) { {} }
      it "it displays an error pop-up" do
        expect(Yast::Report).to receive(:yesno_popup)
        subject.error("probing failed", "")
      end
    end

    context "with LIBSTORAGE_IGNORE_PROBE_ERRORS set" do
      before { mock_env(env_vars) }
      after { mock_env({}) } # clean up for future tests
      let(:env_vars) { { "LIBSTORAGE_IGNORE_PROBE_ERRORS" => "1" } }
      it "does not display an error pop-up and returns true" do
        expect(Yast::Report).not_to receive(:yesno_popup)
        expect(subject.error("probing failed", "")).to be true
      end
    end
  end
end
