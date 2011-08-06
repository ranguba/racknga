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

module Racknga
  module Middleware
    # This is a middleware that deflates response except for
    # IE6. If your Rack application need support IE6, use
    # this middleware instead of Rack::Deflater.
    #
    # Usage:
    #   require "racknga"
    #
    #   use Racknga::Middleware::Deflater
    #   run YourApplication
    #
    # You can use this middleware with
    # Racknga::Middleware::Cache. You *should* use this
    # middleware before the cache middleware:
    #   use Racknga::Middleawre::Deflater
    #   use Racknga::Middleawre::Cache, :database_path => "var/cache/db"
    #   run YourApplication
    #
    # If you use this middleware after the cache middleware,
    # you get two problems. It's the first problem pattern
    # that the cache middleware may return deflated response
    # to IE6. It's the second problem pattern that the cache
    # middleware may return not deflated response to no IE6
    # user agent. Here are examples:
    #
    # Problem case:
    #   use Racknga::Middleawre::Cache, :database_path => "var/cache/db"
    #   use Racknga::Middleawre::Deflater
    #   run YourApplication
    #
    # Problem pattern1:
    #   http://localhost:9292/ by Firefox -> no cache. cache deflated response.
    #   http://localhost:9292/ by IE6     -> use deflated response cache.
    #
    # Problem pattern2:
    #   http://localhost:9292/ by IE6     -> no cache. cache not deflated response.
    #   http://localhost:9292/ by Firefox -> use not deflated response cache.
    class Deflater
      def initialize(application, options={})
        @application = application
        @deflater = Rack::Deflater.new(@application)
        @options = Utils.normalize_options(options || {})
      end

      # @private
      def call(environment)
        if ie6?(environment)
          @application.call(environment)
        else
          @deflater.call(environment)
        end
      end

      private
      def ie6?(environment)
        /MSIE 6.0;/ =~ (environment["HTTP_USER_AGENT"] || '')
      end
    end
  end
end
