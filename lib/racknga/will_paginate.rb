# -*- coding: utf-8 -*-
#
# Copyright (C) 2010  SHIMODA Hiroshi <shimoda@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require "groonga/pagination"

module Groonga
  module Pagination
    alias :total_pages :n_pages
    alias :per_page :n_records_in_page
    alias :total_entries :n_records
    alias :out_of_bounds? :have_pages?
    def offset
      start_offset || 0
    end
  end
end
