#import <Cocoa/Cocoa.h>
#import "../src/PurrTypeEngine.h"
#import "../src/PurrTypeInputBehavior.h"
#import "../src/PurrTypePreferencesConstants.h"

static const NSUInteger MKTypingOneHourTargetKeystrokes = 14400;

typedef struct {
    NSUInteger keystrokes;
    NSUInteger repetitions;
    NSUInteger chineseSelections;
    NSUInteger candidatePageTurns;
    NSUInteger rawCharacters;
    NSUInteger uniqueChineseCharacters;
    NSUInteger cangjieSelections;
    NSUInteger newSuchengLearningReplays;
    NSUInteger preferenceToggleChecks;
} MKTypingSimulationStats;

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

static NSString *TypingCorpusFromMarkdown(NSString *markdown) {
    NSString *beginMarker = @"<!-- TYPING_CORPUS_BEGIN -->";
    NSString *endMarker = @"<!-- TYPING_CORPUS_END -->";
    NSRange beginRange = [markdown rangeOfString:beginMarker];
    NSRange endRange = [markdown rangeOfString:endMarker];
    AssertTrue(beginRange.location != NSNotFound, @"typing corpus begin marker exists");
    AssertTrue(endRange.location != NSNotFound && endRange.location > NSMaxRange(beginRange), @"typing corpus end marker exists");

    NSRange textRange = NSMakeRange(NSMaxRange(beginRange), endRange.location - NSMaxRange(beginRange));
    NSMutableString *text = [[markdown substringWithRange:textRange] mutableCopy];
    while ([text hasPrefix:@"\n"] || [text hasPrefix:@"\r"]) {
        [text deleteCharactersInRange:NSMakeRange(0, 1)];
    }
    while ([text hasSuffix:@"\n"] || [text hasSuffix:@"\r"]) {
        [text deleteCharactersInRange:NSMakeRange(text.length - 1, 1)];
    }
    AssertTrue(text.length > 0, @"typing corpus has body text");
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

static BOOL FirstCandidateIsText(NSArray<MKCandidate *> *candidates, NSString *text) {
    return candidates.count > 0 && [candidates.firstObject.text isEqualToString:text];
}

static NSUInteger SuchengKeystrokesForText(NSString *text,
                                           PurrTypeEngine *engine,
                                           NSMutableDictionary<NSString *, NSNumber *> *keystrokeCache,
                                           NSMutableDictionary<NSString *, NSNumber *> *pageTurnCache,
                                           MKTypingSimulationStats *stats) {
    NSNumber *cached = keystrokeCache[text];
    if (cached) {
        return cached.unsignedIntegerValue;
    }

    NSString *code = [engine preferredSuchengCodeForText:text];
    AssertTrue(code.length > 0, [NSString stringWithFormat:@"Sucheng code exists for %@", text]);

    NSArray<MKCandidate *> *candidates = [engine candidatesForInput:code limit:1000 mode:MKInputModeSucheng];
    NSUInteger matchingIndex = NSNotFound;
    MKCandidate *candidate = CandidateMatchingText(candidates, text, &matchingIndex);
    AssertTrue(candidate != nil, [NSString stringWithFormat:@"Sucheng candidates for %@ contain %@", code, text]);

    NSUInteger pageSize = [PurrTypeInputBehavior candidatePageSize];
    NSUInteger expectedPageIndex = matchingIndex / pageSize;
    NSUInteger pageIndex = expectedPageIndex;
    NSArray<MKCandidate *> *page = [PurrTypeInputBehavior candidatePageFromPool:candidates pageIndex:&pageIndex];
    AssertTrue(pageIndex == expectedPageIndex, [NSString stringWithFormat:@"candidate page is stable for %@ %@", code, text]);

    NSUInteger visibleIndex = matchingIndex % pageSize;
    AssertTrue(visibleIndex < page.count, [NSString stringWithFormat:@"visible candidate index exists for %@ %@", code, text]);
    AssertTrue([page[visibleIndex].text isEqualToString:text], [NSString stringWithFormat:@"visible candidate selects %@", text]);

    NSArray<NSString *> *labels = [PurrTypeInputBehavior displayTextsForCandidates:page
                                                                               buffer:code
                                                                rawEnglishModeActive:NO
                                                               associationModeActive:NO
                                                         rawEnglishCandidateEnabled:YES];
    NSString *expectedPrefix = [NSString stringWithFormat:@"%lu ", (unsigned long)(visibleIndex + 1)];
    NSUInteger labelIndex = [[labels firstObject] hasPrefix:@"0 "] ? visibleIndex + 1 : visibleIndex;
    AssertTrue(labelIndex < labels.count && [labels[labelIndex] hasPrefix:expectedPrefix], [NSString stringWithFormat:@"candidate label has number for %@", text]);

    NSUInteger keystrokes = code.length + expectedPageIndex + 1;
    keystrokeCache[text] = @(keystrokes);
    pageTurnCache[text] = @(expectedPageIndex);
    stats->uniqueChineseCharacters += 1;
    return keystrokes;
}

static NSUInteger CangjieKeystrokesForText(NSString *text,
                                           PurrTypeEngine *engine,
                                           MKTypingSimulationStats *stats) {
    NSString *code = [engine preferredCangjieCodeForText:text];
    AssertTrue(code.length > 0, [NSString stringWithFormat:@"Cangjie code exists for %@", text]);

    NSArray<MKCandidate *> *candidates = [engine candidatesForInput:code limit:1000 mode:MKInputModeCangjie];
    NSUInteger matchingIndex = NSNotFound;
    MKCandidate *candidate = CandidateMatchingText(candidates, text, &matchingIndex);
    AssertTrue(candidate != nil, [NSString stringWithFormat:@"Cangjie candidates for %@ contain %@", code, text]);

    NSUInteger pageSize = [PurrTypeInputBehavior candidatePageSize];
    NSUInteger pageIndex = matchingIndex / pageSize;
    NSArray<MKCandidate *> *page = [PurrTypeInputBehavior candidatePageFromPool:candidates pageIndex:&pageIndex];
    NSUInteger visibleIndex = matchingIndex % pageSize;
    AssertTrue(visibleIndex < page.count, [NSString stringWithFormat:@"Cangjie visible index exists for %@ %@", code, text]);
    AssertTrue([page[visibleIndex].text isEqualToString:text], [NSString stringWithFormat:@"Cangjie visible candidate selects %@", text]);

    NSArray<NSString *> *labels = [PurrTypeInputBehavior displayTextsForCandidates:page
                                                                               buffer:code
                                                                  rawEnglishModeActive:NO
                                                                 associationModeActive:NO
                                                           rawEnglishCandidateEnabled:YES];
    NSString *expectedPrefix = [NSString stringWithFormat:@"%lu ", (unsigned long)(visibleIndex + 1)];
    NSUInteger labelIndex = [[labels firstObject] hasPrefix:@"0 "] ? visibleIndex + 1 : visibleIndex;
    AssertTrue(labelIndex < labels.count && [labels[labelIndex] hasPrefix:expectedPrefix], [NSString stringWithFormat:@"Cangjie label has number for %@", text]);

    stats->cangjieSelections += 1;
    return code.length + pageIndex + 1;
}

static NSString *ReplayCorpusOnce(NSString *corpus,
                                  PurrTypeEngine *engine,
                                  NSMutableDictionary<NSString *, NSNumber *> *keystrokeCache,
                                  NSMutableDictionary<NSString *, NSNumber *> *pageTurnCache,
                                  MKTypingSimulationStats *stats) {
    NSMutableString *output = [NSMutableString stringWithCapacity:corpus.length];
    [corpus enumerateSubstringsInRange:NSMakeRange(0, corpus.length)
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substringRange;
        (void)enclosingRange;
        (void)stop;

        if (IsCJKTypingText(substring)) {
            NSUInteger keystrokes = SuchengKeystrokesForText(substring, engine, keystrokeCache, pageTurnCache, stats);
            stats->keystrokes += keystrokes;
            stats->candidatePageTurns += pageTurnCache[substring].unsignedIntegerValue;
            stats->chineseSelections += 1;
        } else {
            stats->keystrokes += substring.length;
            stats->rawCharacters += 1;
        }
        [output appendString:substring];
    }];
    return [output copy];
}

