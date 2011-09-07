# -*- coding: utf-8 -*-
#
# Copyright (C) 2011  Ryo Onodera <onodera@clear-code.com>
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
  module Middleware
    # NOTE:
    # This is a middleware that restores the unprocessed URI client requests
    # as is. Usually, nginx-passenger stack unescapes percent encoding in URI
    # and resolve relative paths (ie "." and "..").
    # Most of time, processed URI isn't program. However, if you want to
    # distinguish %2F (ie "/") from "/", it is.
    #
    # Passenger 3.x or later is required.
    #
    # Use this with following nginx configuration:
    #
    #   ... {
    #      ...
    #      passenger_set_cgi_param HTTP_X_RAW_REQUEST_URI $request_uri;
    #   }
    #
    # Usage:
    #   require "racknga"
    #   use Racknga::Middleware::NginxRawURI
    #   run YourApplication
    class NginxRawURI
      RAW_REQUEST_URI_HEADER_NAME = "HTTP_X_RAW_REQUEST_URI"
      def initialize(application)
        @application = application
      end

      # For Rack.
      def call(environment)
        raw_uri = environment[RAW_REQUEST_URI_HEADER_NAME]

        if raw_uri
          restore_raw_uri(environment, raw_uri)
        end

        @application.call(environment)
      end

      private
      def restore_raw_uri(environment, raw_uri)
        environment["PATH_INFO"] = raw_uri.split("?").first
        environment["REQUEST_URI"] = raw_uri
      end
    end
  end
end
