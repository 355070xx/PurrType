#import <Cocoa/Cocoa.h>
#import "../src/PurrTypeEngine.h"
#import "../src/PurrTypeInputBehavior.h"

typedef struct {
    NSUInteger sourceCharacters;
    NSUInteger cjkCharacters;
    NSUInteger rawCharacters;
    NSUInteger uniqueCJKCharacters;
    NSUInteger simulatedKeystrokes;
    NSUInteger candidatePageTurns;
    NSUInteger maxCandidatePageIndex;
    NSUInteger maxCandidateIndex;
    NSUInteger labelChecks;
} MKFullBibleAuditStats;

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSString *TextAtPath(NSString *path) {
    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    AssertTrue(text.length > 0, [NSString stringWithFormat:@"loads text at %@ %@", path, error.localizedDescription ?: @""]);
    return text;
}

static NSString *FullBibleCorpusFromMarkdown(NSString *markdown) {
    NSString *beginMarker = @"<!-- FULL_BIBLE_TYPING_CORPUS_BEGIN -->";
    NSString *endMarker = @"<!-- FULL_BIBLE_TYPING_CORPUS_END -->";
    NSRange beginRange = [markdown rangeOfString:beginMarker];
    NSRange endRange = [markdown rangeOfString:endMarker];
    AssertTrue(beginRange.location != NSNotFound, @"full Bible corpus begin marker exists");
    AssertTrue(endRange.location != NSNotFound && endRange.location > NSMaxRange(beginRange), @"full Bible corpus end marker exists");

    NSRange textRange = NSMakeRange(NSMaxRange(beginRange), endRange.location - NSMaxRange(beginRange));
    NSMutableString *text = [[markdown substringWithRange:textRange] mutableCopy];
    while ([text hasPrefix:@"\n"] || [text hasPrefix:@"\r"]) {
        [text deleteCharactersInRange:NSMakeRange(0, 1)];
    }
    while ([text hasSuffix:@"\n"] || [text hasSuffix:@"\r"]) {
        [text deleteCharactersInRange:NSMakeRange(text.length - 1, 1)];
    }
    AssertTrue(text.length > 0, @"full Bible corpus has body text");
    return [text copy];
}

static BOOL IsCJKTypingText(NSString *text) {
    if (text.length == 0) {
        return NO;
    }

    unichar character = [text characterAtIndex:0];
    return (character >= 0x3400 && character <= 0x4DBF) ||
           (character >= 0x4E00 && character <= 0x9FFF) ||
           (character >= 0xF900 && character <= 0xFAFF);
}

static MKCandidate *CandidateMatchingText(NSArray<MKCandidate *> *candidates, NSString *text, NSUInteger *matchingIndex) {
    for (NSUInteger index = 0; index < candidates.count; index += 1) {
        MKCandidate *candidate = candidates[index];
        if ([candidate.text isEqualToString:text]) {
            if (matchingIndex) {
                *matchingIndex = index;
            }
            return candidate;
        }
    }
    return nil;
}

static NSString *JoinOrderedSet(NSOrderedSet<NSString *> *items, NSUInteger limit) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSUInteger count = MIN(limit, items.count);
    for (NSUInteger index = 0; index < count; index += 1) {
        [parts addObject:items[index]];
    }
    if (items.count > limit) {
        [parts addObject:[NSString stringWithFormat:@"... (+%lu more)", (unsigned long)(items.count - limit)]];
    }
    return [parts componentsJoinedByString:@", "];
}

