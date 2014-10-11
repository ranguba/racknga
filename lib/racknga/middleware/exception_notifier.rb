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

require 'racknga/exception_mail_notifier'

module Racknga
  module Middleware
    # This is a middleware that mails exception details on
    # error. It's useful for finding your Rack application
    # troubles.
    #
    # Usage:
    #   require "racknga"
    #
    #   notifier_options = {
    #     :subject_label => "[YourApplication]",
    #     :from => "reporter@example.com",
    #     :to => "maintainers@example.com",
    #   }
    #   notifiers = [Racknga::ExceptionMailNotifier.new(notifier_options)]
    #   use Racknga::Middleware::ExceptionNotifier, :notifiers => notifiers
    #   run YourApplication
    class ExceptionNotifier
      def initialize(application, options={})
        @application = application
        @options = Utils.normalize_options(options || {})
        @notifiers = @options[:notifiers] || []
      end

      # For Rack.
      def call(environment)
        @application.call(environment)
      rescue Exception => exception
        @notifiers.each do |notifier|
          begin
            notifier.notify(exception, environment)
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
        raise
      end
    end
  end
end
