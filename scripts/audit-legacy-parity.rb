#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "set"

ROOT = File.expand_path("..", __dir__)
BUILD_DIR = File.join(ROOT, "build")
REPORT_PATH = File.join(BUILD_DIR, "legacy_parity_audit.md")
SUCHENG_MISMATCH_TSV_PATH = File.join(BUILD_DIR, "legacy_sucheng_first_page_mismatches.tsv")
SUCHENG_SLOT_TSV_PATH = File.join(BUILD_DIR, "legacy_sucheng_slot_diffs.tsv")
SUCHENG_OVERRIDE_SUGGESTIONS_TSV_PATH = File.join(BUILD_DIR, "legacy_sucheng_override_suggestions.tsv")
SUCHENG_ANCHOR_CONFLICTS_TSV_PATH = File.join(BUILD_DIR, "legacy_sucheng_anchor_conflicts.tsv")
CANGJIE_MISMATCH_TSV_PATH = File.join(BUILD_DIR, "legacy_cangjie_first_page_mismatches.tsv")
CANGJIE_SLOT_TSV_PATH = File.join(BUILD_DIR, "legacy_cangjie_slot_diffs.tsv")
SUCHENG_ANCHOR_PATH = File.join(ROOT, "resources/sucheng_position_anchors.tsv")
SUCHENG_OVERRIDES_PATH = File.join(ROOT, "resources/sucheng_order_guards.tsv")
PAGE_SIZE = 9

def load_cin(path, max_code_len: nil)
  table = Hash.new { |hash, key| hash[key] = [] }
  seen = Hash.new { |hash, key| hash[key] = Set.new }
  in_chardef = false

  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.strip
    next if line.empty? || line.start_with?("#")

    unless in_chardef
      in_chardef = true if line == "%chardef begin"
      next
    end
    break if line == "%chardef end"

    code, text = line.split(/\s+/, 2)
    next if code.nil? || text.nil?

    code = code.downcase
    next if max_code_len && code.length > max_code_len
    next unless code.match?(/\A[a-z]+\z/)
    next if seen[code].include?(text)

    seen[code] << text
    table[code] << text
  end

  table
end

def load_ibus_table(path, max_code_len: nil)
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
    next if max_code_len && code.length > max_code_len
    next unless code.match?(/\A[a-z]+\z/)
    next if seen[code].include?(text)

    seen[code] << text
    table[code] << text
  end

  table
end

def load_snapshot(path, max_code_len: nil)
  table = {}
  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.chomp
    next if line.empty? || line.start_with?("#")

    code, *candidates = line.split("\t")
    next if max_code_len && code.length > max_code_len

    table[code] = candidates
  end
  table
end

def load_target_table(env_key, fallback_path, max_code_len: nil, fallback_loader: nil)
  fallback_loader ||= method(:load_cin)
  env_path = ENV[env_key].to_s.strip
  if env_path.empty?
    return [
      fallback_loader.call(fallback_path, max_code_len: max_code_len),
      "`#{fallback_path.sub("#{ROOT}/", "")}`"
    ]
  end

  resolved_path = File.expand_path(env_path, ROOT)
  unless File.file?(resolved_path)
    abort "FAIL: #{env_key} points to missing target table #{resolved_path}"
  end

  [
    load_snapshot(resolved_path, max_code_len: max_code_len),
    "`#{resolved_path}` from `$#{env_key}`"
  ]
end

def load_sucheng_anchors(path)
  anchors = []
  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.chomp
    next if line.empty? || line.start_with?("#")

    code, text, position, source = line.split("\t", 4)
    code = code.to_s.downcase
    expected_position = position.to_i
    unless code.match?(/\A[a-z]{1,2}\z/) && text.to_s.length > 0 && expected_position.positive?
      abort "FAIL: invalid Sucheng position anchor row: #{line}"
    end

    anchors << {
      code: code,
      text: text,
      expected_position: expected_position,
      source: source.to_s.empty? ? "verified legacy Sucheng anchor" : source
    }
  end
  anchors
end

def apply_candidate_order_overrides(table, path, source:)
  current = table.transform_values(&:dup)
  File.foreach(path, encoding: "UTF-8") do |raw_line|
    line = raw_line.chomp
    next if line.empty? || line.start_with?("#")

    row_source, code, *ordered_texts = line.split("\t")
    next unless row_source == source && code && !ordered_texts.empty?

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