static void WriteReport(NSString *path,
                        MKFullBibleAuditStats stats,
                        NSOrderedSet<NSString *> *missingCode,
                        NSOrderedSet<NSString *> *missingCandidate,
                        NSOrderedSet<NSString *> *labelFailures) {
    BOOL pass = missingCode.count == 0 && missingCandidate.count == 0 && labelFailures.count == 0;
    NSString *report = [NSString stringWithFormat:
        @"# Full Bible Typing Audit\n\n"
         "- Source text: Chinese Union Version, Traditional Chinese, `chi-cuv.usfx.xml` from `seven1m/open-bibles`.\n"
         "- Source license: Public Domain as listed by `seven1m/open-bibles`.\n"
         "- Full replay text: docs/typing/full_bible_typing_corpus.md\n"
         "- Scope: all 66 books, 1,189 chapters, 31,100 verses extracted from the XML source.\n"
         "- Source characters: %lu\n"
         "- CJK characters replayed: %lu\n"
         "- Raw characters replayed: %lu\n"
         "- Unique CJK characters checked: %lu\n"
         "- Simulated keystrokes: %lu\n"
         "- Candidate page turns: %lu\n"
         "- Max candidate page index: %lu\n"
         "- Max candidate index: %lu\n"
         "- Unique candidate label checks: %lu\n"
         "- Missing Sucheng reverse-code characters: %lu\n"
         "- Missing Sucheng candidate characters: %lu\n"
         "- Candidate page/label failures: %lu\n"
         "- Result: %@\n\n"
         "## Missing Reverse-Code Characters\n\n%@\n\n"
         "## Missing Candidate Characters\n\n%@\n\n"
         "## Candidate Page/Label Failures\n\n%@\n",
        (unsigned long)stats.sourceCharacters,
        (unsigned long)stats.cjkCharacters,
        (unsigned long)stats.rawCharacters,
        (unsigned long)stats.uniqueCJKCharacters,
        (unsigned long)stats.simulatedKeystrokes,
        (unsigned long)stats.candidatePageTurns,
        (unsigned long)stats.maxCandidatePageIndex,
        (unsigned long)stats.maxCandidateIndex,
        (unsigned long)stats.labelChecks,
        (unsigned long)missingCode.count,
        (unsigned long)missingCandidate.count,
        (unsigned long)labelFailures.count,
        pass ? @"PASS" : @"FAIL",
        missingCode.count == 0 ? @"None" : JoinOrderedSet(missingCode, 200),
        missingCandidate.count == 0 ? @"None" : JoinOrderedSet(missingCandidate, 200),
        labelFailures.count == 0 ? @"None" : JoinOrderedSet(labelFailures, 200)];

    NSError *error = nil;
    BOOL wrote = [report writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    AssertTrue(wrote, [NSString stringWithFormat:@"writes full Bible audit report %@", error.localizedDescription ?: @""]);
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *corpusPath = [root stringByAppendingPathComponent:@"docs/typing/full_bible_typing_corpus.md"];
        NSString *corpus = FullBibleCorpusFromMarkdown(TextAtPath(corpusPath));

        NSString *cangjieDirectory = [root stringByAppendingPathComponent:@"third_party/rime-cangjie"];
        NSString *pinyinPath = [root stringByAppendingPathComponent:@"resources/pinyin_seed.tsv"];
        PurrTypeEngine *engine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                             pinyinPath:pinyinPath
                                                                           learningPath:nil];

        NSMutableDictionary<NSString *, NSNumber *> *keystrokeCache = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSString *, NSNumber *> *pageTurnCache = [NSMutableDictionary dictionary];
        NSMutableOrderedSet<NSString *> *uniqueCJK = [NSMutableOrderedSet orderedSet];
        NSMutableOrderedSet<NSString *> *missingCode = [NSMutableOrderedSet orderedSet];
        NSMutableOrderedSet<NSString *> *missingCandidate = [NSMutableOrderedSet orderedSet];
        NSMutableOrderedSet<NSString *> *labelFailures = [NSMutableOrderedSet orderedSet];
        __block MKFullBibleAuditStats stats = {0};
        stats.sourceCharacters = corpus.length;

        [corpus enumerateSubstringsInRange:NSMakeRange(0, corpus.length)
                                   options:NSStringEnumerationByComposedCharacterSequences
                                usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            (void)substringRange;
            (void)enclosingRange;
            (void)stop;

            if (!IsCJKTypingText(substring)) {
                stats.rawCharacters += 1;
                stats.simulatedKeystrokes += substring.length;
                return;
            }

            stats.cjkCharacters += 1;
            [uniqueCJK addObject:substring];

            NSNumber *cachedKeystrokes = keystrokeCache[substring];
            if (cachedKeystrokes) {
                stats.simulatedKeystrokes += cachedKeystrokes.unsignedIntegerValue;
                stats.candidatePageTurns += pageTurnCache[substring].unsignedIntegerValue;
                return;
            }

            NSString *code = [engine preferredSuchengCodeForText:substring];
            if (code.length == 0) {
                [missingCode addObject:substring];
                return;
            }

            NSArray<MKCandidate *> *candidates = [engine candidatesForInput:code limit:1000 mode:MKInputModeSucheng];
            NSUInteger matchingIndex = NSNotFound;
            MKCandidate *candidate = CandidateMatchingText(candidates, substring, &matchingIndex);
            if (!candidate) {
                [missingCandidate addObject:[NSString stringWithFormat:@"%@(%@)", substring, code]];
                return;
            }

            NSUInteger pageSize = [PurrTypeInputBehavior candidatePageSize];
            NSUInteger expectedPageIndex = matchingIndex / pageSize;
            NSUInteger pageIndex = expectedPageIndex;
            NSArray<MKCandidate *> *page = [PurrTypeInputBehavior candidatePageFromPool:candidates pageIndex:&pageIndex];
            NSUInteger visibleIndex = matchingIndex % pageSize;
            if (pageIndex != expectedPageIndex ||
                visibleIndex >= page.count ||
                ![page[visibleIndex].text isEqualToString:substring]) {
                [labelFailures addObject:[NSString stringWithFormat:@"%@(%@)", substring, code]];
                return;
            }

            NSArray<NSString *> *labels = [PurrTypeInputBehavior displayTextsForCandidates:page
                                                                                       buffer:code
                                                                        rawEnglishModeActive:NO
                                                                       associationModeActive:NO
                                                                 rawEnglishCandidateEnabled:YES];
            NSString *expectedPrefix = [NSString stringWithFormat:@"%lu ", (unsigned long)(visibleIndex + 1)];
            NSUInteger labelIndex = [[labels firstObject] hasPrefix:@"0 "] ? visibleIndex + 1 : visibleIndex;
            if (labelIndex >= labels.count || ![labels[labelIndex] hasPrefix:expectedPrefix]) {
                [labelFailures addObject:[NSString stringWithFormat:@"%@(%@)", substring, code]];
                return;
            }

            NSUInteger keystrokes = code.length + expectedPageIndex + 1;
            keystrokeCache[substring] = @(keystrokes);
            pageTurnCache[substring] = @(expectedPageIndex);
            stats.simulatedKeystrokes += keystrokes;
            stats.candidatePageTurns += expectedPageIndex;
            stats.maxCandidatePageIndex = MAX(stats.maxCandidatePageIndex, expectedPageIndex);
            stats.maxCandidateIndex = MAX(stats.maxCandidateIndex, matchingIndex);
            stats.labelChecks += 1;
        }];
        stats.uniqueCJKCharacters = uniqueCJK.count;

        NSString *reportPath = [root stringByAppendingPathComponent:@"build/full_bible_typing_audit.md"];
        WriteReport(reportPath, stats, missingCode, missingCandidate, labelFailures);

        AssertTrue(missingCode.count == 0, @"full Bible audit has no missing Sucheng reverse-code characters");
        AssertTrue(missingCandidate.count == 0, @"full Bible audit has no missing Sucheng candidates");
        AssertTrue(labelFailures.count == 0, @"full Bible audit has no candidate page or label failures");
        NSLog(@"PASS: PurrTypeFullBibleTypingAudit %@", reportPath);
    }
    return 0;
}
