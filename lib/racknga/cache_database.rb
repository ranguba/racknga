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

module Racknga
  class CacheDatabase
    def initialize(database_path)
      @database_path = database_path
      @context = Groonga::Context.new(:encoding => :none)
      ensure_database
    end

    def responses
      @context["Responses"]
    end

    def purge_old_responses(threshold_time_stamp=nil)
      threshold_time_stamp ||= Time.now
      responses.each do |response|
        response.remove if response.created_at < threshold_time_stamp
      end
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

    private
    def create_responses_table
      Groonga::Schema.define(:context => @context) do |schema|
        schema.create_table("Responses",
                            :type => :hash,
                            :key_type => "ShortText") do |table|
          table.uint32("status")
          table.short_text("headers")
          table.text("body")
          table.time("created_at")
        end
      end
    end

    def create_database
      FileUtils.mkdir_p(File.dirname(@database_path))
      @database = Groonga::Database.create(:path => @database_path,
                                           :context => @context)
    end

    def ensure_tables
      return if responses
      create_responses_table
    end
  end
end
