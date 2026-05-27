#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'set'

MAGIC = 'PTCIDX01'.b
HEADER_SIZE = 16
RECORD_SIZE = 16

def usage!
  warn 'Usage: index-candidate-tables.rb MODE OUTPUT INPUT...'
  warn '  quick OUTPUT quick-classic.txt'
  warn '  cangjie OUTPUT cangjie5.txt cangjie5.base.dict.yaml cangjie5.extended.dict.yaml'
  warn '  pinyin OUTPUT pinyin_seed.tsv pinyin_phrases.tsv luna_pinyin.dict.yaml quick-classic.txt'
  exit 2
end

def normalized_input(value)
  value.to_s.gsub(/\A[[:space:]\u3000]+|[[:space:]\u3000]+\z/, '').downcase
end

def normalized_pinyin_code(value)
  normalized_input(value)
    .tr('ü', 'v')
    .gsub('u:', 'v')
    .delete(' ')
    .delete("'")
end

def alphabetic_code?(value)
  value.match?(/\A[a-z]+\z/)
end

def utf16_length(value)
  value.encode('UTF-16LE').bytesize / 2
end

def add_candidate(buckets, seen_by_code, code, text, weight, sequence)
  return false if code.empty? || text.empty?

  seen = (seen_by_code[code] ||= Set.new)
  return false if seen.include?(text)

  seen.add(text)
  buckets[code] << { text: text, weight: weight, sequence: sequence }
  true
end

def objc_whitespace_split(value)
  value.split(/[[:space:]\u3000]+/).reject(&:empty?)
end

def parse_ibus_table(path)
  rows = []
  in_table = false
  File.foreach(path, encoding: 'UTF-8') do |raw_line|
    line = raw_line.gsub(/\A[[:space:]\u3000]+|[[:space:]\u3000]+\z/, '')
    next if line.empty? || line.start_with?('###')

    unless in_table
      in_table = true if line == 'BEGIN_TABLE'
      next
    end

    break if line == 'END_TABLE'

    parts = objc_whitespace_split(line)
    next if parts.length < 2

    code = normalized_input(parts[0])
    text = parts[1]
    weight = parts.length >= 3 ? parts[2].to_i : 0
    next if code.empty? || text.empty?

    rows << [code, text, weight]
  end
  rows
end

def parse_rime_cangjie(path)
  rows = []
  in_data = false
  File.foreach(path, encoding: 'UTF-8') do |line|
    line = line.chomp
    unless in_data
      in_data = true if line == '...'
      next
    end

    next if line.empty? || line.start_with?('#')

    columns = line.split("\t")
    next if columns.length < 2

    text = columns[0]
    code = normalized_input(columns[1])
    next if text.empty? || code.empty?

    rows << [code, text, 1000]
  end
  rows
end

def parse_pinyin_tsv(path, base_weight)
  rows = []
  File.foreach(path, encoding: 'UTF-8') do |line|
    line = line.chomp
    next if line.empty? || line.start_with?('#')

    columns = line.split("\t")
    next if columns.length < 2

    code = normalized_pinyin_code(columns[0])
    text = columns[1]
    weight = base_weight + (columns.length >= 3 ? columns[2].to_i : 0)
    next if code.empty? || text.empty? || !alphabetic_code?(code)

    rows << [code, text, weight]
  end
  rows
end

def quick_weight_by_text(path)
  weights = {}
  parse_ibus_table(path).each do |_code, text, weight|
    current = weights[text]
    weights[text] = weight if current.nil? || weight > current
  end
  weights
end

def parse_rime_pinyin(path, quick_weights)
  rows = []
  File.foreach(path, encoding: 'UTF-8') do |line|
    line = line.chomp
    unless defined?(@in_rime_pinyin_data) && @in_rime_pinyin_data
      @in_rime_pinyin_data = true if line == '...'
      next
    end

    next if line.empty? || line.start_with?('#')

    columns = line.split("\t")
    next if columns.length < 2

    text = columns[0]
    code = normalized_pinyin_code(columns[1])
    next if text.empty? || code.empty? || !alphabetic_code?(code)

    raw_weight = columns.length >= 3 ? columns[2].delete('%') : '0'
    weight = 500 + (raw_weight.to_f * 10.0).to_i
    weight += quick_weights[text].to_i * 10 if utf16_length(text) == 1
    rows << [code, text, weight]
  end
  @in_rime_pinyin_data = false
  rows
end

def build_index(rows)
  buckets = Hash.new { |hash, key| hash[key] = [] }
  seen_by_code = {}
  candidate_count = 0
  sequence = 0

  rows.each do |code, text, weight|
    candidate_count += 1
    if add_candidate(buckets, seen_by_code, code, text, weight, sequence)
      sequence += 1
    end
  end

  buckets.each_value do |candidates|
    candidates.sort_by! { |candidate| [-candidate[:weight], candidate[:sequence], candidate[:text]] }
  end

  [buckets, candidate_count]
end

def write_index(path, buckets, candidate_count)
  FileUtils.mkdir_p(File.dirname(path))

  sorted_keys = buckets.keys.sort
  payload = String.new.b
  records = String.new.b
  offset = HEADER_SIZE + (sorted_keys.length * RECORD_SIZE)

  sorted_keys.each do |key|
    key_bytes = key.b
    value = buckets[key].map do |candidate|
      "#{candidate[:text]}\t#{candidate[:weight]}\t#{candidate[:sequence]}"
    end.join("\n").b
    value << "\n" unless value.empty?

    key_offset = offset
    offset += key_bytes.bytesize
    value_offset = offset
    offset += value.bytesize

    records << [key_offset, key_bytes.bytesize, value_offset, value.bytesize].pack('N4')
    payload << key_bytes
    payload << value
  end

  File.binwrite(path, MAGIC + [sorted_keys.length, candidate_count].pack('N2') + records + payload)
end

mode, output_path, *inputs = ARGV
usage! if mode.nil? || output_path.nil?

rows = case mode
       when 'quick'
         usage! unless inputs.length == 1
         parse_ibus_table(inputs[0])
       when 'cangjie'
         usage! unless inputs.length == 3
         parse_ibus_table(inputs[0]) +
           parse_rime_cangjie(inputs[1]) +
           parse_rime_cangjie(inputs[2])
       when 'pinyin'
         usage! unless inputs.length == 4
         parse_pinyin_tsv(inputs[0], 10_000) +
           parse_pinyin_tsv(inputs[1], 30_000) +
           parse_rime_pinyin(inputs[2], quick_weight_by_text(inputs[3]))
       else
         usage!
       end

buckets, candidate_count = build_index(rows)
write_index(output_path, buckets, candidate_count)
puts "Indexed #{candidate_count} #{mode} candidates into #{output_path}"
