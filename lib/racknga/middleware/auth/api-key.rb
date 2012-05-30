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
  module Middleware
    module Auth
      # This is a middleware that provides an authentication of API key.
      # This middleware checks whether a URL requests API and
      # whether API key in its request is authorized.
      # When a URL requests API with unauthorized API key,
      # this middleware returns json response with :error_message.
      # Racknga::APIKeys is used as authorized API keys.
      # Usage:
      #   require 'racknga'
      #
      #   authorized_api_keys =
      #     Racknga::APIKeys.new("api-query-parameter", ["key1", "key2"])
      #   error_response =
      #   api_key_options = {
      #     :api_url_prefixes => ["/api"],
      #     :authorized_api_keys => authorized_api_keys,
      #     :error_response => {"error" => "this api key is not authorized"}
      #   }
      #   use Racknga::Middleware::Auth::APIKey, api_key_options
      #   run YourApplication
      class APIKey
        def initialize(application, options={})
          @application = application
          @authorized_api_keys = options[:authorized_api_keys]
          url_prefixes_option = options[:api_url_prefixes]
          @api_url_prefixes = url_prefixes_option.collect do |url|
            /\A#{Regexp.escape(url)}/
          end
          @error_response = options[:error_response].to_json
          @disable_authorization = options[:disable_authorization]
        end

        # For Rack.
        def call(environment)
          if api_url?(environment) and not authorized?(environment)
            unauthorized_access_response
          else
            @application.call(environment)
          end
        end

        private
        def api_url?(environment)
          @api_url_prefixes.any? do |prefix|
            environment["PATH_INFO"] =~ prefix
          end
        end

        def authorized?(environment)
          if disable_authorization?
            true
          else
            if @authorized_api_keys
              @authorized_api_keys.include?(environment)
            else
              false
            end
          end
        end

        def disable_authorization?
          @disable_authorization
        end

        def unauthorized_access_response
          [
            401,
            {"Content-Type" => "application/json; charset=utf-8"},
            [@error_response],
          ]
        end
      end
    end
  end
end
