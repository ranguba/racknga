# -*- coding: utf-8 -*-
#
# Copyright (C) 2010  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License version 2.1 as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'time'
require 'net/smtp'
require 'etc'
require 'socket'

module Racknga
  # Ruby 1.9 only. 1.8 isn't supported.
  class ExceptionMailNotifier
    def initialize(options)
      @options = Utils.normalize_options(options || {})
    end

    def notify(exception, environment)
      host = @options[:host]
      return if host.nil?
      return if to.empty?
      mail = format(exception, environment)
      Net::SMTP.start(host, @options[:port]) do |smtp|
        smtp.send_message(mail, from, *to)
      end
    end

    private
    def format(exception, environment)
      header = format_header(exception, environment)
      body = format_body(exception, environment)
      mail = "#{header}\r\n#{body}"
      mail.force_encoding("utf-8")
      begin
        mail = mail.encode(charset)
      rescue EncodingError
      end
      mail.force_encoding("ASCII-8BIT")
    end

    def format_header(exception, environment)
      <<-EOH
MIME-Version: 1.0
Content-Type: Text/Plain; charset=#{charset}
Content-Transfer-Encoding: #{transfer_encoding}
From: #{from}
To: #{to.join(', ')}
Subject: #{encode_subject(subject(exception, environment))}
Date: #{Time.now.rfc2822}
EOH
    end

    def format_body(exception, environment)
      request = Rack::Request.new(environment)
      body = <<-EOB
URL: #{request.url}
--
#{exception.class}: #{exception}
--
#{exception.backtrace.join("\n")}
EOB
      params = request.params
      max_key_size = (environment.keys.collect(&:size) +
                      params.keys.collect(&:size)).max
      body << <<-EOE
--
Environments:
EOE
      environment.sort_by {|key, value| key}.each do |key, value|
        body << "  %*s: <%s>\n" % [max_key_size, key, value]
      end

      unless params.empty?
        body << <<-EOE
--
Parameters:
EOE
        params.sort_by {|key, value| key}.each do |key, value|
          body << "  %#{max_key_size}s: <%s>\n" % [key, value]
        end
      end

      body
    end

    def subject(exception, environment)
      [@options[:subject_label], exception.to_s].compact.join(' ')
    end

    def to
      @to ||= ensure_array(@options[:to]) || []
    end

    def ensure_array(maybe_array)
      maybe_array = [maybe_array] if maybe_array.is_a?(String)
      maybe_array
    end

    def from
      @from ||= @options[:from] || guess_from
    end

    def guess_from
      name = Etc.getpwuid(Process.uid).name
      host = Socket.gethostname
      "#{name}@#{host}"
    end

    def charset
      @options[:charset] || 'utf-8'
    end

    def transfer_encoding
      case charset
      when /\Autf-8\z/i
        "8bit"
      else
        "7bit"
      end
    end

    def encode_subject(subject)
      case charset
      when /\Aiso-2022-jp\z/i
        NKF.nkf('-Wj -M', subject)
      else
        NKF.nkf('-Ww -M', subject)
      end
    end
  end
end
