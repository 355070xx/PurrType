#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "set"

ROOT = File.expand_path("..", __dir__)
HKSCS_PATH = File.join(ROOT, "third_party/hkscs/HKSCS2016.json")
QUICK_PATH = File.join(ROOT, "third_party/ibus-table-chinese/quick-classic.txt")
CANGJIE_PATH = File.join(ROOT, "third_party/ibus-table-chinese/cangjie5.txt")
RIME_PATHS = [
  File.join(ROOT, "third_party/rime-cangjie/cangjie5.base.dict.yaml"),
  File.join(ROOT, "third_party/rime-cangjie/cangjie5.extended.dict.yaml")
].freeze

RADICAL_CODES = {
  "日" => "a", "月" => "b", "金" => "c", "木" => "d", "水" => "e",
  "火" => "f", "土" => "g", "竹" => "h", "戈" => "i", "十" => "j",
  "大" => "k", "中" => "l", "一" => "m", "弓" => "n", "人" => "o",
  "心" => "p", "手" => "q", "口" => "r", "尸" => "s", "廿" => "t",
  "山" => "u", "女" => "v", "田" => "w", "難" => "x", "卜" => "y",
  "重" => "z"
}.freeze

def han?(text)
  text.each_codepoint.any? do |codepoint|
    (0x3400..0x4DBF).cover?(codepoint) ||
      (0x4E00..0x9FFF).cover?(codepoint) ||
      (0xF900..0xFAFF).cover?(codepoint) ||
      (0x20000..0x3FFFD).cover?(codepoint)
  end
end

def normalized_cangjie_code(raw)
  code = raw.strip.each_char.map do |char|
    if char.match?(/[A-Za-z]/)
      char.downcase
    else
      RADICAL_CODES[char]
    end
  end
  return nil if code.any?(&:nil?)

  normalized = code.join
  return nil unless normalized.match?(/\A[a-z]{1,5}\z/)

  normalized
end

def normalized_cangjie_codes(raw)
  codes = []
  raw.split(",").each do |code|
    normalized = normalized_cangjie_code(code)
    codes << normalized if normalized
  end
  codes.uniq
end

def quick_code(cangjie_code)
  return cangjie_code if cangjie_code.length <= 1

  "#{cangjie_code[0]}#{cangjie_code[-1]}"
end

def load_ibus_texts(path)
  texts = Set.new
  in_table = false
  File.foreach(path, encoding: "UTF-8") do |line|
    line = line.chomp
    if line == "BEGIN_TABLE"
      in_table = true
      next
    end
    if line == "END_TABLE"
      in_table = false
      next
    end
    next unless in_table
    next if line.empty? || line.start_with?("#")

    _code, text = line.split(/\t/, 3)
    texts << text if text && !text.empty?
  end
  texts
end

def load_rime_texts(paths)
  texts = Set.new
  paths.each do |path|
    in_data = false
    File.foreach(path, encoding: "UTF-8") do |line|
      line = line.chomp
      if line == "..."
        in_data = true
        next
      end
      next unless in_data
      next if line.empty? || line.start_with?("#")

      text, code = line.split(/\t/)
      texts << text if text && code
    end
  end
  texts
end

hkscs = JSON.parse(File.binread(HKSCS_PATH).force_encoding("UTF-8").sub(/\A\uFEFF/, ""))
quick_texts = load_ibus_texts(QUICK_PATH)
cangjie_texts = load_ibus_texts(CANGJIE_PATH).merge(load_rime_texts(RIME_PATHS))

valid_rows = []
hkscs.each do |row|
  text = row["char"].to_s
  codes = normalized_cangjie_codes(row["cangjie"].to_s)
  next if text.empty? || codes.empty? || !han?(text)

  valid_rows << { "text" => text, "codes" => codes }
end

missing_quick_before_overlay = valid_rows.reject { |row| quick_texts.include?(row["text"]) }
missing_cangjie_before_overlay = valid_rows.reject { |row| cangjie_texts.include?(row["text"]) }

puts "HKSCS Han rows with usable Cangjie codes: #{valid_rows.length}"
puts "Missing from bundled Sucheng before overlay: #{missing_quick_before_overlay.length}"
puts "Missing from bundled Cangjie before overlay: #{missing_cangjie_before_overlay.length}"
puts "Runtime overlay covers missing rows by deriving Cangjie and Sucheng codes from HKSCS2016.json."

if valid_rows.empty?
  warn "No usable HKSCS rows parsed"
  exit 1
end
