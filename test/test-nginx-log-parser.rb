# -*- coding: utf-8 -*-
#
# Copyright (C) 2011  Ryo Onodera <onodera@clear-code.com>
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

require 'stringio'

module NginxAccessLogParserTests
  module Data
    private
    def time_log_component
      times = ["03/Aug/2011:16:58:01 +0900", runtime, request_time].compact
      "[#{times.join(', ')}]"
    end

    def usual_log_line
      "127.0.0.1 - - #{time_log_component}  " +
        "\"GET / HTTP/1.1\" 200 613 \"-\" \"Ruby\""
    end

    def usual_log_entry_options
      {
        :remote_address => "127.0.0.1",
        :remote_user => "-",
        :time_local => Time.local(2011, 8, 3, 16, 58, 1),
        :runtime => runtime,
        :request_time => request_time,
        :request => "GET / HTTP/1.1",
        :status => 200,
        :body_bytes_sent => 613,
        :http_referer => "-",
        :http_user_agent => "Ruby",
      }
    end

    def usual_log_entry
      create_log_entry(usual_log_entry_options)
    end

    def not_found_log_line
      "127.0.0.1 - - #{time_log_component}  " +
        "\"GET /the-truth.html HTTP/1.1\" 404 613 \"-\" \"Ruby\""
    end

    def not_found_log_entry
      options = {
        :status => 404,
        :request => "GET /the-truth.html HTTP/1.1",
      }
      create_log_entry(usual_log_entry_options.merge(options))
    end

    def utf8_path
      "/トップページ.html"
    end

    def valid_utf8_log_line
      path = utf8_path

      "127.0.0.1 - - #{time_log_component}  " +
        "\"GET #{path} HTTP/1.1\" 200 613 \"-\" \"Ruby\""
    end

    def valid_utf8_log_entry
      options = {
        :request => "GET #{utf8_path} HTTP/1.1",
      }
      create_log_entry(usual_log_entry_options.merge(options))
    end


    def garbled_path
      "/#{Random.new.bytes(10)}".force_encoding(Encoding::UTF_8)
    end

    def invalid_utf8_log_line
      path = garbled_path

      "127.0.0.1 - - #{time_log_component}  " +
        "\"GET #{path} HTTP/1.1\" 200 613 \"-\" \"Ruby\""
    end

    def ipv6_log_line
      "::1 - - #{time_log_component}  " +
        "\"GET / HTTP/1.1\" 200 613 \"-\" \"Ruby\""
    end

    def ipv6_log_entry
      options = {
        :remote_address => "::1",
      }
      create_log_entry(usual_log_entry_options.merge(options))
    end

    def apache_combined_log_line
      "127.0.0.1 - - #{time_log_component} " +
        "\"GET / HTTP/1.1\" 200 613 \"-\" \"Ruby\""
    end

    def apache_combined_log_entry
      usual_log_entry
    end

    def no_body_bytes_sent_log_line
      "127.0.0.1 - - #{time_log_component}  " +
        "\"GET / HTTP/1.1\" 200 - \"-\" \"Ruby\""
    end

    def no_body_bytes_sent_log_entry
      options = {
        :body_bytes_sent => 0,
      }
      create_log_entry(usual_log_entry_options.merge(options))
    end

    def bad_log_line
      "bad"
    end
  end

  module Environment
    private
    def create_log_entry(options)
      Racknga::LogEntry.new(options)
    end

    def create_log_file(string)
      StringIO.new(string)
    end

    def create_log_parser(file)
      Racknga::NginxAccessLogParser.new(file)
    end

    def create_reversed_log_parser(file)
      Racknga::ReversedNginxAccessLogParser.new(file)
    end

    def join_lines(*lines)
      lines.collect do |line|
        line + "\n"
      end.join
    end

    def parse(string)
      file = create_log_file(string)
      parser = create_log_parser(file)
      parser.collect.to_a
    end

    def reversed_parse(string)
      file = create_log_file(string)
      parser = create_reversed_log_parser(file)
      parser.collect.to_a
    end
  end

  module Tests
    def test_usual_log
      accesses = parse(join_lines(usual_log_line))
      access = accesses.first
      assert_equal(usual_log_entry, access)
    end

    def test_ipv6_log
      accesses = parse(join_lines(ipv6_log_line))
      assert_equal([ipv6_log_entry],
                   accesses)
    end

    def test_apache_combined_log
      accesses = parse(join_lines(apache_combined_log_line))
      assert_equal([apache_combined_log_entry],
                   accesses)
    end

    def test_no_body_bytes_sent_log
      accesses = parse(join_lines(no_body_bytes_sent_log_line))
      assert_equal([no_body_bytes_sent_log_entry],
                   accesses)
    end

    def test_no_log
      accesses = parse(join_lines())
      assert_equal([], accesses)
    end

    def test_multiple_logs
      accesses = parse(join_lines(usual_log_line,
                                  usual_log_line,
                                  not_found_log_line))
      assert_equal([usual_log_entry,
                    usual_log_entry,
                    not_found_log_entry],
                   accesses)
    end

    def test_reversed_parse
      accesses = reversed_parse(join_lines(usual_log_line,
                                           usual_log_line,
                                           not_found_log_line))
      assert_equal([usual_log_entry,
                    usual_log_entry,
                    not_found_log_entry].reverse,
                   accesses)
    end

    def test_bad_log
      assert_raise(Racknga::NginxAccessLogParser::FormatError) do
        parse(join_lines(bad_log_line))
      end
    end

    def test_invalid_utf8_log_line_ignored
      accesses = parse(join_lines(valid_utf8_log_line,
                                  invalid_utf8_log_line,
                                  valid_utf8_log_line))
      assert_equal([valid_utf8_log_entry,
                    valid_utf8_log_entry],
                   accesses)
    end
  end

  class CombinedLogTest < Test::Unit::TestCase
    include Environment
    include Data
    include Tests

    def runtime
      nil
    end

    def request_time
      nil
    end
  end

  class CombinedWithTimeLogTest < Test::Unit::TestCase
    include Environment
    include Data
    include Tests

    def runtime
      0.000573
    end

    def request_time
      0.001
    end
  end
end
