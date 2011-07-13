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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'time'
require 'net/smtp'
require 'etc'
require 'socket'
require 'nkf'

require 'racknga/utils'

module Racknga
  # Ruby 1.9 only. 1.8 isn't supported.
  class ExceptionMailNotifier
    def initialize(options)
      @options = Utils.normalize_options(options || {})
      reset_limitation
    end

    def notify(exception, environment)
      return if to.empty?

      if limitation_expired?
        send_report
        reset_limitation
      end

      if @mail_count < max_mail_count_in_limit_duration
        send_notification(exception, environment)
      else
        @summaries << summarize(exception, environment)
      end

      @mail_count += 1
    end

    private
    def reset_limitation
      @mail_count = 0
      @count_start_time = Time.now
      @summaries = []
    end

    def limitation_expired?
      (Time.now - @count_start_time) > limit_duration
    end

    def send(mail)
      host = @options[:host] || "localhost"
      Net::SMTP.start(host, @options[:port]) do |smtp|
        smtp.send_message(mail, from, *to)
      end
    end

    def create_mail(options)
      subject = [@options[:subject_label], options[:subject]].compact.join(' ')
      header = header(:subject => subject)

      body = options[:body]

      mail = "#{header}\r\n#{body}"
      mail.force_encoding("utf-8")
      begin
        mail = mail.encode(charset)
      rescue EncodingError
      end
      mail.force_encoding("ASCII-8BIT")
    end

    def header(options)
      <<-EOH
MIME-Version: 1.0
Content-Type: Text/Plain; charset=#{charset}
Content-Transfer-Encoding: #{transfer_encoding}
From: #{from}
To: #{to.join(', ')}
Subject: #{encode_subject(options[:subject])}
Date: #{Time.now.rfc2822}
EOH
    end

    def send_one_notification(exception, environment)
      mail = create_mail(:subject => exception.to_s,
                         :body => notification_body(exception, environment))
      send(mail)
    end

    def notification_body(exception, environment)
      request = Rack::Request.new(environment)
      body = <<-EOB
#{summarize(exception, environment)}
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

    def send_report
        subject = "summaries of #{@summaries.size} notifications"
        mail = create_mail(:subject => subject,
                           :body => report_body)
        send(mail)
    end

    def report_body
      @summaries.join("\n\n")
    end

    def summarize(exception, environment)
      request = Rack::Request.new(environment)
      <<-EOB
Timestamp: #{Time.now.rfc2822}
--
URL: #{request.url}
--
#{exception.class}: #{exception}
EOB
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

    DEFAULT_MAX_MAIL_COUNT_IN_LIMIT_DURATION = 2
    def max_mail_count_in_limit_duration
      @options[:max_mail_count_in_limit_duration] || DEFAULT_MAX_MAIL_COUNT_IN_LIMIT_DURATION
    end

    DEFAULT_LIMIT_DURATION = 60 # one minute
    def limit_duration
      @options[:limit_duration] || DEFAULT_LIMIT_DURATION
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
