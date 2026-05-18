#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "time"

def capture(*command)
  output, status = Open3.capture2(*command)
  status.success? ? output.strip : ""
end

version = ARGV.shift
output_path = ARGV.shift
artifact_paths = ARGV

if version.to_s.empty? || output_path.to_s.empty? || artifact_paths.empty?
  warn "Usage: scripts/write-release-provenance.rb <version> <output.json> <artifact>..."
  exit 1
end

missing_artifacts = artifact_paths.reject { |path| File.file?(path) }
unless missing_artifacts.empty?
  warn "Missing release artifacts: #{missing_artifacts.join(", ")}"
  exit 1
end

artifacts = artifact_paths.map do |path|
  {
    "path" => path,
    "bytes" => File.size(path),
    "sha256" => Digest::SHA256.file(path).hexdigest
  }
end

provenance = {
  "name" => "PurrType",
  "version" => version,
  "generatedAtUtc" => Time.now.utc.iso8601,
  "git" => {
    "commit" => capture("git", "rev-parse", "HEAD"),
    "branch" => capture("git", "branch", "--show-current"),
    "dirty" => !capture("git", "status", "--short").empty?
  },
  "toolchain" => {
    "macOS" => capture("sw_vers", "-productVersion"),
    "sdkPath" => capture("xcrun", "--sdk", "macosx", "--show-sdk-path"),
    "sdkVersion" => capture("xcrun", "--sdk", "macosx", "--show-sdk-version"),
    "clang" => capture("clang", "--version").lines.first.to_s.strip,
    "make" => capture("make", "--version").lines.first.to_s.strip
  },
  "artifacts" => artifacts
}

File.write(output_path, "#{JSON.pretty_generate(provenance)}\n")