def compare_tables(current, target, sample_codes)
  comparable = current.keys.select { |code| target.key?(code) }.sort
  first_same = comparable.count { |code| current[code].first == target[code].first }
  exact_page_same = comparable.count { |code| current[code].first(PAGE_SIZE) == target[code].first(PAGE_SIZE) }
  same_page_set = comparable.count { |code| current[code].first(PAGE_SIZE).to_set == target[code].first(PAGE_SIZE).to_set }
  slot_stats = {
    target_slots: 0,
    exact_position: 0,
    different_position: 0,
    missing_from_current_page: 0
  }
  slot_rows = []

  mismatches = comparable.each_with_object([]) do |code, rows|
    current_page = current[code].first(PAGE_SIZE)
    target_page = target[code].first(PAGE_SIZE)

    target_page.each_with_index do |target_text, target_index|
      current_index = current_page.index(target_text)
      status = if current_index.nil?
                 :missing_from_current_page
               elsif current_index == target_index
                 :exact_position
               else
                 :different_position
               end
      slot_stats[:target_slots] += 1
      slot_stats[status] += 1
      slot_rows << {
        code: code,
        target_position: target_index + 1,
        target_text: target_text,
        current_position: current_index ? current_index + 1 : nil,
        current_text_at_target_position: current_page[target_index],
        status: status
      }
    end

    next if current_page == target_page

    target_first = target_page.first
    current_index = current[code].index(target_first)
    target_first_missing_from_current_page = current_page.index(target_first).nil?
    slot_differences = target_page.each_with_index.count { |text, index| current_page[index] != text }
    rows << {
      code: code,
      current: current_page,
      target: target_page,
      target_first: target_first,
      current_index: current_index,
      target_first_missing_from_current_page: target_first_missing_from_current_page,
      slot_differences: slot_differences
    }
  end

  mismatch_by_code = mismatches.each_with_object({}) { |row, hash| hash[row[:code]] = row }
  sample_rows = sample_codes.map { |code| mismatch_by_code[code] }.compact
  remaining_rows = mismatches.reject { |row| sample_codes.include?(row[:code]) }
  ranked_rows = remaining_rows.sort_by do |row|
    [
      row[:target_first_missing_from_current_page] ? 0 : 1,
      row[:current_index] || 10_000,
      row[:code].length,
      row[:code]
    ]
  end

  {
    comparable: comparable.count,
    first_same: first_same,
    exact_page_same: exact_page_same,
    same_page_set: same_page_set,
    mismatches: mismatches.count,
    slot_stats: slot_stats,
    slot_rows: slot_rows,
    mismatch_rows: mismatches,
    sample_rows: sample_rows,
    ranked_rows: ranked_rows
  }
end

def candidate_list(values)
  values.join(" ")
end

def mismatch_markdown(rows, limit)
  selected = rows.first(limit)
  return "None\n" if selected.empty?

  lines = ["| Code | Current first page | legacy proxy first page | Proxy first candidate position in current |",
           "| --- | --- | --- | --- |"]
  selected.each do |row|
    position = row[:current_index] ? (row[:current_index] + 1).to_s : "missing from current candidates"
    lines << "| `#{row[:code]}` | #{candidate_list(row[:current])} | #{candidate_list(row[:target])} | #{position} |"
  end
  lines.join("\n") + "\n"
end

def section(title, result, source_note, mismatch_limit)
  lines = []
  lines << "## #{title}"
  lines << ""
  lines << source_note
  lines << ""
  lines << "- Comparable codes: #{result[:comparable]}"
  lines << "- Same first candidate: #{result[:first_same]}"
  lines << "- Exact first page matches: #{result[:exact_page_same]}"
  lines << "- Same first-page candidate set: #{result[:same_page_set]}"
  lines << "- First-page mismatches: #{result[:mismatches]}"
  lines << "- Target first-page slots compared: #{result[:slot_stats][:target_slots]}"
  lines << "- Exact slot matches: #{result[:slot_stats][:exact_position]}"
  lines << "- Different slot positions on current first page: #{result[:slot_stats][:different_position]}"
  lines << "- Target slots missing from current first page: #{result[:slot_stats][:missing_from_current_page]}"
  lines << ""
  lines << "### Locked High-Impact Samples"
  lines << ""
  lines << mismatch_markdown(result[:sample_rows], result[:sample_rows].count)
  lines << ""
  lines << "### Ranked Mismatches"
  lines << ""
  lines << mismatch_markdown(result[:ranked_rows], mismatch_limit)
  lines.join("\n")
end

