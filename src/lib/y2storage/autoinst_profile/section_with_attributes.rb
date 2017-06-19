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

require "yast"

module Y2Storage
  module AutoinstProfile
    class SectionWithAttributes
      include Yast::Logger

      class << self
        def attributes
          []
        end

        def new_from_hashes(hash)
          result = new
          result.init_from_hashes(hash)
          result
        end

      protected

        def define_attr_accessors
          attributes.each do |attrib|
            attr_accessor attrib[:name]
          end
        end
      end

      def to_hashes
        attributes.each_with_object({}) do |attrib, result|
          value = attrib_value(attrib)
          next if attrib_skip?(value)

          key = attrib_key(attrib)
          result[key] = value
        end
      end

      def init_from_hashes(hash)
        init_scalars_from_hash(hash)
      end

    protected

      def attributes
        self.class.attributes
      end

      def attrib_skip?(value)
        return true if value.nil?
        return true if value == []
        return true if value == ""
        false
      end

      def attrib_value(attrib)
        value = send(attrib[:name])
        if value.is_a?(Array)
          value.map { |v| attrib_scalar(v) }
        else
          attrib_scalar(value)
        end
      end

      def attrib_scalar(element)
        element.respond_to?(:to_hashes) ? element.to_hashes : element
      end

      def attrib_key(attrib)
        (attrib[:xml_name] || attrib[:name]).to_s
      end

      def attrib_name(key)
        attrib = attributes.detect { |a| a[:xml_name] == key.to_sym || a[:name] == key.to_sym }
        return nil unless attrib
        attrib[:name]
      end

      def init_scalars_from_hash(hash)
        hash.each_pair do |key, value|
          name = attrib_name(key)

          if name.nil?
            log.warn "Attribute #{key} not recognized by #{self.class}. Check the XML schema."
            next
          end

          # This method only reads scalar values
          next if value.is_a?(Array) || value.is_a?(Hash)

          if attrib_skip?(value)
            log.debug "Ignored blank value (#{value}) for #{key}"
            next
          end

          send(:"#{name}=", value)
        end
      end
    end
  end
end
