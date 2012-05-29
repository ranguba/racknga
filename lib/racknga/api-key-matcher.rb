# -*- coding: utf-8 -*-
#
# Copyright (C) 2012  Haruka Yoshihara <yoshihara@clear-code.com>
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
  # This is a matcher for authorized API keys. It is used with
  # Racknga::Middleware::Auth::APIKeys.
  class APIKeyMatcher
    # @param [String] query_parameter query parameter to specify an API key.
    # @param [Array] valid_api_keys authorized API keys.
    def initialize(query_parameter, valid_api_keys)
      @query_parameter = query_parameter
      @valid_api_keys = valid_api_keys
    end

    # Checks whether an API key in a request is authorized.
    # @param [Hash] environment an environment for Rack.
    # @return [Boolean] true if an API key is authorized, or false if not.
    def authorized?(environment)
      request = Rack::Request.new(environment)
      key = request[@query_parameter]

      @valid_api_keys.include?(key)
    end
  end
end
