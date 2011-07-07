#!/usr/bin/env ruby
#
# Copyright (C) 2010-2011  Kouhei Sutou <kou@clear-code.com>
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

$VERBOSE = true

$KCODE = "u" if RUBY_VERSION < "1.9"

require 'pathname'

base_dir = Pathname(__FILE__).dirname.parent.expand_path
rroonga_dir = base_dir.parent + "rroonga"
rroonga_ext_dir = rroonga_dir + "ext" + "groonga"
rroonga_lib_dir = rroonga_dir + "lib"
lib_dir = base_dir + "lib"
test_dir = base_dir + "test"

gem 'test-unit'
require 'test/unit'
require 'test/unit/notify'

Test::Unit::Priority.enable

$LOAD_PATH.unshift(rroonga_ext_dir.to_s)
$LOAD_PATH.unshift(rroonga_lib_dir.to_s)
$LOAD_PATH.unshift(lib_dir.to_s)

$LOAD_PATH.unshift(test_dir.to_s)
require 'racknga-test-utils'

Dir.glob("#{test_dir}/**/test{_,-}*.rb") do |file|
  require file.sub(/\.rb$/, '')
end

exit Test::Unit::AutoRunner.run(false)
