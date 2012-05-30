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
  # This is a store for API keys. It is used with
  # Racknga::Middleware::Auth::APIKeys.
  class APIKeys
    # @param [String] query_parameter query parameter to specify an API key.
    # @param [Array] api_keys stored API keys.
    def initialize(query_parameter, api_keys)
      @query_parameter = query_parameter
      @api_keys = api_keys
    end

    # Checks whether stored API keys includes an API key in a request.
    # @param [Hash] environment an environment for Rack.
    # @return [Boolean] true if an API key is included, or false if not.
    def matched?(environment)
      request = Rack::Request.new(environment)
      key = request[@query_parameter]

      @api_keys.include?(key)
    end
  end
end
