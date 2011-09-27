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

class InstanceNameTest < Test::Unit::TestCase
  include RackngaTestUtils

  def test_no_option
    footer_variables = extract_from_default_instance_name

    instance_name_options({}) do
      request
      assert_header("Proc #{default_footer(*footer_variables)}")
    end
  end

  def test_application_name
    application_name = "HelloWorld"
    footer_variables = extract_from_default_instance_name

    instance_name_options(:application_name => application_name) do
      request
      assert_header("#{application_name} " +
                    "#{default_footer(*footer_variables)}")
    end
  end

  def test_both_application_name_and_version
    application_name = "HelloWorld"
    version = 1
    footer_variables = extract_from_default_instance_name

    instance_name_options(:application_name => application_name,
                          :version => version) do
      request
      assert_header("#{application_name} v#{version} " +
                    "#{default_footer(*footer_variables)}")
    end
  end

  private
  def prepare_rack_stack(options)
    application = create_minimal_application
    instance_name = create_instance_name(application, options)
    outermost_wrapper_middleware(instance_name)
  end

  def outermost_wrapper_middleware(application)
    Proc.new do |environment|
      application.call(environment)
    end
  end

  def create_instance_name(*arguments)
    Racknga::Middleware::InstanceName.new(*arguments)
  end

  def default_instance_name
    @default_instance_name ||=
      create_instance_name(create_minimal_application).freeze
  end

  def extract_from_default_instance_name
    server = default_instance_name.server
    user = default_instance_name.user
    revision = default_instance_name.revision
    branch = default_instance_name.branch
    ruby = default_instance_name.ruby

    [server, user, revision, branch, ruby]
  end

  def default_footer(server, user, revision, branch, ruby)
    "(at #{revision} (#{branch})) on #{server} by #{user} with #{ruby}"
  end

  def create_minimal_application
    Proc.new do |environment|
      [200,
       {"Content-Type" => "text/plain"},
       ["Hello world."]]
    end
  end

  def request
    get("/")
  end

  def instance_name_options(options)
    Capybara.app = prepare_rack_stack(options)
    yield
  end

  def assert_header(expected_header)
    actual_header = page.response_headers["X-Responsed-By"]
    assert_equal(expected_header, actual_header)
  end
end
