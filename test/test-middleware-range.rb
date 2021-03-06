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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

module MiddlewareRangeTests
  include RackngaTestUtils

  def app
    application = Proc.new do |environment|
      @environment = environment
      [200,
       {
         "Content-Type" => "video/ogv",
         "Content-Length" => @body.bytesize.to_s,
         "Last-Modified" => @ogv.mtime.httpdate,
         "ETag" => @etag,
       },
       application_body]
    end
    Racknga::Middleware::Range.new(application)
  end

  def setup
    @ogv = fixtures_dir + "rabbit-theme-change.ogv"
    @ogv.open("rb") do |file|
      @body = file.read.force_encoding("ASCII-8BIT")
    end
    stat = @ogv.stat
    @etag = "%x-%x-%x" % [stat.ino, stat.size, stat.mtime.to_i * 1_000_000]
    Capybara.app = app
  end

  def test_both
    get("/", {}, {"HTTP_RANGE" => "bytes=200-499"})

    assert_response(206,
                    "300",
                    "bytes 200-499/#{@body.bytesize}",
                    @body[200, 300])
  end

  def test_first_byte_only
    get("/", {}, {"HTTP_RANGE" => "bytes=200-"})

    data_length = @body.bytesize
    expected_bytes = data_length - 200
    assert_response(206,
                    "#{expected_bytes}",
                    "bytes 200-#{data_length - 1}/#{data_length}",
                    @body[200, expected_bytes])
  end

  def test_last_byte_only
    get("/", {}, {"HTTP_RANGE" => "bytes=-200"})

    data_length = @body.bytesize
    first_byte = data_length - 200
    assert_response(206,
                    "200",
                    "bytes #{first_byte}-#{data_length - 1}/#{data_length}",
                    @body[data_length - 200, 200])
  end

  def test_no_position
    get("/", {}, {"HTTP_RANGE" => "bytes=-"})

    assert_response(416, "0", nil, "")
  end

  def test_if_range_date
    get("/",
        {},
        {
          "HTTP_RANGE" => "bytes=200-499",
          "HTTP_IF_RANGE" => @ogv.mtime.httpdate,
        })

    data_length = @body.bytesize
    assert_response(206, "300", "bytes 200-499/#{data_length}", @body[200, 300])
  end

  def test_if_range_date_expired
    get("/",
        {},
        {
          "HTTP_RANGE" => "bytes=200-499",
          "HTTP_IF_RANGE" => Time.now.httpdate,
        })

    assert_response(200, "#{@body.bytesize}", nil, @body)
  end

  def test_if_range_etag
    get("/",
        {},
        {
          "HTTP_RANGE" => "bytes=200-499",
          "HTTP_IF_RANGE" => @etag,
        })

    assert_response(206,
                    "300",
                    "bytes 200-499/#{@body.bytesize}",
                    @body[200, 300])
  end

  def test_if_range_etag_expired
    get("/",
        {},
        {
          "HTTP_RANGE" => "bytes=200-499",
          "HTTP_IF_RANGE" => "not-match-etag",
        })

    assert_response(200, "#{@body.bytesize}", nil, @body)
  end

  private
  def assert_response(status, content_length, content_range, body)
    assert_equal({
                   :status => status,
                   :content_length => content_length,
                   :content_range => content_range,
                   :body => body,
                 },
                 {
                   :status => page.status_code,
                   :content_length => page.response_headers["Content-Length"],
                   :content_range => page.response_headers["Content-Range"],
                   :body => page.source,
                 })
  end
end

class MiddlewareRangeDataTest < Test::Unit::TestCase
  include MiddlewareRangeTests

  def application_body
    [@body]
  end
end

class MiddlewareRangeFileTest < Test::Unit::TestCase
  include MiddlewareRangeTests

  def application_body
    @ogv.open("rb")
  end
end
