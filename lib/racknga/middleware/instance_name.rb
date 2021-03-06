# -*- coding: utf-8 -*-
#
# Copyright (C) 2011  Ryo Onodera <onodera@clear-code.com>
# Copyright (C) 2012  Kouhei Sutou <kou@clear-code.com>
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

module Racknga
  module Middleware
    # This is a middleware that adds "X-Responsed-By" header
    # to responses. It's useful to determine responded
    # server when your Rack applications are deployed behind
    # load balancers.
    #
    # @example A simple usage
    #   require "racknga"
    #   use Racknga::Middleware::InstanceName
    #   run YourApplication
    class InstanceName
      attr_reader :header
      # @param [application] application rack application.
      # @param [Hash] options options to create header.
      # @option options [String] :header_name ("Responsed-By") header name.
      # @option options [String] :application_name (application.class.name)
      #   application name.
      # @option options [Integer] :version application version.
      def initialize(application, options={})
        @application = application
        @options = options

        @header = construct_header.freeze
        @headers = construct_headers.freeze
      end

      # For Rack.
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
        case using_scm_name
        when :git
          `git describe --abbrev=7 HEAD`.strip
        when :subversion
          `LANG=C svn info | grep Revision`.strip
        else
          nil
        end
      end

      def server
        `hostname`.strip
      end

      def user
        `id --user --name`.strip
      end

      def branch
        case using_scm_name
        when :git
          git_branch_name
        when :subversion
          subversion_branch_name
        else
          nil
        end
      end

      def ruby
        RUBY_DESCRIPTION
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
                      format_revision(branch, revision),
                      format_server(server),
                      format_user(user),
                      format_ruby(ruby))
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

      def format_revision(branch, revision)
        format_if_possible(revision) do
          "(at #{revision}#{format_branch(branch)})"
        end
      end

      def format_branch(branch)
        format_if_possible(branch) do
          " (#{branch})"
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

      def format_ruby(ruby)
        format_if_possible(ruby) do
          "with #{ruby}"
        end
      end

      def format_if_possible(data)
        if data and (data.respond_to?(:to_s) and not data.to_s.empty?)
          yield
        else
          nil
        end
      end

      SVN_URL_KEY = /\AURL:.*/
      SVN_REPOSITORY_ROOT_KEY = /\ARepository Root:.*/
      SVN_KEY = /\A.*:/
      SVN_BRANCHES_NAME = /\A\/branches\//
      def subversion_branch_name
        url = ""
        repository_root = ""

        `LANG=C svn info`.each_line do |line|
          case line
          when SVN_URL_KEY
            url = line.sub(SVN_KEY, "").strip
          when SVN_REPOSITORY_ROOT_KEY
            repository_root = line.sub(SVN_KEY, "").strip
          end
        end
        base_path = url.sub(/#{Regexp.escape(repository_root)}/, "")
        base_path.sub(SVN_BRANCHES_NAME, "")
      end

      GIT_CURRENT_BRANCH_MARKER = /\A\* /
      def git_branch_name
        `git branch -a`.each_line do |line|
          case line
          when GIT_CURRENT_BRANCH_MARKER
            return line.sub(GIT_CURRENT_BRANCH_MARKER, "").strip
          end
        end
        nil
      end

      def using_scm_name
        if File.exist?(".git")
          :git
        elsif File.exist?(".svn")
          :subversion
        else
          nil
        end
      end
    end
  end
end
