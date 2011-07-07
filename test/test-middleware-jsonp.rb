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
    Capybara.app = app
  end

  def test_no_jsonp
    visit("/")
    assert_not_jsonp_response(@body)
  end

  def test_jsonp
    visit("/?callback=jsonp_callback")
    assert_jsonp_response("jsonp_callback(#{@body});")
  end

  def test_no_jsonp_cache_key
    visit("/")
    assert_nil(@environment[@cache_key_key])
  end

  def test_jsonp_cache_key
    visit("/?callback=jsonp_callback")
    assert_equal("/",
                 @environment[@cache_key_key])
  end

  def test_jsonp_cache_key_with_parameters
    visit("/?query=ruby&callback=jsonp_callback&_=1279288762")
    assert_equal("/?query=ruby",
                 @environment[@cache_key_key])
  end

  def test_jsonp_cache_key_exist
    @update_environment = Proc.new do |environment|
      environment[@cache_key_key] = "pc"
      environment
    end
    visit("/?callback=jsonp_callback")
    assert_equal("pc:/",
                 @environment[@cache_key_key])
  end

  private
  def assert_jsonp_response(body)
    assert_equal({
                   :content_type => "text/javascript",
                   :body => body,
                 },
                 {
                   :content_type => page.response_headers["Content-Type"],
                   :body => page.source,
                 })
  end

  def assert_not_jsonp_response(body)
    assert_equal({
                   :content_type => "application/json",
                   :body => body,
                 },
                 {
                   :content_type => page.response_headers["Content-Type"],
                   :body => page.source,
                 })
  end
end
