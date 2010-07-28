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

require 'fileutils'

require 'groonga'

module Racknga
  class LogDatabase
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

    def purge_old_entries(base_time=nil)
      base_time ||= Time.now - 60 * 60 * 24
      entries.select do |record|
        record.time_stamp < base_time
      end.each do |record|
        record.key.delete
      end
    end

    private
    def create_tables
      Groonga::Schema.define(:context => @context) do |schema|
        schema.create_table("Tags",
                            :type => :hash,
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
