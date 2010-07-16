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

class MiddlewareJSONPTest < Test::Unit::TestCase
  include RackngaTestUtils

  def app
    application = Proc.new do |environment|
      @environment = environment
      [200,
       {"Content-Type" => "application/json"},
       [@body]]
    end
    jsonp = Racknga::Middleware::JSONP.new(application)
    Proc.new do |environment|
      environment = @update_environment.call(environment) if @update_environment
      jsonp.call(environment)
    end
  end

  def setup
    @cache_key_key = "racknga.cache.key"
    @environment = nil
    @body = "{}"
    @update_environment = nil
  end

  def test_no_jsonp
    get "/"
    assert_equal(@body, webrat_session.response.body)
  end

  def test_jsonp
    get "/?callback=jsonp_callback"
    assert_equal("jsonp_callback(#{@body});",
                 webrat_session.response.body)
  end

  def test_no_jsonp_cache_key
    get "/"
    assert_nil(@environment[@cache_key_key])
  end

  def test_jsonp_cache_key
    get "/?callback=jsonp_callback"
    assert_equal("/",
                 @environment[@cache_key_key])
  end

  def test_jsonp_cache_key_with_parameters
    get "/?query=ruby&callback=jsonp_callback&_=1279288762"
    assert_equal("/?query=ruby",
                 @environment[@cache_key_key])
  end

  def test_jsonp_cache_key_exist
    @update_environment = Proc.new do |environment|
      environment[@cache_key_key] = "pc"
      environment
    end
    get "/?callback=jsonp_callback"
    assert_equal("pc:/",
                 @environment[@cache_key_key])
  end
end
