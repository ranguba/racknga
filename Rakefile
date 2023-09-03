# -*- coding: utf-8; mode: ruby -*-
#
# Copyright (C) 2010-2011  Kouhei Sutou <kou@clear-code.com>
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require 'English'

require 'fileutils'
require 'pathname'
require 'erb'
require 'rubygems'
require 'rubygems/package_task'
require 'bundler/gem_helper'
require "packnga"

base_dir = Pathname.new(__FILE__).dirname
racknga_lib_dir = base_dir + 'lib'
$LOAD_PATH.unshift(racknga_lib_dir.to_s)

helper = Bundler::GemHelper.new(base_dir)
def helper.version_tag
  version
end
helper.install
spec = helper.gemspec

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_tar_gz = true
end

Packnga::DocumentTask.new(spec) do |task|
  task.original_language = "en"
  task.translate_languages = ["ja"]
end

Packnga::ReleaseTask.new(spec) do
end

desc "Run test"
task :test do
  ruby("-rubygems", "test/run-test.rb")
end

task :default => :test