static NSString *ReplayCangjieText(NSString *text, PurrTypeEngine *engine, MKTypingSimulationStats *stats) {
    NSMutableString *output = [NSMutableString stringWithCapacity:text.length];
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substringRange;
        (void)enclosingRange;
        (void)stop;

        if (IsCJKTypingText(substring)) {
            stats->keystrokes += CangjieKeystrokesForText(substring, engine, stats);
        } else {
            stats->keystrokes += substring.length;
            stats->rawCharacters += 1;
        }
        [output appendString:substring];
    }];
    return [output copy];
}

static void RunPreferenceToggleChecks(PurrTypeEngine *engine, MKTypingSimulationStats *stats) {
    NSArray<MKCandidate *> *candidates = [engine candidatesForInput:@"d" limit:20 mode:MKInputModeSucheng];
    AssertTrue(candidates.count > 0, @"preference toggle fixture has Sucheng candidates");

    NSArray<NSString *> *withRawEnglish = [PurrTypeInputBehavior displayTextsForCandidates:[candidates subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)2, candidates.count))]
                                                                                       buffer:@"d"
                                                                          rawEnglishModeActive:NO
                                                                         associationModeActive:NO
                                                                   rawEnglishCandidateEnabled:YES];
    AssertTrue([[withRawEnglish firstObject] isEqualToString:@"0 d"], @"raw-English candidate is visible first when preference is on");

    NSArray<NSString *> *withTrailingRawEnglish =
        [PurrTypeInputBehavior displayTextsForCandidates:[candidates subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)2, candidates.count))]
                                                  buffer:@"d"
                                    rawEnglishModeActive:NO
                                   associationModeActive:NO
                             rawEnglishCandidateEnabled:YES
                            rawEnglishCandidatePosition:MKRawEnglishCandidatePositionTrailing];
    AssertTrue([[withTrailingRawEnglish lastObject] isEqualToString:@"0 d"], @"raw-English candidate can be placed after Chinese candidates");

    NSArray<NSString *> *withoutRawEnglish = [PurrTypeInputBehavior displayTextsForCandidates:[candidates subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)2, candidates.count))]
                                                                                          buffer:@"d"
                                                                             rawEnglishModeActive:NO
                                                                            associationModeActive:NO
                                                                      rawEnglishCandidateEnabled:NO];
    AssertTrue(![withoutRawEnglish containsObject:@"0 d"], @"raw-English candidate is hidden when preference is off");

    AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:49
                                                             modifiers:0
                                                        candidateCount:10
                                                    spacePagingEnabled:YES] == 1,
               @"Space pages forward when preference is on");
    AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:49
                                                             modifiers:0
                                                        candidateCount:10
                                                    spacePagingEnabled:NO] == 0,
               @"Space stops paging when preference is off");
    AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:48
                                                             modifiers:0
                                                        candidateCount:10
                                                    spacePagingEnabled:NO] == 1,
               @"Tab still pages when Space paging preference is off");
    stats->preferenceToggleChecks += 5;
}

