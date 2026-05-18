#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path("..", __dir__)
INPUT = ARGV[0] || File.join(ROOT, "resources", "association_generated.tsv")
OUTPUT = ARGV[1] || File.join(ROOT, "resources", "association_generated.index")

MAGIC = "PTAIDX01".b
HEADER_SIZE = 12
RECORD_SIZE = 16
CJK_ONLY = /\A[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]+\z/

def each_grapheme(text)
  text.scan(/\X/)
end

def cjk_only?(text)
  text.match?(CJK_ONLY)
end

def association_continuation_for(key, candidate)
  key_characters = each_grapheme(key)
  candidate_characters = each_grapheme(candidate)
  return "" if key_characters.empty? || candidate_characters.empty?

  max_overlap = [key_characters.length, candidate_characters.length - 1].min
  max_overlap.downto(1) do |overlap|
    key_suffix = key_characters[-overlap, overlap]
    candidate_prefix = candidate_characters[0, overlap]
    next unless key_suffix == candidate_prefix

    return candidate_characters[overlap..].join
  end

  candidate_characters.join
end

def add_association(buckets, key, candidate)
  continuation = association_continuation_for(key, candidate)
  return unless cjk_only?(key) && cjk_only?(continuation)

  bucket = buckets[key]
  bucket << continuation unless bucket.include?(continuation)
end

buckets = Hash.new { |hash, key| hash[key] = [] }

File.foreach(INPUT, encoding: "UTF-8") do |raw_line|
  line = raw_line.strip
  next if line.empty? || line.start_with?("#")

  columns = line.split("\t")
  if columns.length == 1
    characters = each_grapheme(columns.first)
    next if characters.length < 2

    (0...(characters.length - 1)).each do |index|
      add_association(buckets, characters[index], characters[index + 1])
    end
    next
  end

  key = columns.first.to_s
  columns.drop(1).each do |candidate|
    add_association(buckets, key, candidate.to_s)
  end
end

keys = buckets.keys.sort_by { |key| key.encode("UTF-8").bytes }
record_bytes = +""
pool = +""
pool.force_encoding(Encoding::BINARY)
base_offset = HEADER_SIZE + (keys.length * RECORD_SIZE)

keys.each do |key|
  key_bytes = key.encode("UTF-8").b
  value_bytes = buckets[key].join("\t").encode("UTF-8").b
  key_offset = base_offset + pool.bytesize
  pool << key_bytes
  value_offset = base_offset + pool.bytesize
  pool << value_bytes
  record_bytes << [key_offset, key_bytes.bytesize, value_offset, value_bytes.bytesize].pack("NNNN")
end

output_directory = File.dirname(OUTPUT)
Dir.mkdir(output_directory) unless Dir.exist?(output_directory)

tmp_output = "#{OUTPUT}.tmp.#{$PROCESS_ID}"
File.binwrite(tmp_output, [MAGIC, keys.length].pack("a8N") + record_bytes + pool)
File.rename(tmp_output, OUTPUT)

puts "Indexed #{INPUT} -> #{OUTPUT} with #{keys.length} keys"
