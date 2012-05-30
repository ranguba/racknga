# Copyright (C) 2012  Haruka Yoshihara <kou@clear-code.com>
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

class MiddlewareAuthAPIKeyTest < Test::Unit::TestCase
  include RackngaTestUtils

  def app
    application = Proc.new do |environment|
      @environment = environment
      [
        200,
        {"Content-Type" => "application/json"},
        [@body]
      ]
    end
    authorized_api_keys =
      Racknga::APIKeys.new(@api_query_parameter, @api_keys)
    api_key_options = {
      :api_url_prefixes => [@api_url_prefix],
      :authorized_api_keys => authorized_api_keys,
      :error_response => @error_response,
      :disable_authorization => disable_authorization?
    }
    api_key = api_key_authorizer(application, api_key_options)
    Proc.new do |environment|
      api_key.call(environment)
    end
  end

  def setup
    @api_query_parameter = "api-key"
    @api_url_prefix = "/api"
    @api_keys = ["key1", "key2"]
    @body = "{}"
    @error_response = {"error" => "this api key is not authorized"}
    Capybara.app = app
  end

  def test_authorized_key
    url = generate_url(url_prefix, query_parameter, valid_key)
    visit(url)
    assert_success_response
  end

  def test_unauthorized_key
    url = generate_url(url_prefix, query_parameter, "invalidkey")
    visit(url)
    assert_failture_response
  end

  def test_unmatched_query_parameter
    url = generate_url(url_prefix, "not-api-key", valid_key)
    visit(url)
    assert_failture_response
  end

  def test_unauthorized_key_and_unmatched_query_parameter
    url = generate_url(url_prefix, "not-api-key", "invalidkey")
    visit(url)
    assert_failture_response
  end

  def test_not_api_url
    visit("/not/api/url")
    assert_success_response
  end

  private
  def disable_authorization?
    false
  end

  def api_key_authorizer(application, api_key_options)
    Racknga::Middleware::Auth::APIKey.new(application, api_key_options)
  end

  def generate_url(path, query_parameter, api_key)
    url = path
    if query_parameter
      url << "?#{query_parameter}=#{api_key}"
    end
    url
  end

  def url_prefix
    @api_url_prefix
  end

  def query_parameter
    @api_query_parameter
  end

  def valid_key
    @api_keys.first
  end

  def assert_success_response
    assert_equal(200, page.status_code)
    assert_equal(@body, page.source)
  end

  def assert_failture_response
    assert_equal(401, page.status_code)
    assert_equal(@error_response.to_json, page.source)
  end

  class DisableAuthorizationTest < self
    def test_unauthorized_key
      url = generate_url(url_prefix, query_parameter, "invalidkey")
      visit(url)
      assert_success_response
    end

    def test_unmatched_query_parameter
      url = generate_url(url_prefix, "not-api-key", valid_key)
      visit(url)
      assert_success_response
    end

    def test_unauthorized_key_and_unmatched_query_parameter
      url = generate_url(url_prefix, "not-api-key", "invalidkey")
      visit(url)
      assert_success_response
    end

    private
    def disable_authorization?
      true
    end
  end
end