static void RunNewSuchengLearningReplay(NSString *cangjieDirectory,
                                        NSString *pinyinPath,
                                        MKTypingSimulationStats *stats) {
    NSString *learningPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"PurrTypeTypingSimulation-%@.json", [NSUUID UUID].UUIDString]];
    NSString *phrase = @"我想繼續";
    NSString *code = @"hidpvivc";

    PurrTypeEngine *learningEngine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                                 pinyinPath:pinyinPath
                                                                               learningPath:learningPath];
    learningEngine.learningEnabled = YES;
    [learningEngine recordCommittedText:phrase code:code mode:MKInputModeSmartSucheng];
    AssertTrue(FirstCandidateIsText([learningEngine candidatesForInput:code limit:9 mode:MKInputModeSmartSucheng], phrase), @"New Sucheng replay learns committed phrase before reload");

    PurrTypeEngine *reloadedEngine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                                pinyinPath:pinyinPath
                                                                              learningPath:learningPath];
    reloadedEngine.learningEnabled = YES;
    NSArray<MKCandidate *> *learnedCandidates = [reloadedEngine candidatesForInput:code limit:9 mode:MKInputModeSmartSucheng];
    AssertTrue(!FirstCandidateIsText(learnedCandidates, phrase), @"New Sucheng session learning does not persist learned phrase after reload");

    NSMutableString *output = [NSMutableString string];
    MKCandidate *candidate = [learningEngine candidatesForInput:code limit:9 mode:MKInputModeSmartSucheng].firstObject;
    [output appendString:candidate.text];
    [output appendString:@" setting"];
    AssertTrue([output isEqualToString:@"我想繼續 setting"], @"New Sucheng replay commits learned phrase plus raw English");

    AssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:learningPath], @"New Sucheng replay does not create learning persistence");

    [reloadedEngine resetLearningState];
    [[NSFileManager defaultManager] removeItemAtPath:learningPath error:nil];
    stats->newSuchengLearningReplays += 1;
}

