# -*- coding: utf-8 -*-
#
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

module Racknga
  class ReverseLineReader
    def initialize(io)
      @io = io
      @io.seek(0, IO::SEEK_END)
      @buffer = ""
      @data = ""
    end

    def each
      separator = $/
      separator_length = separator.length
      while read_to_buffer
        loop do
          index = @buffer.rindex(separator, @buffer.length - 1 - separator_length)
          break if index.nil? or index.zero?
          last_line = @buffer.slice!((index + separator_length)..-1)
          yield(last_line)
        end
      end
      yield(@buffer) unless @buffer.empty?
    end

    private
    BYTES_PER_READ = 4096
    def read
      position = @io.pos
      if position < BYTES_PER_READ
        bytes_per_read = position
      else
        bytes_per_read = BYTES_PER_READ
      end

      if bytes_per_read.zero?
        @data.replace("")
      else
        @io.seek(-bytes_per_read, IO::SEEK_CUR)
        @io.read(bytes_per_read, @data)
        @io.seek(-bytes_per_read, IO::SEEK_CUR)
      end

      @data
    end

    def read_to_buffer
      data = read.force_encoding("BINARY")
      if data.empty?
        false
      else
        @buffer.insert(0, data)
        true
      end
    end
  end

  # configure nginx to match access log format to this parser like this:
  #
  #   log_format combined_with_time '$remote_addr - $remote_user [$time_local,'
  #                                 ' $upstream_http_x_runtime, $request_time]  '
  #                                 '"$request" $status $body_bytes_sent '
  #                                 '"$http_referer" "$http_user_agent"';
  #   access_log log/access.log combined_with_time
  class NginxAccessLogParser
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

    REMOTE_ADDRESS = '(?:\d{1,3}\.){3}\d{1,3}'
    REMOTE_USER = '[^ ]+'
    TIME_LOCAL = '[^ ]+ \+0900'
    RUNTIME = '(?:[\d.]+|-)'
    REQUEST_TIME = '[\d.]+'
    REQUEST = '.*?'
    STATUS = '\d{3}'
    BODY_BYTES_SENT = '\d+'
    HTTP_REFERER = '.*?'
    HTTP_USER_AGENT = '(?:\\"|[^\"])*?' # '
    LOG_FORMAT =
      /\A(#{REMOTE_ADDRESS}) - (#{REMOTE_USER}) \[(#{TIME_LOCAL}), (#{RUNTIME}), (#{REQUEST_TIME})\]  "(#{REQUEST})" (#{STATUS}) (#{BODY_BYTES_SENT}) "(#{HTTP_REFERER})" "(#{HTTP_USER_AGENT})"\n\z/
    def parse_line(line)
      if line =~ LOG_FORMAT
        last_match = Regexp.last_match
        options = {}
        options[:remote_address] = last_match[1]
        options[:remote_user] = last_match[2]
        parse_time_local(last_match[3], options)
        options[:runtime] = last_match[4].to_f
        options[:request_time] = last_match[5].to_f
        options[:request] = last_match[6]
        options[:status] = last_match[7].to_i
        options[:body_bytes_sent] = last_match[8].to_i
        options[:http_referer] = last_match[9]
        options[:http_user_agent] = last_match[10]
        LogEntry.new(options)
      else
        raise FormatError.new("ill-formatted log entry: #{line.inspect} !~ #{LOG_FORMAT}")
      end
    end

    def parse_time_local(token, options)
      day, month, year, hour, minute, second, _time_zone = token.split(/[\/: ]/)
      options[:time_local] = Time.local(year, month, day, hour, minute, second)
    end
  end

  class ReversedNginxAccessLogParser < NginxAccessLogParser
    def initialize(line_reader)
      @line_reader = ReverseLineReader.new(line_reader)
    end
  end

  class LogEntry
    ATTRIBUTES = [
      :remote_address,
      :remote_user,
      :time_local,
      :runtime,
      :request_time,
      :request,
      :status,
      :body_bytes_sent,
      :http_referer,
      :http_user_agent,
    ]

    attr_reader *ATTRIBUTES
    def initialize(options=nil)
      options ||= {}
      @remote_address = options[:remote_address]
      @remote_user = options[:remote_user]
      @time_local = options[:time_local] || Time.at(0)
      @runtime = options[:runtime] || 0.0
      @request_time = options[:request_time] || 0.0
      @request = options[:request]
      @status = options[:status]
      @body_bytes_sent = options[:body_bytes_sent]
      @http_referer = options[:http_referer]
      @http_user_agent = options[:http_user_agent]
    end

    def attributes
      ATTRIBUTES.collect do |attribute|
        __send__(attribute)
      end
    end

    def ==(other)
      attributes == other.attributes
    end
  end
end
