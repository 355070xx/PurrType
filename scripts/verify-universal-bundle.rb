#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'json'
require 'open3'
require 'rubygems'

module PurrTypeBundleAudit
  module_function

  def capture!(*command)
    output, error, status = Open3.capture3(*command)
    raise "#{command.first} failed: #{error.strip}" unless status.success?
    output.strip
  end

  def plist_value(plist, key)
    capture!('/usr/libexec/PlistBuddy', '-c', "Print :#{key}", plist)
  end

  def inspect_bundle(bundle, minimum, version, build_version)
    bundle = File.expand_path(bundle)
    descriptions = [
      [bundle, 'PurrType', 'org.purrtype.inputmethod.PurrTypeUnified'],
      [File.join(bundle, 'Contents/Resources/PurrTypePreferences.app'),
       'PurrTypePreferences', 'org.purrtype.inputmethod.PurrTypeUnified.Preferences']
    ]
    binaries = descriptions.map do |app, executable, identifier|
      plist = File.join(app, 'Contents/Info.plist')
      { 'CFBundleIdentifier' => identifier, 'CFBundleExecutable' => executable,
        'CFBundleShortVersionString' => version, 'CFBundleVersion' => build_version,
        'LSMinimumSystemVersion' => minimum }.each do |key, expected|
        actual = plist_value(plist, key)
        raise "#{app}: #{key}=#{actual.inspect}, expected #{expected.inspect}" unless actual == expected
      end
      binary = File.join(app, 'Contents/MacOS', executable)
      architectures = capture!('lipo', '-archs', binary).split.sort
      raise "#{binary}: expected arm64 and x86_64, got #{architectures.join(' ')}" unless architectures == %w[arm64 x86_64]

      slices = architectures.map do |arch|
        commands = capture!('otool', '-arch', arch, '-l', binary)
        deployment = commands[/cmd LC_BUILD_VERSION\b.*?\bminos\s+(\S+)/m, 1] ||
                     commands[/cmd LC_VERSION_MIN_MACOSX\b.*?\bversion\s+(\S+)/m, 1]
        unless deployment && Gem::Version.new(deployment) == Gem::Version.new(minimum)
          raise "#{binary} (#{arch}): minimum macOS #{deployment.inspect}, expected #{minimum}"
        end
        dependencies = capture!('otool', '-arch', arch, '-L', binary).lines.drop(1).map { |line| line.strip.split(' (').first }
        external = dependencies.reject { |path| path.start_with?('/System/Library/', '/usr/lib/') }
        raise "#{binary} (#{arch}): unexpected dependency #{external.join(', ')}" unless external.empty?
        { 'architecture' => arch, 'minimumMacOS' => deployment, 'dependencies' => dependencies }
      end
      capture!('codesign', '--verify', '--strict', '--all-architectures', app)
      { 'path' => binary.delete_prefix("#{bundle}/"), 'sha256' => Digest::SHA256.file(binary).hexdigest,
        'architectures' => architectures, 'slices' => slices }
    end
    { 'minimumMacOS' => minimum, 'version' => version, 'bundleVersion' => build_version, 'binaries' => binaries }
  end
end

if $PROGRAM_NAME == __FILE__
  abort('Usage: verify-universal-bundle.rb APP MIN_MACOS VERSION BUNDLE_VERSION') unless ARGV.length == 4
  begin
    report = PurrTypeBundleAudit.inspect_bundle(*ARGV)
    report.fetch('binaries').each do |binary|
      puts "PASS: #{binary.fetch('path')}: arm64 x86_64; macOS #{report.fetch('minimumMacOS')}; signatures valid"
    end
  rescue StandardError => error
    abort("FAIL: universal bundle: #{error.message}")
  end
end
