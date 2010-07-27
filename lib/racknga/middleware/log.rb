# -*- coding: utf-8 -*-
#
# Copyright (C) 2010  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'racknga/log_database'

module Racknga
  module Middleware
    class Log
      LOGGER_KEY = "racknga.logger"

      def initialize(application, options={})
        @application = application
        @options = Utils.normalize_options(options || {})
        database_path = @options[:database_path]
        raise ArgumentError, ":database_path is missing" if database_path.nil?
        @database = LogDatabase.new(database_path)
        @logger = Logger.new(@database)
      end

      def call(environment)
        environment[LOGGER_KEY] = @logger

        start_time = Time.now
        status, headers, body = @application.call(environment)
        end_time = Time.now
        request_time = end_time - start_time

        length = headers["Content-Length"] || "-"
        length = "-" if length == "0"
        request = Rack::Request.new(environment)
        format = "%s - %s [%s] \"%s %s %s\" %d %s %0.4f"
        message = format % [request.ip || "-",
                            environment["REMOTE_USER"] || "-",
                            end_time.strftime("%d/%b/%Y %H:%M:%S"),
                            request.request_method,
                            request.fullpath,
                            environment["HTTP_VERSION"],
                            status.to_s[0..3],
                            length,
                            request_time]
        @logger.log("access",
                    request.fullpath,
                    :message => message,
                    :runtime => request_time)

        [status, headers, body]
      end

      def ensure_database
        @database.ensure_database
      end

      def close_database
        @database.close_database
      end

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
