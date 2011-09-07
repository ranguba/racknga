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

class NginxRawURITest < Test::Unit::TestCase
  include RackngaTestUtils

  class PseudoNginx
    def initialize(application)
      @application = application
    end

    def call(environment)
      mimic_nginx_behavior(environment)

      @application.call(environment)
    end

    private
    def mimic_nginx_behavior(environment)
      environment["HTTP_X_RAW_REQUEST_URI"] = environment["PATH_INFO"]
      environment["PATH_INFO"] = Rack::Utils.unescape(environment["PATH_INFO"])
    end
  end

  def app
    application = Proc.new do |environment|
      @environment = environment

      response
    end

    raw_uri = Racknga::Middleware::NginxRawURI.new(application)
    pseudo_nginx = PseudoNginx.new(raw_uri)

    pseudo_nginx
  end

  def setup
    Capybara.app = app
  end

  def test_slash
    path_info_with_slash = "/keywords/GNU%2fLinux"

    visit(path_info_with_slash)
    assert_equal(path_info_with_slash, path_info)
  end

  private
  def response
    [200, {"Content-Type" => "plain/text"}, ["this is a response."]]
  end

  def path_info
    @environment["PATH_INFO"]
  end
end
