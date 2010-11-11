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
  module Middleware
    class JSONP
      def initialize(application)
        @application = application
      end

      def call(environment)
        request = Rack::Request.new(environment)
        callback = request["callback"]
        update_cache_key(request) if callback
        status, headers, body = @application.call(environment)
        return [status, headers, body] unless callback
        return [status, headers, body] unless json_response?(headers)
        body = Writer.new(callback, body)
        [status, headers, body]
      end

      private
      def update_cache_key(request)
        return unless Middleware.const_defined?(:Cache)
        cache_key_key = Cache::KEY_KEY

        path = request.fullpath
        path, parameters = path.split(/\?/, 2)
        if parameters
          parameters = parameters.split(/[&;]/).reject do |parameter|
            key, value = parameter.split(/\=/, 2)
            key == "callback" or (key == "_" and value = /\A\d+\z/)
          end.join("&")
          path << "?" << parameters unless parameters.empty?
        end

        key = request.env[cache_key_key]
        request.env[cache_key_key] = [key, path].compact.join(":")
      end

      def json_response?(headers)
        content_type = Rack::Utils::HeaderHash.new(headers)["Content-Type"]
        content_type == "application/json" or
          content_type == "application/javascript" or
          content_type == "text/javascript"
      end

      class Writer
        def initialize(callback, body)
          @callback = callback
          @body = body
        end

        def each(&block)
          block.call("#{@callback}(")
          @body.each(&block)
          block.call(");")
        end
      end
    end
  end
end
