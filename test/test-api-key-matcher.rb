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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

class APIKeyMatcherTest < Test::Unit::TestCase
  include RackngaTestUtils

  def setup
    @api_key_matcher = api_key_matcher
  end

  def test_valid_key
    assert_matched(query_parameter, valid_key)
  end

  def test_invalid_key
    assert_not_matched(query_parameter, "invalidkey")
  end

  def test_empty_key
    assert_not_matched(query_parameter, "")
  end

  def test_empty_query_parameter
    assert_not_matched("", valid_key)
  end

  def test_mismatched_query_parameter
    assert_not_matched("not-api-key", valid_key)
  end

  private
  def api_key_matcher
    Racknga::APIKeyMatcher.new(query_parameter, valid_api_keys)
  end

  def assert_matched(parameter, key)
    environment = generate_environment(parameter, key)
    assert_true(@api_key_matcher.authorized?(environment))
  end

  def assert_not_matched(parameter, key)
    environment = generate_environment(parameter, key)
    assert_false(@api_key_matcher.authorized?(environment))
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

  def valid_api_keys
    ["validkey", "validkey2"]
  end

  def valid_key
    valid_api_keys.first
  end
end
