# -*- coding: utf-8 -*-
#
# Copyright (C) 2010-2011  Kouhei Sutou <kou@clear-code.com>
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

require 'racknga/log_database'

module Racknga
  module Middleware
    # This is a middleware that puts access logs to groonga
    # database. It may useful for OLAP (OnLine Analytical
    # Processing).
    #
    # Usage:
    #   use Racnkga::Middleware::Log, :database_path => "var/log/db"
    #   run YourApplication
    #
    # @see Racknga::LogDatabase
    class Log
      LOGGER = "racknga.logger"

      # @option options [String] :database_path the
      # database path to be stored caches.
      def initialize(application, options={})
        @application = application
        @options = Utils.normalize_options(options || {})
        database_path = @options[:database_path]
        raise ArgumentError, ":database_path is missing" if database_path.nil?
        @database = LogDatabase.new(database_path)
        @logger = Logger.new(@database)
      end

      # For Rack.
      def call(environment)
        environment[LOGGER] = @logger

        start_time = Time.now
        status, headers, body = @application.call(environment)
        end_time = Time.now

        request = Rack::Request.new(environment)
        log(start_time, end_time, request, status, headers, body)

        [status, headers, body]
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
      def log(start_time, end_time, request, status, headers, body)
        request_time = end_time - start_time
        runtime = headers["X-Runtime"]
        runtime_in_float = nil
        runtime_in_float = runtime.to_f if runtime
        length = headers["Content-Length"] || "-"
        length = "-" if length == "0"
        format = "%s - %s [%s] \"%s %s %s\" %s %s \"%s\" \"%s\" %s %0.8f"
        message = format % [request.ip || "-",
                            request.env["REMOTE_USER"] || "-",
                            end_time.dup.utc.strftime("%d/%b/%Y:%H:%M:%S %z"),
                            request.request_method,
                            request.fullpath,
                            request.env["SERVER_PROTOCOL"] || "-",
                            status.to_s[0..3],
                            length,
                            request.env["HTTP_REFERER"] || "-",
                            request.user_agent || "-",
                            runtime || "-",
                            request_time]
        @logger.log("access",
                    request.fullpath,
                    :message => message,
                    :user_agent => request.user_agent,
                    :runtime => runtime_in_float,
                    :request_time => request_time)
      end

      # @private
      class Logger
        def initialize(database)
          @database = database
          @entries = @database.entries
        end

        def log(tag, path, options={})
          @entries.add(options.merge(:time_stamp => Time.now,
                                     :tag => tag,
                                     :path => path))
        end
      end
    end
  end
end
