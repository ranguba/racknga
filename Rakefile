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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'English'

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
                        "{license,munin,doc/text/}/**/*",
                        "example/*.rb",
                        "AUTHORS",
                        "Rakefile",
                        "Gemfile",
                        "README*"]
  spec.test_files = FileList["test/**/*.rb"]
end

Rake::Task["release"].prerequisites.clear
Jeweler::RubygemsDotOrgTasks.new do
end

reference_base_dir = Pathname.new("doc/reference")
doc_en_dir = reference_base_dir + "en"
html_base_dir = Pathname.new("doc/html")
html_reference_dir = html_base_dir + spec.name
YARD::Rake::YardocTask.new do |task|
  task.options += ["--title", spec.name]
  task.options += ["--readme", "README.textile"]
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

include ERB::Util

def apply_template(content, paths, templates, language)
  content = content.sub(/lang="en"/, "lang=\"#{language}\"")

  title = nil
  content = content.sub(/<title>(.+?)<\/title>/m) do
    title = $1
    templates[:head].result(binding)
  end

  content = content.sub(/<body(?:.*?)>/) do |body_start|
    "#{body_start}\n#{templates[:header].result(binding)}\n"
  end

  content = content.sub(/<\/body/) do |body_end|
    "\n#{templates[:footer].result(binding)}\n#{body_end}"
  end

  content
end

def erb_template(name)
  file = File.join("doc/templates", "#{name}.html.erb")
  template = File.read(file)
  erb = ERB.new(template, nil, "-")
  erb.filename = file
  erb
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
  html_files = FileList[(doc_en_dir + "**/*.html").to_s].to_a

  directory reference_base_dir.to_s
  CLOBBER.include(reference_base_dir.to_s)

  po_dir = "doc/po"
  pot_file = "#{po_dir}/#{spec.name}.pot"
  namespace :pot do
    directory po_dir
    file pot_file => [po_dir, *html_files] do |t|
      sh("xml2po", "--keep-entities", "--output", t.name, *html_files)
    end

    desc "Generates pot file."
    task :generate => pot_file
  end

  namespace :po do
    translate_languages.each do |language|
      namespace language do
        po_file = "#{po_dir}/#{language}.po"

        if File.exist?(po_file)
          file po_file => html_files do |t|
            sh("xml2po", "--keep-entities", "--update", t.name, *html_files)
          end
        else
          file po_file => pot_file do |t|
            sh("msginit",
               "--input=#{pot_file}",
               "--output=#{t.name}",
               "--locale=#{language}")
          end
        end

        desc "Updates po file for #{language}."
        task :update => po_file
      end
    end

    desc "Updates po files."
    task :update do
      rake("clobber")
      rake("yard")
      translate_languages.each do |language|
        rake("reference:po:#{language}:update")
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
        raw_reference_dir = reference_base_dir + language.to_s
        prepared_reference_dir = html_reference_dir + language.to_s
        rm_rf(prepared_reference_dir.to_s)
        head = erb_template("head.#{language}")
        header = erb_template("header.#{language}")
        footer = erb_template("footer.#{language}")
        raw_reference_dir.find do |path|
          relative_path = path.relative_path_from(raw_reference_dir)
          prepared_path = prepared_reference_dir + relative_path
          if path.directory?
            mkdir_p(prepared_path.to_s)
          else
            case path.basename.to_s
            when /(?:file|method|class)_list\.html\z/
              cp(path.to_s, prepared_path.to_s)
            when /\.html\z/
              relative_dir_path = relative_path.dirname
              current_path = relative_dir_path + path.basename
              if current_path.basename.to_s == "index.html"
                current_path = current_path.dirname
              end
              top_path = html_base_dir.relative_path_from(prepared_path.dirname)
              package_path = top_path + spec.name
              paths = {
                :top => top_path,
                :current => current_path,
                :package => package_path,
              }
              templates = {
                :head => head,
                :header => header,
                :footer => footer
              }
              content = apply_template(File.read(path.to_s),
                                       paths,
                                       templates,
                                       language)
              File.open(prepared_path.to_s, "w") do |file|
                file.print(content)
              end
            else
              cp(path.to_s, prepared_path.to_s)
            end
          end
        end
      end
      File.open("#{html_reference_dir}/.htaccess", "w") do |file|
        file.puts("RedirectMatch permanent ^/#{spec.name}/$ " +
                  "#{spec.homepage}#{spec.name}/en/")
      end
    end
  end

  desc "Upload document to rubyforge."
  task :publish => [:generate, "reference:publication:prepare"] do
    rsync_to_rubyforge(spec, "#{html_reference_dir}/", spec.name)
  end
end

namespace :html do
  desc "Publish HTML to Web site."
  task :publish do
    rsync_to_rubyforge(spec, "#{html_base_dir}/", "")
  end
end

desc "Upload document to rubyforge."
task :publish => ["reference:publish"]

desc "Tag the current revision."
task :tag do
  sh("git tag -a #{version} -m 'release #{version}!!!'")
end