def tsv_value(value)
  value.to_s.gsub(/[\t\r\n]+/, " ")
end

def write_tsv(path, headers, rows)
  File.open(path, "w:UTF-8") do |file|
    file.puts(headers.map { |value| tsv_value(value) }.join("\t"))
    rows.each do |row|
      file.puts(row.map { |value| tsv_value(value) }.join("\t"))
    end
  end
end

def write_mismatch_tsv(path, result)
  rows = result[:mismatch_rows].map do |row|
    target_first_position = row[:current_index] ? row[:current_index] + 1 : ""
    target_first_status = if row[:target_first_missing_from_current_page]
                            "missing_from_current_first_page"
                          elsif target_first_position == 1
                            "same_first_candidate"
                          else
                            "present_on_current_first_page"
                          end
    [
      row[:code],
      row[:slot_differences],
      candidate_list(row[:current]),
      candidate_list(row[:target]),
      row[:target_first],
      target_first_position,
      target_first_status
    ]
  end
  write_tsv(path,
            %w[code first_page_slot_differences current_first_page target_first_page target_first_candidate target_first_current_position target_first_status],
            rows)
end

def write_slot_tsv(path, result)
  rows = result[:slot_rows].map do |row|
    [
      row[:code],
      row[:target_position],
      row[:target_text],
      row[:current_position] || "",
      row[:current_text_at_target_position] || "",
      row[:status]
    ]
  end
  write_tsv(path,
            %w[code target_position target_candidate current_position current_candidate_at_target_position status],
            rows)
end

def anchors_by_code(anchors)
  anchors.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |anchor, grouped|
    grouped[anchor[:code]] << anchor
  end
end

def anchor_conflicts_for_page(code, page, grouped_anchors)
  (grouped_anchors[code] || []).select do |anchor|
    next false if anchor[:expected_position] > page.length

    page[anchor[:expected_position] - 1] != anchor[:text]
  end
end

def suggest_sucheng_overrides(result, anchors)
  grouped_anchors = anchors_by_code(anchors)
  suggestions = []
  anchor_conflicts = []

  result[:mismatch_rows].each do |row|
    current_page = row[:current]
    target_page = row[:target]
    conflicts = anchor_conflicts_for_page(row[:code], target_page, grouped_anchors)
    conflicts.each do |anchor|
      anchor_conflicts << {
        code: row[:code],
        text: anchor[:text],
        expected_position: anchor[:expected_position],
        target_position: target_page.index(anchor[:text]) ? target_page.index(anchor[:text]) + 1 : nil,
        current: current_page,
        target: target_page,
        source: anchor[:source]
      }
    end

    next unless current_page.count == PAGE_SIZE && target_page.count == PAGE_SIZE
    next unless current_page.to_set == target_page.to_set
    next unless conflicts.empty?

    suggestions << {
      code: row[:code],
      current: current_page,
      target: target_page,
      slot_differences: row[:slot_differences]
    }
  end

  {
    suggestions: suggestions.sort_by { |row| [-row[:slot_differences], row[:code].length, row[:code]] },
    anchor_conflicts: anchor_conflicts.sort_by { |row| [row[:code].length, row[:code], row[:expected_position]] }
  }
end

def write_sucheng_override_suggestions(path, suggestions)
  rows = suggestions.map do |row|
    ["quick", row[:code], *row[:target], row[:slot_differences], candidate_list(row[:current])]
  end
  write_tsv(path,
            ["source", "code", "candidate1", "candidate2", "candidate3", "candidate4", "candidate5", "candidate6", "candidate7", "candidate8", "candidate9", "slot_differences", "current_first_page"],
            rows)
end

def write_anchor_conflicts(path, conflicts)
  rows = conflicts.map do |row|
    [
      row[:code],
      row[:text],
      row[:expected_position],
      row[:target_position] || "",
      candidate_list(row[:current]),
      candidate_list(row[:target]),
      row[:source]
    ]
  end
  write_tsv(path,
            %w[code candidate expected_position target_position current_first_page target_first_page source],
            rows)
end

def override_suggestion_markdown(suggestions, limit)
  selected = suggestions.first(limit)
  return "None\n" if selected.empty?

  lines = ["| Code | Suggested override first page | Current first page | Slot differences |",
           "| --- | --- | --- | --- |"]
  selected.each do |row|
    lines << "| `#{row[:code]}` | #{candidate_list(row[:target])} | #{candidate_list(row[:current])} | #{row[:slot_differences]} |"
  end
  lines.join("\n") + "\n"
