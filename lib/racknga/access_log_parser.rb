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

require "racknga/log_entry"
require "racknga/reverse_line_reader"

module Racknga
  # Supported formats:
  #  * combined (nginx's default format)
  #  * combined (Apache's predefined format)
  #  * combined_with_time_nginx (custom format with runtime)
  #  * combined_with_time_apache (custom format with runtime)
  #
  # Configurations:
  #  * combined
  #    * nginx
  #      log_format combined '$remote_addr - $remote_user [$time_local]  '
  #                          '"$request" $status $body_bytes_sent '
  #                          '"$http_referer" "$http_user_agent"';
  #      access_log log/access.log combined
  #    * Apache
  #      CustomLog ${APACHE_LOG_DIR}/access.log combined
  #
  #  * combined_with_time_nginx
  #    * nginx
  #      log_format combined_with_time '$remote_addr - $remote_user '
  #                                    '[$time_local, $upstream_http_x_runtime, $request_time]  '
  #                                    '"$request" $status $body_bytes_sent '
  #                                    '"$http_referer" "$http_user_agent"';
  #      access_log log/access.log combined_with_time
  #
  #  * combined_with_time_apache
  #    * Apache
  #      LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\" %{X-Runtime}o %D" combined_with_time
  #      CustomLog ${APACHE_LOG_DIR}/access.log combined_with_time
  class AccessLogParser
    include Enumerable

    class FormatError < StandardError
    end

    def initialize(line_reader)
      @line_reader = line_reader
    end

    def each
      @line_reader.each do |line|
        line.force_encoding("UTF-8")
        yield(parse_line(line)) if line.valid_encoding?
      end
    end

    private
    REMOTE_ADDRESS = "[^\\x20]+"
    REMOTE_USER = "[^\\x20]+"
    TIME_LOCAL = "[^\\x20]+\\x20\\+\\d{4}"
    RUNTIME = "(?:[\\d.]+|-)"
    REQUEST_TIME = "[\\d.]+"
    REQUEST = ".*?"
    STATUS = "\\d{3}"
    BODY_BYTES_SENT = "(?:\\d+|-)"
    HTTP_REFERER = ".*?"
    HTTP_USER_AGENT = "(?:\\\"|[^\"])*?"
    COMBINED_FORMAT =
      /^(#{REMOTE_ADDRESS})\x20
        -\x20
        (#{REMOTE_USER})\x20
        \[(#{TIME_LOCAL})(?:,\x20(.+))?\]\x20+
        "(#{REQUEST})"\x20
        (#{STATUS})\x20
        (#{BODY_BYTES_SENT})\x20
        "(#{HTTP_REFERER})"\x20
        "(#{HTTP_USER_AGENT})"
        (?:\x20(.+))?$/x
    def parse_line(line)
      case line
      when COMBINED_FORMAT
        last_match = Regexp.last_match
        options = {}
        options[:remote_address] = last_match[1]
        options[:remote_user] = last_match[2]
        options[:time_local] = parse_local_time(last_match[3])
        if last_match[4]
          if /\A(#{RUNTIME}), (#{REQUEST_TIME})\z/ =~ last_match[4]
            time_match = Regexp.last_match
            options[:runtime] = time_match[1]
            options[:request_time] = time_match[2]
          else
            message = "expected 'RUNTIME, REQUEST_TIME' time format: " +
                      "<#{last_match[4]}>: <#{line}>"
            raise FormatError.new(message)
          end
        end
        options[:request] = last_match[5]
        options[:status] = last_match[6].to_i
        options[:body_bytes_sent] = last_match[7]
        options[:http_referer] = last_match[8]
        options[:http_user_agent] = last_match[9]
        if last_match[10]
          if /\A(#{RUNTIME}) (#{REQUEST_TIME})\z/ =~ last_match[10]
            time_match = Regexp.last_match
            runtime = time_match[1]
            request_time = time_match[2]
            request_time = request_time.to_i * 0.000_001 if request_time
            options[:runtime] = runtime
            options[:request_time] = request_time
          else
            message = "expected 'RUNTIME REQUEST_TIME' time format: " +
                      "<#{last_match[10]}>: <#{line}>"
            raise FormatError.new(message)
          end
        end
        LogEntry.new(options)
      else
        raise FormatError.new("unsupported format log entry: <#{line}>")
      end
    end

    def parse_local_time(token)
      day, month, year, hour, minute, second, _time_zone = token.split(/[\/: ]/)
      Time.local(year, month, day, hour, minute, second)
    end
  end

  class ReversedAccessLogParser < AccessLogParser
    def initialize(line_reader)
      @line_reader = ReverseLineReader.new(line_reader)
    end
  end
end
