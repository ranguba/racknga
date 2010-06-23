# -*- coding: utf-8 -*-
#
# Copyright (C) 2010  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License version 2.1 as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'yaml'
require 'racknga/cache_database'

module Racknga
  module Middleware
    class Cache
      def initialize(application, options={})
        @application = application
        @options = Utils.normalize_options(options || {})
        database_path = @options[:database_path]
        raise ArgumentError, ":database_path is missing" if database_path.nil?
        @database = CacheDatabase.new(database_path)
      end

      def call(environment)
        request = Rack::Request.new(environment)
        key = "#{key_prefix(request)}:#{normalize_path(request.fullpath)}"
        cache = @database.responses
        record = cache[key]
        if record
          handle_request_with_cache(cache, key, record, request)
        else
          handle_request(cache, key, request)
        end
      end

      def ensure_database
        @database.ensure_database
      end

      def close_database
        @database.close_database
      end

      private
      def key_prefix(request)
        if request.respond_to?(:mobile?) and request.mobile?
          last_component = request.mobile.class.name.split(/::/).last
          "mobile:#{last_component.downcase}"
        else
          "pc"
        end
      end

      def normalize_path(path)
        path.gsub(/&callback=jsonp\d+&_=\d+\z/, '')
      end

      def skip_cache?(status, headers, body)
        return true if status != 200

        headers = Rack::Utils::HeaderHash.new(headers)
        content_type = headers["Content-Type"]
        if /\A(\w+)\/([\w.+\-]+)\b/ =~ content_type
          media_type = $1
          sub_type = $2
          return false if media_type == "text"
          return false if sub_type == "json"
          return false if sub_type == "xml"
          return false if /\+xml\z/ =~ sub_type
        end
        true
      end

      def handle_request(cache, key, request)
        status, headers, body = @application.call(request.env)
        return [status, headers, body] if skip_cache?(status, headers, body)

        now = Time.now
        headers = Rack::Utils::HeaderHash.new(headers)
        headers["Last-Modified"] ||= now.httpdate
        stringified_body = ''
        body.each do |data|
          stringified_body << data
        end
        headers = headers.to_hash
        cache[key] = {
          :status => status,
          :headers => headers.to_yaml,
          :body => stringified_body.force_encoding("ASCII-8BIT"),
          :created_at => now,
        }
        body = [stringified_body]
        [status, headers, body]
      end

      def handle_request_with_cache(cache, key, record, request)
        body = record["body"]
        return handle_request(cache, key, request) if body.nil?

        status = record["status"]
        headers = YAML.load(record["headers"])
        [status, headers, [body]]
      end
    end
  end
end