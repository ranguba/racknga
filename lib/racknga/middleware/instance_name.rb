# -*- coding: utf-8 -*-
#
# Copyright (C) 2011  Ryo Onodera <onodera@clear-code.com>
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
    # This is a middleware that adds "X-Responsed-By" header
    # to responses. It's useful to determine responded
    # server when your Rack applications are deployed behind
    # load balancers.
    #
    # Usage:
    #   require "racknga"
    #   use Racknga::Middleware::InstanceName
    #   run YourApplication
    class InstanceName
      attr_reader :header
      def initialize(application, options={})
        @application = application
        @options = options

        @header = construct_header.freeze
        @headers = construct_headers.freeze
      end

      def call(environment)
        response = @application.call(environment).to_a

        [
          response[0],
          response[1].merge(@headers),
          response[2],
        ]
      end

      def application_name
        @options[:application_name] || @application.class.name
      end

      def version
        @options[:version]
      end

      def revision
        `git describe --abbrev=7 HEAD`.strip # XXX be SCM-agonostic
      end

      def server
        `hostname`.strip
      end

      def user
        `id --user --name`.strip
      end

      private
      DEFAULT_HEADER_NAME = "X-Responsed-By"
      def header_name
        @options[:header_name] || DEFAULT_HEADER_NAME
      end

      def construct_headers
        {
          header_name => header,
        }
      end

      def construct_header
        format_header(format_application_name(application_name),
                      format_version(version),
                      format_revision(revision),
                      format_server(server),
                      format_user(user))
      end

      def format_header(*arguments)
        arguments.compact.join(" ")
      end

      def format_application_name(name)
        format_if_possible(name) do
          "#{name}"
        end
      end

      def format_version(version)
        format_if_possible(version) do
          "v#{version}"
        end
      end

      def format_revision(revision)
        format_if_possible(revision) do
          "(at #{revision})"
        end
      end

      def format_server(server)
        format_if_possible(server) do
          "on #{server}"
        end
      end

      def format_user(user)
        format_if_possible(user) do
          "by #{user}"
        end
      end

      def format_if_possible(data)
        if data and (data.respond_to?(:to_s) and not data.to_s.empty?)
          result = yield
        end

        result
      end
    end
  end
end