end

def anchor_conflict_markdown(conflicts)
  return "None\n" if conflicts.empty?

  lines = ["| Code | Candidate | Anchor position | Target/proxy position | Current first page | Target/proxy first page |",
           "| --- | --- | --- | --- | --- | --- |"]
  conflicts.each do |row|
    lines << "| `#{row[:code]}` | #{row[:text]} | #{row[:expected_position]} | #{row[:target_position] || "missing"} | #{candidate_list(row[:current])} | #{candidate_list(row[:target])} |"
  end
  lines.join("\n") + "\n"
end

def anchor_checks(current, target, anchors)
  anchors.map do |anchor|
    current_page = current[anchor[:code]] || []
    target_page = target[anchor[:code]] || []
    current_position = current_page.index(anchor[:text])
    target_position = target_page.index(anchor[:text])
    {
      code: anchor[:code],
      text: anchor[:text],
      expected_position: anchor[:expected_position],
      current_position: current_position ? current_position + 1 : nil,
      target_position: target_position ? target_position + 1 : nil,
      source: anchor[:source]
    }
  end
end

def anchor_markdown(rows)
  lines = ["| Code | Candidate | Expected legacy position | Current position | Proxy position | Source | Status |",
           "| --- | --- | --- | --- | --- | --- | --- |"]
  rows.each do |row|
    current_status = row[:current_position] == row[:expected_position] ? "current matches" : "current differs"
    proxy_status = row[:target_position] == row[:expected_position] ? "proxy matches" : "proxy differs"
    lines << "| `#{row[:code]}` | #{row[:text]} | #{row[:expected_position]} | #{row[:current_position] || "missing"} | #{row[:target_position] || "missing"} | #{row[:source]} | #{current_status}; #{proxy_status} |"
  end
  lines.join("\n") + "\n"
end

def anchor_failures(rows)
  rows.select { |row| row[:current_position] != row[:expected_position] }
end

quick_classic_source_path = File.join(ROOT, "third_party/ibus-table-chinese/quick-classic.txt")
sucheng_current = load_snapshot(File.join(ROOT, "resources/sucheng_first_pages.tsv"))
sucheng_full_order = apply_candidate_order_overrides(load_ibus_table(quick_classic_source_path, max_code_len: 2),
                                                     SUCHENG_OVERRIDES_PATH,
                                                     source: "quick")
sucheng_legacy_proxy, sucheng_target_source = load_target_table("LEGACY_SUCHENG_TARGET_TSV",
                                                            quick_classic_source_path,
                                                            max_code_len: 2,
                                                            fallback_loader: method(:load_ibus_table))
cangjie_current = load_ibus_table(File.join(ROOT, "third_party/ibus-table-chinese/cangjie5.txt"))
cangjie_legacy_proxy, cangjie_target_source = load_target_table("LEGACY_CANGJIE_TARGET_TSV",
                                                            File.join(ROOT, "third_party/cin-tables/mscj3.cin"))

sucheng_samples = %w[hi ms yr yu kb mn vo ao ip or of oa vd if qo sl ar hm]
cangjie_samples = %w[hapi amyo mf hqi m kb k klg o nn l mgln mobuc mwv mnr vio yymr owjr onf omwa vnd]

sucheng_anchors = load_sucheng_anchors(SUCHENG_ANCHOR_PATH)
sucheng_result = compare_tables(sucheng_current, sucheng_legacy_proxy, sucheng_samples)
cangjie_result = compare_tables(cangjie_current, cangjie_legacy_proxy, cangjie_samples)
sucheng_anchor_rows = anchor_checks(sucheng_full_order, sucheng_legacy_proxy, sucheng_anchors)
sucheng_anchor_failures = anchor_failures(sucheng_anchor_rows)
sucheng_override_review = suggest_sucheng_overrides(sucheng_result, sucheng_anchors)
sucheng_override_suggestions = sucheng_override_review[:suggestions]
sucheng_anchor_conflicts = sucheng_override_review[:anchor_conflicts]

