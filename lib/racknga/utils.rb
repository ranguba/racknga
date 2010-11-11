# -*- coding: utf-8 -*-
#
# Copyright (C) 2010  Kouhei Sutou <kou@clear-code.com>
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
  module Utils
    module_function
    def production?
      ENV["RACK_ENV"] == "production"
    end

    def passenger?
      ENV["PASSENGER_ENVIRONMENT"] or
        /Phusion_Passenger/ =~ ENV["SERVER_SOFTWARE"].to_s
    end

    def normalize_options(options)
      normalized_options = {}
      options.each do |key, value|
        value = normalize_options(value) if value.is_a?(Hash)
        normalized_options[key.to_sym] = value
      end
      normalized_options
    end
  end
end
