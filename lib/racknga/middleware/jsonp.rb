# -*- coding: utf-8 -*-
#
# Copyright (C) 2010-2012  Kouhei Sutou <kou@clear-code.com>
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
    # This is a middleware that provides JSONP support.
    #
    # If you use this middleware, your Rack application just
    # returns JSON response.
    #
    # Usage:
    #   require "racknga"
    #
    #   use Rack::ContentLength
    #   use Racknga::Middleware::JSONP
    #   json_application = Proc.new do |env|
    #     [200,
    #      {"Content-Type" => "application/json"},
    #      ['{"Hello": "World"}']]
    #   end
    #   run json_application
    #
    # Results:
    #   % curl 'http://localhost:9292/'
    #   {"Hello": "World"}
    #   % curl 'http://localhost:9292/?callback=function'
    #   function({"Hello": "World"})
    #
    # You can use this middleware with
    # Racknga::Middleware::Cache. You *should* use this
    # middleware before the cache middleware:
    #   use Racknga::Middleawre::JSONP
    #   use Racknga::Middleawre::Cache, :database_path => "var/cache/db"
    #   run YourApplication
    #
    # If you use this middleware after the cache middleware,
    # the cache middleware will cache many responses that
    # just only differ callback parameter value. Here are
    # examples:
    #
    # Recommended case:
    #   use Racknga::Middleawre::JSONP
    #   use Racknga::Middleawre::Cache, :database_path => "var/cache/db"
    #   run YourApplication
    #
    # Requests:
    #   http://localhost:9292/                    -> no cache. cached.
    #   http://localhost:9292/?callback=function1 -> use cache.
    #   http://localhost:9292/?callback=function2 -> use cache.
    #   http://localhost:9292/?callback=function3 -> use cache.
    #   http://localhost:9292/?callback=function1 -> use cache.
    #
    # Not recommended case:
    #   use Racknga::Middleawre::Cache, :database_path => "var/cache/db"
    #   use Racknga::Middleawre::JSONP
    #   run YourApplication
    #
    # Requests:
    #   http://localhost:9292/                    -> no cache. cached.
    #   http://localhost:9292/?callback=function1 -> no cache. cached.
    #   http://localhost:9292/?callback=function2 -> no cache. cached.
    #   http://localhost:9292/?callback=function3 -> no cache. cached.
    #   http://localhost:9292/?callback=function1 -> use cache.
    class JSONP
      def initialize(application)
        @application = application
      end

      # For Rack.
      def call(environment)
        request = Rack::Request.new(environment)
        callback = request["callback"]
        update_cache_key(request) if callback
        status, headers, body = @application.call(environment)
        return [status, headers, body] unless callback
        header_hash = Rack::Utils::HeaderHash.new(headers)
        return [status, headers, body] unless json_response?(header_hash)
        body = Writer.new(callback, body)
        update_header_hash(header_hash, body)
        [status, header_hash, body]
      end

      private
      def update_cache_key(request)
        return unless Middleware.const_defined?(:Cache)
        cache_key = Cache::KEY

        path = request.fullpath
        path, parameters = path.split(/\?/, 2)
        if parameters
          parameters = parameters.split(/[&;]/).reject do |parameter|
            key, value = parameter.split(/\=/, 2)
            key == "callback" or (key == "_" and value = /\A\d+\z/)
          end.join("&")
          path << "?" << parameters unless parameters.empty?
        end

        key = request.env[cache_key]
        request.env[cache_key] = [key, path].compact.join(":")
      end

      def json_response?(header_hash)
        content_type = header_hash["Content-Type"]
        media_type = content_type.split(/\s*;\s*/, 2).first.downcase
        media_type == "application/json" or
          media_type == "application/javascript" or
          media_type == "text/javascript"
      end

      def update_header_hash(header_hash, body)
        update_content_type(header_hash)
        update_content_length(header_hash, body)
      end

      def update_content_type(header_hash)
        content_type = header_hash["Content-Type"]
        media_type, parameters = content_type.split(/\s*;\s*/, 2)
        _ = media_type # FIXME: suppress a warning. :<
        # We should use application/javascript not
        # text/javascript when all IE <= 8 are deprecated. :<
        updated_content_type = ["text/javascript", parameters].compact.join("; ")
        header_hash["Content-Type"] = updated_content_type
      end

      def update_content_length(header_hash, body)
        return unless header_hash["Content-Length"]

        content_length = header_hash["Content-Length"].to_i
        updated_content_length = content_length + body.additional_content_length
        header_hash["Content-Length"] = updated_content_length.to_s
      end

      # @private
      class Writer
        def initialize(callback, body)
          @callback = callback
          @body = body
          @header = "#{@callback}("
          @footer = ");"
        end

        def each(&block)
          block.call(@header)
          @body.each(&block)
          block.call(@footer)
        end

        def additional_content_length
          @header.bytesize + @footer.bytesize
        end
      end
    end
  end
end