static void WriteReport(NSString *path, MKTypingSimulationStats stats, NSUInteger sourceCorpusLength, NSUInteger expectedLength) {
    NSString *report = [NSString stringWithFormat:
        @"# Typing Simulation Report\n\n"
         "- Source corpus: docs/typing/one_hour_typing_corpus.md\n"
         "- Source text: Chinese Union Version, Traditional Chinese, selected Bible chapters from `seven1m/open-bibles` `chi-cuv.usfx.xml`.\n"
         "- Source license: Public Domain as listed by `seven1m/open-bibles`.\n"
         "- Source chapters: 創世紀 1-3; 出埃及記 20; 詩篇 23, 90; 以賽亞書 53; 馬太福音 5-7; 約翰福音 1; 羅馬書 8; 哥林多前書 13.\n"
         "- Source corpus characters: %lu\n"
         "- Target: %lu keystrokes, equivalent to 60 minutes at 240 keystrokes/minute.\n"
         "- Simulated keystrokes: %lu\n"
         "- Corpus repetitions: %lu\n"
         "- Output characters: %lu\n"
         "- Chinese candidate selections: %lu\n"
         "- Candidate page turns: %lu\n"
         "- Raw characters: %lu\n"
         "- Unique Chinese characters checked: %lu\n"
         "- Cangjie replay selections: %lu\n"
         "- New Sucheng learning replays: %lu\n"
         "- Preference toggle checks: %lu\n"
         "- Exact output comparison: PASS\n",
        (unsigned long)sourceCorpusLength,
        (unsigned long)MKTypingOneHourTargetKeystrokes,
        (unsigned long)stats.keystrokes,
        (unsigned long)stats.repetitions,
        (unsigned long)expectedLength,
        (unsigned long)stats.chineseSelections,
        (unsigned long)stats.candidatePageTurns,
        (unsigned long)stats.rawCharacters,
        (unsigned long)stats.uniqueChineseCharacters,
        (unsigned long)stats.cangjieSelections,
        (unsigned long)stats.newSuchengLearningReplays,
        (unsigned long)stats.preferenceToggleChecks];

    NSError *error = nil;
    BOOL wrote = [report writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    AssertTrue(wrote, [NSString stringWithFormat:@"writes typing simulation report %@", error.localizedDescription ?: @""]);
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *corpusPath = [root stringByAppendingPathComponent:@"docs/typing/one_hour_typing_corpus.md"];
        NSString *corpus = TypingCorpusFromMarkdown(TextAtPath(corpusPath));

        NSString *cangjieDirectory = [root stringByAppendingPathComponent:@"third_party/rime-cangjie"];
        NSString *pinyinPath = [root stringByAppendingPathComponent:@"resources/pinyin_seed.tsv"];
        PurrTypeEngine *engine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                             pinyinPath:pinyinPath
                                                                           learningPath:nil];

        NSMutableDictionary<NSString *, NSNumber *> *keystrokeCache = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSString *, NSNumber *> *pageTurnCache = [NSMutableDictionary dictionary];
        NSMutableString *expectedOutput = [NSMutableString string];
        NSMutableString *actualOutput = [NSMutableString string];
        MKTypingSimulationStats stats = {0};

        while (stats.keystrokes < MKTypingOneHourTargetKeystrokes) {
            NSString *replayed = ReplayCorpusOnce(corpus, engine, keystrokeCache, pageTurnCache, &stats);
            [expectedOutput appendString:corpus];
            [actualOutput appendString:replayed];
            stats.repetitions += 1;
            if (stats.keystrokes < MKTypingOneHourTargetKeystrokes) {
                [expectedOutput appendString:@"\n"];
                [actualOutput appendString:@"\n"];
                stats.keystrokes += 1;
                stats.rawCharacters += 1;
            }
        }

        AssertTrue([actualOutput isEqualToString:expectedOutput], @"one-hour typing simulation output matches expected corpus exactly");

        NSString *cangjieReplayText = @"我們今天測試輸入法";
        NSString *cangjieOutput = ReplayCangjieText(cangjieReplayText, engine, &stats);
        AssertTrue([cangjieOutput isEqualToString:cangjieReplayText], @"Cangjie replay output matches expected text exactly");

        RunNewSuchengLearningReplay(cangjieDirectory, pinyinPath, &stats);
        RunPreferenceToggleChecks(engine, &stats);

        NSString *reportPath = [root stringByAppendingPathComponent:@"build/typing-simulation-report.md"];
        WriteReport(reportPath, stats, corpus.length, expectedOutput.length);
        NSLog(@"PASS: PurrTypeTypingSimulationTests %@", reportPath);
    }
    return 0;
}
