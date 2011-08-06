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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'fileutils'

require 'groonga'

module Racknga
  # This is a cache database based on groonga. It is used by
  # Racknga::Middleware::Cache.
  #
  # Normally, #purge_old_responses is only used for cache
  # maintenance.
  class CacheDatabase
    def initialize(database_path)
      @database_path = database_path
      @context = Groonga::Context.new(:encoding => :none)
      ensure_database
    end

    def responses
      @context["Responses"]
    end

    def configurations
      @context["Configurations"]
    end

    def configuration
      configurations["default"]
    end

    # Purges old responses. To clear old caches, you should
    # call this method periodically or after data update.
    #
    # You can call this method by the different
    # process from your Rack application
    # process. (e.g. cron.) It's multi process safe.
    def purge_old_responses
      age_modulo = 2 ** 32
      age = configuration.age
      previous_age = (age - 1).modulo(age_modulo)
      configuration.age = (age + 1).modulo(age_modulo)

      responses.each do |response|
        response.delete if response.age == previous_age
      end
    end

    def ensure_database
      if File.exist?(@database_path)
        @database = Groonga::Database.open(@database_path, :context => @context)
      else
        create_database
      end
      ensure_tables
      ensure_default_configuration
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
          table.text("body", :compress => :zlib)
          table.short_text("checksum")
          table.uint32("age")
          table.time("created_at")
        end
      end
    end

    def create_configurations_table
      Groonga::Schema.define(:context => @context) do |schema|
        schema.create_table("Configurations",
                            :type => :hash,
                            :key_type => "ShortText") do |table|
          table.uint32("age")
        end
      end
    end

    def create_database
      FileUtils.mkdir_p(File.dirname(@database_path))
      @database = Groonga::Database.create(:path => @database_path,
                                           :context => @context)
    end

    def ensure_tables
      create_configurations_table
      create_responses_table
    end

    def ensure_default_configuration
      configurations.add("default")
    end
  end
end
