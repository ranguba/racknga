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

require 'digest/md5'
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
        return @application.call(environment) unless use_cache?(request)
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
      def use_cache?(requeust)
        requeust.get? or requeust.head?
      end

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

      def skip_caching_response?(status, headers, body)
        return true if status != 200
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
        if skip_caching_response?(status, headers, body)
          return [status, headers, body]
        end

        now = Time.now
        headers = Rack::Utils::HeaderHash.new(headers)
        headers["Last-Modified"] ||= now.httpdate
        stringified_body = ''
        body.each do |data|
          stringified_body << data
        end
        headers = headers.to_hash
        encoded_headers = headers.to_yaml
        encoded_body = stringified_body.force_encoding("ASCII-8BIT")
        cache[key] = {
          :status => status,
          :headers => encoded_headers,
          :body => encoded_body,
          :checksum => compute_checksum(status, encoded_headers, encoded_body),
          :created_at => now,
        }
        body = [stringified_body]
        [status, headers, body]
      end

      def handle_request_with_cache(cache, key, record, request)
        status = record["status"]
        headers = record["headers"]
        body = record["body"]
        checksum = record["checksum"]
        if valid_cache?(status, headers, body, checksum)
          return handle_request(cache, key, request)
        end

        [status, YAML.load(headers), [body]]
      end

      def compute_checksum(status, encoded_headers, encoded_body)
        md5 = Digest::MD5.new
        md5 << status.to_s
        md5 << ":"
        md5 << encoded_headers
        md5 << ":"
        md5 << encoded_body
        md5.hexdigest.force_encoding("ASCII-8BIT")
      end

      def valid_cache?(status, encoded_headers, encoded_body, checksum)
        return false if status.nil? or encoded_headers.nil? or encoded_body.nil?
        return false if checksum.nil?
        compute_checksum(status, encoded_headers, encoded_body) == checksum
      end
    end
  end
end
