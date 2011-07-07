# Copyright (C) 2011  Kouhei Sutou <kou@clear-code.com>
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

class MiddlewareCacheTest < Test::Unit::TestCase
  include RackngaTestUtils

  def app
    application = Proc.new do |environment|
      @environment = environment
      [200,
       {"Content-Type" => "application/json"},
       [@body]]
    end
    cache_options = {
      :database_path => @database_path.to_s,
    }
    @cache = Racknga::Middleware::Cache.new(application, cache_options)
    Proc.new do |environment|
      environment = @update_environment.call(environment) if @update_environment
      @cache.call(environment)
    end
  end

  def setup
    @cache_key_key = "racknga.cache.key"
    @environment = nil
    @body = "{}"
    @update_environment = nil
    setup_temporary_directory
    @database_path = @temporary_directory + "cache/db"
    Capybara.app = app
  end

  def setup_temporary_directory
    @temporary_directory = Pathname.new(__FILE__).dirname + "tmp"
    FileUtils.rm_rf(@temporary_directory)
    FileUtils.mkdir_p(@temporary_directory)
  end

  def teardown
    teardown_temporary_directory
  end

  def teardown_temporary_directory
    FileUtils.rm_rf(@temporary_directory)
  end

  def test_4096_length_path
    responses = @cache.database.responses
    assert_equal([], responses.to_a.collect(&:key))
    path = "/" + "x" * 4095
    visit(path)
    assert_equal([path], responses.to_a.collect(&:key))
  end

  def test_4096_length_over_path
    responses = @cache.database.responses
    assert_equal([], responses.to_a.collect(&:key))
    path = "/" + "x" * 4096
    visit(path)
    assert_equal([Digest::SHA1.hexdigest(path)],
                 responses.to_a.collect(&:key))
  end
end
