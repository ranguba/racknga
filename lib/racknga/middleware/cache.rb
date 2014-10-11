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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require 'digest'
require 'yaml'
require 'zlib'
require 'racknga/cache_database'

module Racknga
  module Middleware
    # This is a helper middleware for
    # Racknga::Middleware::Cache.
    #
    # If your Rack application provides different views to
    # mobile user agent and PC user agent in the same URL,
    # this middleware is useful. Your Rack application can
    # has different caches for mobile user agent and PC user
    # agent.
    #
    # This middleware requires jpmobile.
    #
    # Usage:
    #   use Racnkga::Middleware::PerUserAgentCache
    #   use Racnkga::Middleware::Cache, :database_path => "var/cache/db"
    #   run YourApplication
    #
    # @see http://jpmobile-rails.org/ jpmobile
    # @see Racknga::Middleware::Cache
    class PerUserAgentCache
      def initialize(application)
        @application = application
      end

      # For Rack.
      def call(environment)
        mobile = environment["rack.jpmobile"]
        if mobile
          last_component = mobile.class.name.split(/::/).last
          user_agent_key = "mobile:#{last_component.downcase}"
        else
          user_agent_key = "pc"
        end
        key = environment[Cache::KEY]
        environment[Cache::KEY] = [key, user_agent_key].join(":")
        @application.call(environment)
      end
    end

    # This is a middleware that provides page cache.
    #
    # This stores page contents into a groonga
    # database. A groonga database can access by multi
    # process. It means that your Rack application processes
    # can share the same cache. For example, Passenger runs
    # your Rack application with multi processes.
    #
    # Cache key is the request URL by default. It can be
    # customized by env[Racknga::Cache::KEY]. For example,
    # Racknga::Middleware::PerUserAgentCache and
    # Racknga::Middleware::JSONP use it.
    #
    # This only caches the following responses:
    # * 200 status response.
    # * text/*, */json, */xml or */*+xml content type response.
    #
    # Usage:
    #   use Racnkga::Middleware::Cache, :database_path => "var/cache/db"
    #   run YourApplication
    #
    # @see Racknga::Middleware::PerUserAgentCache
    # @see Racknga::Middleware::JSONP
    # @see Racknga::Middleware::Deflater
    # @see Racknga::CacheDatabase
    class Cache
      KEY = "racknga.cache.key"
      START_TIME = "racknga.cache.start_time"

      # @return [Racknga::CacheDatabase] the database used
      #   by this middleware.
      attr_reader :database

      # @option options [String] :database_path the database
      #   path to be stored caches.
      def initialize(application, options={})
        @application = application
        @options = Utils.normalize_options(options || {})
        database_path = @options[:database_path]
        raise ArgumentError, ":database_path is missing" if database_path.nil?
        @database = CacheDatabase.new(database_path)
      end

      # For Rack.
      def call(environment)
        request = Rack::Request.new(environment)
        return @application.call(environment) unless use_cache?(request)
        age = @database.configuration.age
        key = normalize_key(environment[KEY] || request.fullpath)
        environment[START_TIME] = Time.now
        cache = @database.responses
        record = cache[key]
        if record and record.age == age
          handle_request_with_cache(cache, key, age, record, request)
        else
          handle_request(cache, key, age, request)
        end
      end

      # ensures creating cache database.
      def ensure_database
        @database.ensure_database
      end

      # close the cache database.
      def close_database
        @database.close_database
      end

      private
      def use_cache?(requeust)
        requeust.get? or requeust.head?
      end

      def skip_caching_response?(status, headers, body)
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

      def normalize_key(key)
        if key.size > 4096
          Digest::SHA1.hexdigest(key).force_encoding("ASCII-8BIT")
        else
          key
        end
      end

      def handle_request(cache, key, age, request)
        status, headers, body = @application.call(request.env)
        if skip_caching_response?(status, headers, body)
          log("skip", request)
          return [status, headers, body]
        end

        now = Time.now
        headers = Rack::Utils::HeaderHash.new(headers)
        headers["Last-Modified"] ||= now.httpdate
        encoded_body = ''.force_encoding("ASCII-8BIT")
        deflater = ::Zlib::Deflate.new
        body.each do |data|
          encoded_body << deflater.deflate(data)
        end
        body.close if body.respond_to?(:close)
        encoded_body << deflater.finish
        headers = headers.to_hash
        encoded_headers = headers.to_yaml
        cache[key] = {
          :status => status,
          :headers => encoded_headers,
          :body => encoded_body,
          :checksum => compute_checksum(status, encoded_headers, encoded_body),
          :age => age,
          :created_at => now,
        }
        body = Inflater.new(encoded_body)
        log("store", request)
        [status, headers, body]
      end

      def handle_request_with_cache(cache, key, age, record, request)
        status = record.status
        headers = record.headers
        body = record.body
        checksum = record.checksum
        unless valid_cache?(status, headers, body, checksum)
          log("invalid", request)
          return handle_request(cache, key, age, request)
        end

        log("hit", request)
        [status, YAML.load(headers), Inflater.new(body)]
      end

      def compute_checksum(status, encoded_headers, encoded_body)
        checksum = Digest::SHA1.new
        checksum << status.to_s
        checksum << ":"
        checksum << encoded_headers
        checksum << ":"
        checksum << encoded_body
        checksum.hexdigest.force_encoding("ASCII-8BIT")
      end

      def valid_cache?(status, encoded_headers, encoded_body, checksum)
        return false if status.nil? or encoded_headers.nil? or encoded_body.nil?
        return false if checksum.nil?
        compute_checksum(status, encoded_headers, encoded_body) == checksum
      end

      def log(tag, request)
        return unless Middleware.const_defined?(:Log)
        env = request.env
        logger = env[Middleware::Log::LOGGER]
        return if logger.nil?
        start_time = env[START_TIME]
        runtime = Time.now - start_time
        logger.log("cache-#{tag}", request.fullpath, :runtime => runtime)
      end

      # @private
      class Inflater
        def initialize(deflated_string)
          @deflated_string = deflated_string
        end

        def each
          yield ::Zlib::Inflate.inflate(@deflated_string)
        end
      end
    end
  end
end
