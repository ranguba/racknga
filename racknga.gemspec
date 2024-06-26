# -*- ruby -*-
#
# Copyright (C) 2023-2024  Sutou Kouhei <kou@clear-code.com>
# Copyright (C) 2013  Haruka Yoshihara <yoshihara@clear-code.com>
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

require "English"

base_dir = File.dirname(__FILE__)
$LOAD_PATH.unshift(File.expand_path("lib", base_dir))
require "racknga/version"
version = Racknga::VERSION.dup

authors_path = File.join(base_dir, "AUTHORS")
authors = []
emails = []
File.readlines(authors_path).each do |line|
  if /\s*<([^<>]*)>$/ =~ line
    authors << $PREMATCH
    emails << $1
  end
end

summary = "A Rack middleware collection for Rroonga features."
description = "Racknga is a Rack middlewares that uses Rroonga features."

Gem::Specification.new do |spec|
  spec.name = "racknga"
  spec.version = version
  spec.authors = authors
  spec.email = emails
  spec.summary = summary
  spec.description = description

  spec.homepage = "http://ranguba.org/"
  spec.licenses = ["LGPLv2.1 or later"]
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = ["README.md"]
  spec.files = ["AUTHORS", "README.md", "Rakefile", "Gemfile"]
  spec.files += Dir.glob("lib/**/*.rb")
  spec.files += Dir.glob("{license,munin,doc/text/}/**/*")
  spec.files += Dir.glob("example/*.rb")
  spec.test_files = Dir.glob("test/**/*.rb")

  spec.add_runtime_dependency("base64")
  spec.add_runtime_dependency("csv")
  spec.add_runtime_dependency("net-smtp")
  spec.add_runtime_dependency("rack")

  spec.add_development_dependency("bundler")
  spec.add_development_dependency("kramdown")
  spec.add_development_dependency("packnga")
  spec.add_development_dependency("rake")
  spec.add_development_dependency("rroonga")
  spec.add_development_dependency("test-unit")
  spec.add_development_dependency("test-unit-capybara")
end

