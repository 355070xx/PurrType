#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rexml/document'

ROOT = File.expand_path('..', __dir__)

def read_repo(path)
  File.read(File.join(ROOT, path))
end

makefile = read_repo('Makefile')
version = makefile[/^VERSION\s*:=\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$/, 1]
abort('Could not read VERSION from Makefile') unless version

major, minor, patch = version.split('.').map(&:to_i)
bundle_version = ((major * 10_000) + (minor * 100) + patch).to_s
errors = []

def plist_value(path, key)
  document = REXML::Document.new(read_repo(path))
  elements = document.elements.to_a('/plist/dict/*')
  elements.each_with_index do |element, index|
    next unless element.name == 'key' && element.text == key

    return elements.fetch(index + 1).text
  end
  nil
end

[
  'resources/Info.plist',
  'resources/PurrTypePreferencesInfo.plist'
].each do |plist|
  short_version = plist_value(plist, 'CFBundleShortVersionString')
  build_version = plist_value(plist, 'CFBundleVersion')

  errors << "#{plist}: CFBundleShortVersionString is #{short_version.inspect}, expected #{version.inspect}" unless short_version == version
  errors << "#{plist}: CFBundleVersion is #{build_version.inspect}, expected #{bundle_version.inspect}" unless build_version == bundle_version
end

release_text_paths = [
  'README.md',
  'docs/BUILD_AND_INSTALL.md',
  'docs/MANUAL_QA.md',
  'docs/TROUBLESHOOTING.md',
  'packaging/README.txt'
]

release_text_paths.each do |path|
  read_repo(path).scan(/PurrType(?:Dev)?-([0-9]+\.[0-9]+\.[0-9]+)/).flatten.uniq.each do |found_version|
    next if found_version == version

    errors << "#{path}: references PurrType/PurrType artifact #{found_version}, expected #{version}"
  end
end

unless read_repo('docs/CHANGELOG.md').match?(/^## #{Regexp.escape(version)}\s*$/)
  errors << "docs/CHANGELOG.md: missing ## #{version} entry"
end

if errors.any?
  warn errors.join("\n")
  exit 1
end

puts "PASS: version consistency #{version}"
