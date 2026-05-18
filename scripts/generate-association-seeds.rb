#!/usr/bin/env ruby
# frozen_string_literal: true

require "set"

ROOT = File.expand_path("..", __dir__)
OUTPUT = File.join(ROOT, "resources", "association_generated.tsv")
MAX_CANDIDATES_PER_KEY = 120
MAX_SUFFIX_LENGTH = 3

SOURCES = [
  ["resources/association_phrases.tsv", 80, :tsv_phrase],
  ["resources/smart_phrases.tsv", 60, :smart_phrase],
  ["third_party/mcbopomofo/associated-phrases-v2.txt", 20, :mcbopomofo_association],
  ["docs/typing/one_hour_typing_corpus.md", 8, :text],
  ["docs/typing/full_bible_typing_corpus.md", 1, :text],
  ["third_party/rime-cangjie/cangjie5.base.dict.yaml", 6, :dictionary],
  ["third_party/rime-cangjie/cangjie5.extended.dict.yaml", 4, :dictionary],
  ["third_party/ibus-table-chinese/cangjie5.txt", 4, :ibus_dictionary]
].freeze

CJK_RUN = /[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]{2,}/
CJK_ONLY = /\A[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]+\z/

def each_grapheme(text)
  text.scan(/\X/)
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

def add_phrase(scores, phrase, source_weight)
  characters = each_grapheme(phrase)
  return if characters.length < 2

  (0...(characters.length - 1)).each do |index|
    key = characters[index]
    next unless key.match?(CJK_ONLY)

    max_suffix = [MAX_SUFFIX_LENGTH, characters.length - index - 1].min
    (1..max_suffix).each do |suffix_length|
      suffix = characters[(index + 1), suffix_length].join
      next unless suffix.match?(CJK_ONLY)

      suffix_weight = case suffix_length
                      when 1 then 12
                      when 2 then 4
                      else 1
                      end
      scores[key][suffix] += source_weight * suffix_weight
    end
  end
end

def add_phrase_prefix_associations(scores, phrase, source_weight)
  characters = each_grapheme(phrase)
  return if characters.length < 3

  max_key_length = [MAX_SUFFIX_LENGTH, characters.length - 1].min
  (2..max_key_length).each do |key_length|
    key = characters[0, key_length].join
    next unless key.match?(CJK_ONLY)

    max_suffix = [MAX_SUFFIX_LENGTH, characters.length - key_length].min
    (1..max_suffix).each do |suffix_length|
      suffix = characters[key_length, suffix_length].join
      next unless suffix.match?(CJK_ONLY)

      suffix_weight = case suffix_length
                      when 1 then 12
                      when 2 then 4
                      else 1
                      end
      scores[key][suffix] += source_weight * suffix_weight
    end
  end
end

def add_text_runs(scores, text, source_weight)
  text.scan(CJK_RUN) do |run|
    add_phrase(scores, run, source_weight)
  end
end

def load_tsv_phrase_source(scores, path, source_weight)
  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.strip
    next if line.empty? || line.start_with?("#")

    columns = line.split("\t")
    if columns.length == 1
      add_text_runs(scores, columns.first, source_weight)
    else
      key = columns.first
      columns.drop(1).each do |candidate|
        continuation = association_continuation_for(key, candidate)
        next unless key.match?(CJK_ONLY) && continuation.match?(CJK_ONLY)

        scores[key][continuation] += source_weight * 16
      end
    end
  end
end

def load_smart_phrase_source(scores, path, source_weight)
  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.strip
    next if line.empty? || line.start_with?("#")

    columns = line.split("\t")
    add_text_runs(scores, columns[1].to_s, source_weight) if columns.length >= 2
  end
end

def load_dictionary_source(scores, path, source_weight)
  in_data = false
  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.strip
    if line == "..." || line == "%chardef begin"
      in_data = true
      next
    end
    break if line == "%chardef end"
    next unless in_data
    next if line.empty? || line.start_with?("#")

    text = line.split(/\s+/, 2).first.to_s
    add_text_runs(scores, text, source_weight)
  end
end

def load_mcbopomofo_association_source(scores, path, source_weight)
  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.strip
    next if line.empty? || line.start_with?("#") || line.include?("_punctuation")

    phrase_parts, _separator, raw_score = line.rpartition(" ")
    next if phrase_parts.empty? || raw_score.empty?

    tokens = phrase_parts.split("-")
    next if tokens.length < 4 || tokens.length.odd?

    phrase = tokens.each_slice(2).map(&:first).join
    next unless phrase.match?(CJK_ONLY)

    score = raw_score.to_f
    # Scores are negative log frequencies. Less negative rows are more common.
    weighted_source = source_weight + [[((score + 8.0) * 4.0).round, 0].max, 24].min
    add_phrase(scores, phrase, weighted_source)
    add_phrase_prefix_associations(scores, phrase, weighted_source)
  end
end

def load_ibus_dictionary_source(scores, path, source_weight)
  in_table = false
  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.strip
    unless in_table
      in_table = true if line == "BEGIN_TABLE"
      next
    end
    break if line == "END_TABLE"
    next if line.empty? || line.start_with?("###")

    _code, text = line.split(/\s+/, 3)
    add_text_runs(scores, text.to_s, source_weight)
  end
end

scores = Hash.new { |hash, key| hash[key] = Hash.new(0) }

SOURCES.each do |relative_path, weight, kind|
  path = File.join(ROOT, relative_path)
  next unless File.file?(path)

  case kind
  when :tsv_phrase
    load_tsv_phrase_source(scores, path, weight)
  when :smart_phrase
    load_smart_phrase_source(scores, path, weight)
  when :dictionary
    load_dictionary_source(scores, path, weight)
  when :mcbopomofo_association
    load_mcbopomofo_association_source(scores, path, weight)
  when :ibus_dictionary
    load_ibus_dictionary_source(scores, path, weight)
  else
    add_text_runs(scores, File.read(path, encoding: "UTF-8"), weight)
  end
end

File.open(OUTPUT, "w:UTF-8") do |file|
  file.puts "# Generated by scripts/generate-association-seeds.rb."
  file.puts "# key<TAB>candidate1<TAB>candidate2..."
  file.puts "# Sources: local seed TSVs, McBopomofo associated phrases, typing corpora, IBus Cangjie, and Rime Cangjie dictionaries."
  scores.keys.sort.each do |key|
    candidates = scores[key]
      .reject { |candidate, _score| candidate == key }
      .sort_by { |candidate, score| [-score, candidate.length, candidate] }
      .map(&:first)
      .first(MAX_CANDIDATES_PER_KEY)
    next if candidates.empty?

    file.puts(([key] + candidates).join("\t"))
  end
end

puts "Generated #{OUTPUT} with #{scores.length} keys"
