# -*- coding: utf-8 -*-
#
# Copyright (C) 2012  Haruka Yoshihara <yoshihara@clear-code.com>
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

class APIKeysTest < Test::Unit::TestCase
  include RackngaTestUtils

  def setup
    @api_keys = Racknga::APIKeys.new(query_parameter, api_keys)
  end

  def test_matched_key
    assert_matched(query_parameter, api_key)
  end

  def test_not_matched_key
    assert_not_matched(query_parameter, "notapikey")
  end

  def test_empty_key
    assert_not_matched(query_parameter, "")
  end

  def test_empty_query_parameter
    assert_not_matched("", api_key)
  end

  def test_mismatched_query_parameter
    assert_not_matched("not-api-key", api_key)
  end

  private
  def assert_matched(parameter, key)
    environment = generate_environment(parameter, key)
    assert_true(@api_keys.include?(environment))
  end

  def assert_not_matched(parameter, key)
    environment = generate_environment(parameter, key)
    assert_false(@api_keys.include?(environment))
  end

  def generate_environment(parameter, key)
    url = "http://example.org"

    unless parameter.empty?
      api_url = "#{url}?#{parameter}=#{key}"
    else
      api_url = url
    end

    Rack::MockRequest.env_for(api_url)
  end

  def query_parameter
    "api-key"
  end

  def api_keys
    ["key", "key2"]
  end

  def api_key
    api_keys.first
  end
end
