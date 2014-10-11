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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

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
end