report = [
  "# Legacy IME Parity Audit",
  "",
  "Generated by `make audit-legacy-parity`.",
  "",
  "This report does not claim to include proprietary dictionary files. By default it compares PurrType's bundled open tables against IBus Quick Classic (`quick-classic.txt`) for Traditional Simple Cang Jie / Sucheng and the CC0 `mscj3.cin` proxy for Cangjie 3 compatibility. Set `$LEGACY_SUCHENG_TARGET_TSV` or `$LEGACY_CANGJIE_TARGET_TSV` to compare against a locally reviewed legacy first-page TSV instead.",
  "",
  "Use this as a review queue for legacy Sucheng parity. Runtime `Sucheng` uses the bundled IBus Quick Classic table and applies verified anchors as guard rows. User-reported muscle-memory anchors are treated as higher confidence than proxy rows when they conflict.",
  "",
  "Machine-readable queues are also generated:",
  "",
  "- `build/legacy_sucheng_first_page_mismatches.tsv`",
  "- `build/legacy_sucheng_slot_diffs.tsv`",
  "- `build/legacy_sucheng_override_suggestions.tsv`",
  "- `build/legacy_sucheng_anchor_conflicts.tsv`",
  "- `build/legacy_cangjie_first_page_mismatches.tsv`",
  "- `build/legacy_cangjie_slot_diffs.tsv`",
  "",
  "## Known Legacy Muscle-Memory Anchors",
  "",
  "Loaded from `resources/sucheng_position_anchors.tsv`. These rows are treated as hard guards for the bundled Quick Classic Sucheng order.",
  "",
  anchor_markdown(sucheng_anchor_rows),
  "",
  "- Anchor guard result: #{sucheng_anchor_failures.empty? ? "PASS" : "FAIL"}",
  "",
  "### Target/Proxy Anchor Conflicts",
  "",
  anchor_conflict_markdown(sucheng_anchor_conflicts),
  "",
  "## Reviewable Sucheng Override Suggestions",
  "",
  "These rows have the same nine first-page candidates as the current Sucheng runtime order but in a different target/proxy order, and they do not conflict with verified anchors. They are suggestions only; reviewed rows can be copied into `resources/sucheng_order_guards.tsv` in small batches.",
  "",
  "- Suggestions: #{sucheng_override_suggestions.count}",
  "- Blocked by verified anchors: #{sucheng_anchor_conflicts.count}",
  "",
  override_suggestion_markdown(sucheng_override_suggestions, 40),
  "",
  section("Sucheng Quick Classic vs Legacy Sucheng Proxy",
          sucheng_result,
          "Current baseline: runtime snapshot `resources/sucheng_first_pages.tsv`, generated from bundled `third_party/ibus-table-chinese/quick-classic.txt` plus `resources/sucheng_order_guards.tsv`. Target source: #{sucheng_target_source}.",
          80),
  "",
  section("Cangjie vs Legacy Cangjie Proxy",
          cangjie_result,
          "Current baseline: `third_party/ibus-table-chinese/cangjie5.txt`. Target source: #{cangjie_target_source}.",
          80),
  ""
].join("\n")

FileUtils.mkdir_p(BUILD_DIR)
write_mismatch_tsv(SUCHENG_MISMATCH_TSV_PATH, sucheng_result)
write_slot_tsv(SUCHENG_SLOT_TSV_PATH, sucheng_result)
write_sucheng_override_suggestions(SUCHENG_OVERRIDE_SUGGESTIONS_TSV_PATH, sucheng_override_suggestions)
write_anchor_conflicts(SUCHENG_ANCHOR_CONFLICTS_TSV_PATH, sucheng_anchor_conflicts)
write_mismatch_tsv(CANGJIE_MISMATCH_TSV_PATH, cangjie_result)
write_slot_tsv(CANGJIE_SLOT_TSV_PATH, cangjie_result)
File.write(REPORT_PATH, report)
puts "PASS: Legacy parity audit #{REPORT_PATH}"
puts "PASS: Legacy parity queue #{SUCHENG_MISMATCH_TSV_PATH}"
puts "PASS: Legacy parity slot diffs #{SUCHENG_SLOT_TSV_PATH}"
puts "PASS: Sucheng override suggestions #{SUCHENG_OVERRIDE_SUGGESTIONS_TSV_PATH}"
puts "PASS: Sucheng anchor conflicts #{SUCHENG_ANCHOR_CONFLICTS_TSV_PATH}"
puts "PASS: Legacy Cangjie parity queue #{CANGJIE_MISMATCH_TSV_PATH}"
puts "PASS: Legacy Cangjie parity slot diffs #{CANGJIE_SLOT_TSV_PATH}"
if sucheng_anchor_failures.empty?
  puts "PASS: Sucheng anchors #{SUCHENG_ANCHOR_PATH}"
else
  abort "FAIL: Sucheng anchors drifted; see #{REPORT_PATH}"
end
