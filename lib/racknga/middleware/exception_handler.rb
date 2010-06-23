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

require 'racknga/exception_notifier'

module Racknga
  module Middleware
    class ExceptionHandler
      def initialize(application, options={})
        @application = application
        @options = options || {}
        @notifier = @options["notifier"]
        @formatter = @options["formatter"]
      end

      def call(environment)
        @application.call(environment)
      rescue Exception => exception
        if @notifier
          begin
            @notifier.notify(exception, environment)
          rescue Exception
            begin
              $stderr.puts("#{$!.class}: #{$!.message}")
              $stderr.puts($@)
              $stderr.puts("-" * 10)
              $stderr.puts("#{exception.class}: #{exception.message}")
              $stderr.puts(exception.backtrace)
            rescue Exception
            end
          end
        end
        if @formatter
          environment["EXCEPTION"] = exception
          @formatter.call(environment)
        else
          raise
        end
      end
    end
  end
end
