#!/usr/bin/env ruby
# frozen_string_literal: true

require "set"

ROOT = File.expand_path("..", __dir__)
TABLE_PATH = File.join(ROOT, "third_party/ibus-table-chinese/quick-classic.txt")
OVERRIDES_PATH = File.join(ROOT, "resources/sucheng_order_guards.tsv")
PAGE_SIZE = 9
DEFAULT_PAGE_COUNT = 3
DEFAULT_CODES = %w[竹戈 人口 口口 卜口 木戈 竹人 人火].freeze

RADICAL_TO_CODE = {
  "日" => "a",
  "月" => "b",
  "金" => "c",
  "木" => "d",
  "水" => "e",
  "火" => "f",
  "土" => "g",
  "竹" => "h",
  "戈" => "i",
  "十" => "j",
  "大" => "k",
  "中" => "l",
  "一" => "m",
  "弓" => "n",
  "人" => "o",
  "心" => "p",
  "手" => "q",
  "口" => "r",
  "尸" => "s",
  "廿" => "t",
  "山" => "u",
  "女" => "v",
  "田" => "w",
  "難" => "x",
  "卜" => "y"
}.freeze

CODE_TO_RADICAL = RADICAL_TO_CODE.invert.freeze

def load_ibus_table(path)
  table = Hash.new { |hash, key| hash[key] = [] }
  seen = Hash.new { |hash, key| hash[key] = Set.new }
  in_table = false

  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.strip
    next if line.empty? || line.start_with?("###")

    unless in_table
      in_table = true if line == "BEGIN_TABLE"
      next
    end
    break if line == "END_TABLE"

    code, text = line.split(/\s+/, 3)
    next if code.nil? || text.nil?

    code = code.downcase
    next unless code.match?(/\A[a-z]{1,2}\z/)
    next if seen[code].include?(text)

    seen[code] << text
    table[code] << text
  end

  table
end

def apply_overrides(table, path)
  current = table.transform_values(&:dup)
  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.chomp
    next if line.empty? || line.start_with?("#")

    source, code, *ordered_texts = line.split("\t")
    next unless source == "quick" && code && !ordered_texts.empty?

    candidates = current[code]
    next if candidates.nil? || candidates.empty?

    added = Set.new
    reordered = []
    ordered_texts.each do |text|
      next if text.empty? || added.include?(text) || !candidates.include?(text)

      reordered << text
      added << text
    end
    next if reordered.empty?

    candidates.each do |text|
      reordered << text unless added.include?(text)
    end
    current[code] = reordered
  end
  current
end

def normalize_code(raw)
  value = raw.to_s.strip
  return nil if value.empty?
  return value.downcase if value.match?(/\A[a-z]{1,2}\z/)

  letters = value.each_char.map { |char| RADICAL_TO_CODE[char] }
  return nil if letters.empty? || letters.any?(&:nil?)

  code = letters.join
  code.length.between?(1, 2) ? code : nil
end

def radical_label(code)
  code.each_char.map { |char| CODE_TO_RADICAL[char] || char }.join
end

def parse_args(argv)
  page_count = DEFAULT_PAGE_COUNT
  codes = []

  index = 0
  while index < argv.length
    arg = argv[index]
    case arg
    when "--all"
      page_count = nil
    when "--pages"
      index += 1
      value = argv[index].to_s
      abort "FAIL: --pages expects a positive integer" unless value.match?(/\A[1-9]\d*\z/)

      page_count = value.to_i
    when "-h", "--help"
      puts "Usage: ruby scripts/dump-sucheng-pages.rb [--pages N|--all] [code_or_radicals ...]"
      puts "Example: ruby scripts/dump-sucheng-pages.rb --pages 3 竹戈 人口 rr"
      exit 0
    else
      codes << arg
    end
    index += 1
  end

  [page_count, codes.empty? ? DEFAULT_CODES : codes]
end

page_count, raw_codes = parse_args(ARGV)
table = apply_overrides(load_ibus_table(TABLE_PATH), OVERRIDES_PATH)

raw_codes.each do |raw_code|
  code = normalize_code(raw_code)
  if code.nil?
    warn "WARN: skipped unrecognized code #{raw_code.inspect}"
    next
  end

  candidates = table[code] || []
  puts "# #{radical_label(code)} / #{code}"
  if candidates.empty?
    puts "(no candidates)"
    puts
    next
  end

  page_total = (candidates.length.to_f / PAGE_SIZE).ceil
  pages_to_print = page_count ? [page_count, page_total].min : page_total
  candidates.each_slice(PAGE_SIZE).first(pages_to_print).each_with_index do |page, page_index|
    labelled = page.each_with_index.map { |text, slot| "#{slot + 1} #{text}" }
    puts "P#{page_index + 1}: #{labelled.join('  ')}"
  end
  puts "... #{page_total - pages_to_print} more page(s)" if pages_to_print < page_total
  puts
end
