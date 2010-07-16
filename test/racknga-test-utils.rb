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

require 'rubygems'

require 'rack/test'
require 'webrat'
require 'json'

require 'racknga'
require 'racknga/middleware/cache'

Webrat.configure do |config|
  config.mode = :rack
end

module RackngaTestUtils
  include Rack::Test::Methods
  include Webrat::Methods
  include Webrat::Matchers
end
