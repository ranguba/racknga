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

require 'fileutils'

require 'groonga'

module Racknga
  # This is a log database based on groonga. It is used by
  # Racknga::Middleware::Log.
  #
  # Normally, #purge_old_responses is only used for log
  # maintenance.
  class LogDatabase
    # @param [String] database_path the path for log database.
    def initialize(database_path)
      @database_path = database_path
      @context = Groonga::Context.new(:encoding => :none)
      ensure_database
    end

    def entries
      @entries ||= @context["Entries"]
    end

    def ensure_database
      if File.exist?(@database_path)
        @database = Groonga::Database.open(@database_path, :context => @context)
      else
        create_database
      end
      ensure_tables
    end

    def close_database
      @database.close
    end

    # Purges old responses. To clear old logs, you should
    # call this method. All records created before
    # +base_time+ are removed.
    #
    # You can call this method by the different
    # process from your Rack application
    # process. (e.g. cron.) It's multi process safe.
    #
    # @param [Time] base_time the oldest record time to be
    # removed. The default value is 1 day ago.
    def purge_old_entries(base_time=nil)
      base_time ||= Time.now - 60 * 60 * 24
      target_entries = entries.select do |record|
        record.time_stamp < base_time
      end
      target_entries.each do |entry|
        entry.key.delete
      end
    end

    private
    def create_tables
      Groonga::Schema.define(:context => @context) do |schema|
        schema.create_table("Tags",
                            :type => :patricia_trie,
                            :key_type => "ShortText") do |table|
        end

        schema.create_table("Paths",
                            :type => :patricia_trie,
                            :key_type => "ShortText") do |table|
        end

        schema.create_table("UserAgents",
                            :type => :hash,
                            :key_type => "ShortText") do |table|
        end

        schema.create_table("Entries") do |table|
          table.time("time_stamp")
          table.reference("tag", "Tags")
          table.reference("path", "Paths")
          table.reference("user_agent", "UserAgents")
          table.float("runtime")
          table.float("request_time")
          table.short_text("message", :compress => :zlib)
        end

        schema.change_table("Tags") do |table|
          table.index("Entries.tag")
        end

        schema.change_table("Paths") do |table|
          table.index("Entries.path")
        end

        schema.change_table("UserAgents") do |table|
          table.index("Entries.user_agent")
        end
      end
    end

    def create_database
      FileUtils.mkdir_p(File.dirname(@database_path))
      @database = Groonga::Database.create(:path => @database_path,
                                           :context => @context)
    end

    def ensure_tables
      create_tables
    end
  end
end
