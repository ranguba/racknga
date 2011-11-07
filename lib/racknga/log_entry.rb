# -*- coding: utf-8 -*-
#
# Copyright (C) 2011  Ryo Onodera <onodera@clear-code.com>
# Copyright (C) 2011  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

module Racknga
  class LogEntry
    ATTRIBUTES = [
      :remote_address,
      :remote_user,
      :time_local,
      :runtime,
      :request_time,
      :request,
      :status,
      :body_bytes_sent,
      :http_referer,
      :http_user_agent,
    ]

    attr_reader(*ATTRIBUTES)
    def initialize(options=nil)
      options ||= {}
      @remote_address = options[:remote_address]
      @remote_user = normalize_string_value(options[:remote_user])
      @time_local = options[:time_local] || Time.at(0)
      @runtime = normalize_float_value(options[:runtime])
      @request_time = normalize_float_value(options[:request_time])
      @request = options[:request]
      @status = options[:status]
      @body_bytes_sent = normalize_int_value(options[:body_bytes_sent])
      @http_referer = normalize_string_value(options[:http_referer])
      @http_user_agent = normalize_string_value(options[:http_user_agent])
    end

    def attributes
      ATTRIBUTES.collect do |attribute|
        __send__(attribute)
      end
    end

    def ==(other)
      other.is_a?(self.class) and attributes == other.attributes
    end

    private
    def normalize_string_value(value)
      if value.nil? or value == "-"
        nil
      else
        value.to_s
      end
    end

    def normalize_float_value(value)
      if value.nil?
        value
      else
        value.to_f
      end
    end

    def normalize_int_value(value)
      if value.nil? or value == "-"
        nil
      else
        value.to_i
      end
    end
  end
end
