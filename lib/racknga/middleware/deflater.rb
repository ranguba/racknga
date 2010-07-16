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

module Racknga
  module Middleware
    class Deflater
      def initialize(application, options={})
        @application = application
        @deflater = Rack::Deflater.new(@application)
        @options = Utils.normalize_options(options || {})
      end

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
