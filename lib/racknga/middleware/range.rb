# -*- coding: utf-8 -*-
#
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

require 'time'

module Racknga
  module Middleware
    # This is a middleware that provides HTTP range request
    # (partial request) support. For example, HTTP range
    # request is used for playing a video on the way.
    #
    # Usage:
    #   require "racknga"
    #   use Racknga::Middleware::Range
    #   run YourApplication
    class Range
      def initialize(application)
        @application = application
      end

      # For Rack.
      def call(environment)
        status, headers, body = @application.call(environment)
        return [status, headers, body] if status != 200

        headers = Rack::Utils::HeaderHash.new(headers)
        headers["Accept-Ranges"] = "bytes"
        request = Rack::Request.new(environment)
        range = request.env["HTTP_RANGE"]
        if range and /\Abytes=(\d*)-(\d*)\z/ =~ range
          first_byte, last_byte = $1, $2
          status, headers, body = apply_range(status, headers, body, request,
                                              first_byte, last_byte)
        end
        [status, headers.to_hash, body]
      end

      private
      def apply_range(status, headers, body, request, first_byte, last_byte)
        unless use_range?(request, headers)
          return [status, headers, body]
        end
        length = guess_length(headers, body)
        return [status, headers.to_hash, body] if length.nil?

        if first_byte.empty? and last_byte.empty?
          headers["Content-Length"] = "0"
          return [Rack::Utils.status_code(:requested_range_not_satisfiable),
                  headers,
                  []]
        end

        if last_byte.empty?
          last_byte = length - 1
        else
          last_byte = last_byte.to_i
        end
        if first_byte.empty?
          first_byte = length - last_byte
          last_byte = length - 1
        else
          first_byte = first_byte.to_i
        end

        byte_range_spec = "#{first_byte}-#{last_byte}/#{length}"
        range_length = last_byte - first_byte + 1
        headers["Content-Range"] = "bytes #{byte_range_spec}"
        headers["Content-Length"] = range_length.to_s
        stream = RangeStream.new(body, first_byte, range_length)
        if body.respond_to?(:to_path)
          def stream.to_path
            @body.to_path
          end
        end
        [Rack::Utils.status_code(:partial_content),
         headers,
         stream]
      end

      def use_range?(request, headers)
        if_range = request.env["HTTP_IF_RANGE"]
        return true if if_range.nil?

        if /\A(?:Mo|Tu|We|Th|Fr|Sa|Su)/ =~ if_range
          last_modified = headers["Last-Modified"]
          return false if last_modified.nil?
          begin
            if_range = Time.httpdate(if_range)
            last_modified = Time.httpdate(last_modified)
          rescue ArgumentError
            return true
          end
          if_range == last_modified
        else
          if_range == headers["ETag"]
        end
      end

      def guess_length(headers, body)
        length = headers["Content-Length"]
        return length.to_i unless length.nil?
        return body.stat.size if body.respond_to?(:stat)
        nil
      end

      # @private
      class RangeStream
        def initialize(body, first_byte, length)
          @body = body
          @first_byte = first_byte
          @length = length
        end

        def each
          if @body.respond_to?(:seek)
            @body.seek(@first_byte)
            start = 0
          else
            start = @first_byte
          end
          rest = @length

          @body.each do |chunk|
            if chunk.respond_to?(:encoding)
              if chunk.encoding != Encoding::ASCII_8BIT
                chunk = chunk.dup.force_encoding(Encoding::ASCII_8BIT)
              end
            end

            chunk_size = chunk.size
            if start > 0
              if chunk_size < start
                start -= chunk_size
                next
              else
                chunk = chunk[start..-1]
                chunk_size -= start
                start = 0
              end
            end
            if rest > chunk_size
              yield(chunk)
              rest -= chunk_size
            else
              yield(chunk[0, rest])
              rest -= rest
            end
            break if rest <= 0
          end
        end
      end
    end
  end
end
