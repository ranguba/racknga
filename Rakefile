# -*- coding: utf-8; mode: ruby -*-
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

require 'English'

require 'find'
require 'fileutils'
require 'pathname'
require 'erb'
require 'rubygems'
require 'jeweler'
require "rake/clean"
require "yard"

base_dir = Pathname.new(__FILE__).dirname
racknga_lib_dir = base_dir + 'lib'
$LOAD_PATH.unshift(racknga_lib_dir.to_s)

def guess_version
  require 'racknga/version'
  Racknga::VERSION
end

ENV["VERSION"] ||= guess_version
version = ENV["VERSION"].dup
project = nil
spec = nil
Jeweler::Tasks.new do |_spec|
  spec = _spec
  spec.name = 'racknga'
  spec.version = version
  spec.rubyforge_project = 'groonga'
  spec.homepage = "http://groonga.rubyforge.org/"
  authors_file = File.join(base_dir, "AUTHORS")
  authors = []
  emails = []
  File.readlines(authors_file).each do |line|
    if /\s*<([^<>]*)>$/ =~ line
      authors << $PREMATCH
      emails << $1
    end
  end
  spec.authors = authors
  spec.email = emails
  spec.summary = "A Rack middleware collection for rroonga features."
  spec.description = <<-EOD.gsub(/\n/, ' ').strip
Racknga is a Rack middlewares that uses rroonga features.
EOD
  spec.license = "LGPLv2.1 or later"
  spec.files = FileList["lib/**/*.rb",
                        "{license,munin}/**/*",
                        "example/*.rb",
                        "AUTHORS",
                        "Rakefile",
                        "Gemfile",
                        "NEWS*",
                        "README*"]
  spec.test_files = FileList["test/**/*.rb"]
end

Rake::Task["release"].prerequisites.clear
Jeweler::RubygemsDotOrgTasks.new do
end

reference_base_dir = Pathname.new("doc/html")
doc_en_dir = reference_base_dir + "en"
YARD::Rake::YardocTask.new do |task|
  task.options += ["--title", "#{spec.name} - #{version}"]
  task.options += ["--readme", "README.rdoc"]
  task.options += ["--files", "doc/text/**/*"]
  task.options += ["--output-dir", doc_en_dir.to_s]
  task.options += ["--charset", "utf-8"]
end

task :yard do
  doc_en_dir.find do |path|
    next if path.extname != ".html"
    html = path.read
    html = html.gsub(/<div id="footer">.+<\/div>/m,
                     "<div id=\"footer\"></div>")
    path.open("w") do |html_file|
      html_file.print(html)
    end
  end
end

def rsync_to_rubyforge(spec, source, destination, options={})
  config = YAML.load(File.read(File.expand_path("~/.rubyforge/user-config.yml")))
  host = "#{config["username"]}@rubyforge.org"

  rsync_args = "-av --exclude '*.erb' --chmod=ug+w"
  rsync_args << " --delete" if options[:delete]
  remote_dir = "/var/www/gforge-projects/#{spec.rubyforge_project}/"
  sh("rsync #{rsync_args} #{source} #{host}:#{remote_dir}#{destination}")
end

def rake(*arguments)
  ruby($0, *arguments)
end

namespace :reference do
  translate_languages = [:ja]
  supported_languages = [:en, *translate_languages]
  html_files = FileList["doc/html/en/**/*.html"].to_a

  directory reference_base_dir.to_s
  CLOBBER.include(reference_base_dir.to_s)

  po_dir = "doc/po"
  namespace :pot do
    pot_file = "#{po_dir}/#{spec.name}.pot"

    directory po_dir
    file pot_file => ["po", *html_files] do |t|
      sh("xml2po", "--keep-entities", "--output", t.name, *html_files)
    end

    desc "Generates pot file."
    task :generate => pot_file
  end

  namespace :po do
    translate_languages.each do |language|
      namespace language do
        po_file = "#{po_dir}/#{language}.po"

        file po_file => html_files do |t|
          sh("xml2po", "--keep-entities", "--update", t.name, *html_files)
        end

        desc "Updates po file for #{language}."
        task :update => po_file
      end
    end

    desc "Updates po files."
    task :update do
      ruby($0, "clobber")
      ruby($0, "yard")
      translate_languages.each do |language|
        ruby($0, "reference:po:#{language}:update")
      end
    end
  end

  namespace :translate do
    translate_languages.each do |language|
      po_file = "#{po_dir}/#{language}.po"
      translate_doc_dir = "#{reference_base_dir}/#{language}"

      desc "Translates documents to #{language}."
      task language => [po_file, reference_base_dir, *html_files] do
        doc_en_dir.find do |path|
          base_path = path.relative_path_from(doc_en_dir)
          translated_path = "#{translate_doc_dir}/#{base_path}"
          if path.directory?
            mkdir_p(translated_path)
            next
          end
          case path.extname
          when ".html"
            sh("xml2po --keep-entities " +
               "--po-file #{po_file} --language #{language} " +
               "#{path} > #{translated_path}")
          else
            cp(path.to_s, translated_path, :preserve => true)
          end
        end
      end
    end
  end

  translate_task_names = translate_languages.collect do |language|
    "reference:translate:#{language}"
  end
  desc "Translates references."
  task :translate => translate_task_names

  desc "Generates references."
  task :generate => [:yard, :translate]

  namespace :publication do
    task :prepare do
      supported_languages.each do |language|
        doc_dir = Pathname.new("#{reference_base_dir}/#{language}")
        head = erb_template("head.#{language}")
        header = erb_template("header.#{language}")
        footer = erb_template("footer.#{language}")
        doc_dir.find do |file|
          case file.basename.to_s
          when "_index.html", /\A(?:class|method|file)_list.html\z/
            next
          when /\.html\z/
            relative_dir_path = file.relative_path_from(doc_dir).dirname
            current_page = relative_dir_path + file.basename
            top_path = doc_dir.relative_path_from(file.dirname).to_s
            apply_template(file, top_path, current_page,
                           head, header, footer, language)
          end
        end
      end
      File.open("#{reference_base_dir}/.htaccess", "w") do |file|
        file.puts("RedirectMatch permanent ^/#{spec.name}/$ " +
                  "#{spec.homepage}#{spec.name}/en/")
      end
    end
  end

  desc "Upload document to rubyforge."
  task :publish => [:generate, "reference:publication:prepare"] do
    rsync_to_rubyforge(spec, "#{reference_base_dir}/", spec.name,
                       :delete => true)
  end
end

namespace :html do
  desc "Publish HTML to Web site."
  task :publish do
    rsync_to_rubyforge(spec, "html/", "")
  end
end

desc "Upload document and HTML to rubyforge."
task :publish => ["reference:publish", "html:publish"]

desc "Tag the current revision."
task :tag do
  sh("git tag -a #{version} -m 'release #{version}!!!'")
end
