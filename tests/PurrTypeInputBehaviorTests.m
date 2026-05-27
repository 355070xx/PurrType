#import <Cocoa/Cocoa.h>
#import "../src/PurrTypeInputBehavior.h"
#import "../src/PurrTypePreferencesConstants.h"

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static MKCandidate *Candidate(NSString *text, NSString *code) {
    return [[MKCandidate alloc] initWithText:text code:code source:@"test" weight:100];
}

static MKCandidate *CandidateWithSource(NSString *text, NSString *code, NSString *source) {
    return [[MKCandidate alloc] initWithText:text code:code source:source weight:100];
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSUInteger modeFlags = NSEventModifierFlagControl | NSEventModifierFlagShift;
        AssertTrue([[PurrTypeInputBehavior modeForShortcutKeyCode:18 modifiers:modeFlags] isEqualToString:MKInputModeSucheng], @"Ctrl+Shift+1 selects Sucheng");
        AssertTrue([[PurrTypeInputBehavior modeForShortcutKeyCode:19 modifiers:modeFlags] isEqualToString:MKInputModeSmartSucheng], @"Ctrl+Shift+2 selects New Sucheng");
        AssertTrue([[PurrTypeInputBehavior modeForShortcutKeyCode:20 modifiers:modeFlags] isEqualToString:MKInputModeCangjie], @"Ctrl+Shift+3 selects Cangjie");
        AssertTrue([[PurrTypeInputBehavior modeForShortcutKeyCode:21 modifiers:modeFlags] isEqualToString:MKInputModePinyin], @"Ctrl+Shift+4 selects Pinyin");
        AssertTrue([PurrTypeInputBehavior modeForShortcutKeyCode:23 modifiers:modeFlags] == nil, @"Ctrl+Shift+5 is unassigned after merging Quick Classic into Sucheng");
        AssertTrue([PurrTypeInputBehavior modeForShortcutKeyCode:18 modifiers:(modeFlags | NSEventModifierFlagCommand)] == nil, @"Command blocks mode shortcut");
        AssertTrue([PurrTypeInputBehavior modeForShortcutKeyCode:26 modifiers:modeFlags] == nil, @"unassigned shortcut key does not select a mode");
        NSDictionary<NSString *, NSString *> *customShortcuts = @{
            MKInputModeSucheng: @"ctrl_shift_5",
            MKInputModeSmartSucheng: @"ctrl_shift_6",
            MKInputModeCangjie: @"none",
            MKInputModePinyin: @"ctrl_shift_9"
        };
        AssertTrue([[PurrTypeInputBehavior modeForShortcutKeyCode:23 modifiers:modeFlags shortcutsByMode:customShortcuts] isEqualToString:MKInputModeSucheng], @"custom Ctrl+Shift+5 selects Sucheng");
        AssertTrue([[PurrTypeInputBehavior modeForShortcutKeyCode:22 modifiers:modeFlags shortcutsByMode:customShortcuts] isEqualToString:MKInputModeSmartSucheng], @"custom Ctrl+Shift+6 selects New Sucheng");
        AssertTrue([PurrTypeInputBehavior modeForShortcutKeyCode:20 modifiers:modeFlags shortcutsByMode:customShortcuts] == nil, @"custom None disables Cangjie shortcut");
        AssertTrue([[PurrTypeInputBehavior modeForShortcutKeyCode:25 modifiers:modeFlags shortcutsByMode:customShortcuts] isEqualToString:MKInputModePinyin], @"custom Ctrl+Shift+9 selects Pinyin");

        AssertTrue([PurrTypeInputBehavior isPreferencesShortcutKeyCode:43 modifiers:modeFlags], @"Ctrl+Shift+, opens Preferences");
        AssertTrue(![PurrTypeInputBehavior isPreferencesShortcutKeyCode:43 modifiers:NSEventModifierFlagCommand], @"Cmd+, is left for the Preferences helper app");
        AssertTrue(![PurrTypeInputBehavior isPreferencesShortcutKeyCode:18 modifiers:modeFlags], @"mode shortcuts are not preferences shortcuts");
        AssertTrue([[PurrTypeInputBehavior defaultSwitchInputModeShortcutSpec] isEqualToString:@"keycode:1:42"], @"Switch Input Mode defaults to Control+Backslash");
        AssertTrue([PurrTypeInputBehavior shortcutSpec:@"keycode:1:42" matchesKeyCode:42 modifiers:NSEventModifierFlagControl], @"custom Control+Backslash shortcut matches");
        AssertTrue([[PurrTypeInputBehavior shortcutSpecForKeyCode:42 modifiers:NSEventModifierFlagControl] isEqualToString:@"keycode:1:42"], @"recorder builds generic Control+Backslash shortcut");
        AssertTrue([PurrTypeInputBehavior shortcutSpecForKeyCode:42 modifiers:NSEventModifierFlagCommand] == nil, @"recorder rejects Command shortcuts to preserve app shortcuts");
        AssertTrue([[PurrTypeInputBehavior normalizedSwitchInputModeShortcutSpec:@"invalid"] isEqualToString:@"keycode:1:42"], @"invalid switch-mode shortcut falls back to default");
        AssertTrue([[PurrTypeInputBehavior defaultPrivacyLockShortcutSpec] isEqualToString:@"doubletap:50:500"], @"Privacy Lock defaults to double backtick trigger");
        AssertTrue([PurrTypeInputBehavior isDoubleBacktickShortcutSpec:@"doubletap:50:500"], @"double backtick shortcut is recognized");
        AssertTrue([PurrTypeInputBehavior isDoubleBacktickShortcutSpec:@"double_backtick"], @"legacy double backtick shortcut is recognized");
        AssertTrue([PurrTypeInputBehavior isBacktickKeyCode:50 inputString:@"`" modifiers:0], @"plain backtick key can participate in double-backtick shortcut");
        AssertTrue(![PurrTypeInputBehavior isBacktickKeyCode:50 inputString:@"`" modifiers:NSEventModifierFlagControl], @"modified backtick does not participate in double-backtick shortcut");
        AssertTrue([PurrTypeInputBehavior shortcutSpec:@"ctrl_shift_backtick" matchesKeyCode:50 modifiers:modeFlags], @"Ctrl+Shift+` matches Privacy Lock chord option");
        AssertTrue(![PurrTypeInputBehavior shortcutSpec:@"doubletap:50:500" matchesKeyCode:50 modifiers:modeFlags], @"double backtick is handled as a two-key sequence, not a chord");
        AssertTrue([[PurrTypeInputBehavior normalizedPrivacyLockShortcutSpec:@"keycode:1:0"] isEqualToString:@"keycode:1:0"], @"Privacy Lock accepts custom recorder shortcuts");
        AssertTrue([PurrTypeInputBehavior shortcutSpec:@"ctrl_shift_1" conflictsWithShortcutSpec:@"keycode:5:18"], @"legacy and recorded equivalents conflict");
        AssertTrue([[PurrTypeInputBehavior normalizedModeShortcutSpec:@"invalid" forMode:MKInputModeCangjie] isEqualToString:@"ctrl_shift_3"], @"invalid mode shortcut falls back to the mode default");
        AssertTrue([[PurrTypeInputBehavior normalizedPrivacyLockShortcutSpec:@"invalid"] isEqualToString:@"doubletap:50:500"], @"invalid Privacy Lock shortcut falls back to default");
        AssertTrue([[PurrTypeInputBehavior normalizedPrivacyLockShortcutSpec:@"double_backtick"] isEqualToString:@"doubletap:50:500"], @"legacy Privacy Lock shortcut migrates to structured trigger");
        AssertTrue([PurrTypeInputBehavior privacyLockShouldPauseLearningContextForMode:MKInputModeSmartSucheng enabled:YES],
                   @"Privacy Lock pauses only New Sucheng learning context");
        AssertTrue(![PurrTypeInputBehavior privacyLockShouldPauseLearningContextForMode:MKInputModeSucheng enabled:YES],
                   @"Privacy Lock keeps Classic Sucheng fixed associations available");
        AssertTrue(![PurrTypeInputBehavior privacyLockShouldPauseLearningContextForMode:MKInputModeCangjie enabled:YES],
                   @"Privacy Lock keeps Cangjie fixed associations available");
        AssertTrue(![PurrTypeInputBehavior privacyLockShouldPauseLearningContextForMode:MKInputModePinyin enabled:YES],
                   @"Privacy Lock keeps Pinyin fixed associations available");
        AssertTrue(![PurrTypeInputBehavior privacyLockShouldPauseLearningContextForMode:MKInputModeSmartSucheng enabled:NO],
                   @"disabled Privacy Lock does not pause New Sucheng learning context");

        NSArray<NSString *> *enabledModes = @[MKInputModeSucheng, MKInputModeCangjie];
        AssertTrue([[PurrTypeInputBehavior normalizedEnabledInputModes:@[@"sucheng", @"newSucheng", @"pinyin"]] isEqualToArray:@[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModePinyin]],
                   @"enabled mode aliases normalize to engine mode identifiers");
        AssertTrue([[PurrTypeInputBehavior firstEnabledInputModeInModes:enabledModes] isEqualToString:MKInputModeSucheng], @"first enabled mode follows global cycle order");
        AssertTrue([PurrTypeInputBehavior inputMode:MKInputModeCangjie isEnabledInModes:enabledModes], @"enabled mode helper accepts configured mode");
        AssertTrue(![PurrTypeInputBehavior inputMode:MKInputModePinyin isEnabledInModes:enabledModes], @"enabled mode helper rejects disabled mode");
        AssertTrue([PurrTypeInputBehavior modeForShortcutKeyCode:21
                                                       modifiers:modeFlags
                                                 shortcutsByMode:@{
            MKInputModeSucheng: @"ctrl_shift_1",
            MKInputModeSmartSucheng: @"ctrl_shift_2",
            MKInputModeCangjie: @"ctrl_shift_3",
            MKInputModePinyin: @"ctrl_shift_4"
        }
                                                    enabledModes:enabledModes] == nil,
                   @"disabled mode shortcut does not select that mode");

        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:49 modifiers:0 candidateCount:10 spacePagingEnabled:YES] == 1, @"Space pages forward when enabled");
        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:49 modifiers:0 candidateCount:10 spacePagingEnabled:NO] == 0, @"Space does not page when disabled");
        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:49 modifiers:0 candidateCount:6 spacePagingEnabled:YES candidatePageSize:5] == 1, @"Space pages forward with compact five-candidate pages");
        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:48 modifiers:0 candidateCount:10 spacePagingEnabled:YES] == 1, @"Tab pages forward");
        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:48 modifiers:NSEventModifierFlagShift candidateCount:10 spacePagingEnabled:YES] == -1, @"Shift+Tab pages back");
        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:124 modifiers:0 candidateCount:10 spacePagingEnabled:YES] == 1, @"Right Arrow pages forward");
        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:123 modifiers:0 candidateCount:10 spacePagingEnabled:YES] == -1, @"Left Arrow pages back");
        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForKeyCode:49 modifiers:0 candidateCount:9 spacePagingEnabled:YES] == 0, @"single candidate page does not page");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForKeyCode:125 modifiers:0 candidateCount:3] == 1, @"Down Arrow selects next visible candidate");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForKeyCode:126 modifiers:0 candidateCount:3] == -1, @"Up Arrow selects previous visible candidate");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForKeyCode:125 modifiers:NSEventModifierFlagCommand candidateCount:3] == 0, @"modified Down Arrow is left to the app");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForKeyCode:125 modifiers:0 candidateCount:0] == 0, @"candidate selection keys require visible candidates");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForSelector:@selector(moveDown:) candidateCount:3] == 1, @"moveDown selector selects next visible candidate");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForSelector:@selector(moveUp:) candidateCount:3] == -1, @"moveUp selector selects previous visible candidate");
        AssertTrue([PurrTypeInputBehavior candidateSelectionIndexFromIndex:0 offset:-1 candidateCount:3] == 0, @"candidate selection clamps at the first row");
        AssertTrue([PurrTypeInputBehavior candidateSelectionIndexFromIndex:0 offset:1 candidateCount:3] == 1, @"candidate selection advances by one row");
        AssertTrue([PurrTypeInputBehavior candidateSelectionIndexFromIndex:2 offset:1 candidateCount:3] == 2, @"candidate selection clamps at the last row");
        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForSelector:@selector(moveRight:) candidateCount:10 candidatePageSize:9] == 1, @"moveRight selector pages forward");
        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForSelector:@selector(moveLeft:) candidateCount:10 candidatePageSize:9] == -1, @"moveLeft selector pages back");
        AssertTrue([PurrTypeInputBehavior candidatePageOffsetForSelector:@selector(moveRight:) candidateCount:5 candidatePageSize:5] == 0, @"single compact selector page does not page");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForKeyCode:125 modifiers:0 candidateCount:5] == 1,
                   @"down arrow selects the next Pinyin candidate");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForKeyCode:126 modifiers:0 candidateCount:5] == -1,
                   @"up arrow selects the previous Pinyin candidate");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForKeyCode:125 modifiers:NSEventModifierFlagCommand candidateCount:5] == 0,
                   @"modified arrow keys do not change Pinyin candidate selection");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForSelector:@selector(moveDown:) candidateCount:5] == 1,
                   @"moveDown selector selects the next Pinyin candidate");
        AssertTrue([PurrTypeInputBehavior candidateSelectionOffsetForSelector:@selector(moveUp:) candidateCount:5] == -1,
                   @"moveUp selector selects the previous Pinyin candidate");
        AssertTrue([PurrTypeInputBehavior candidateSelectionIndexFromIndex:1 offset:1 candidateCount:3] == 2,
                   @"Pinyin selected candidate advances by offset");
        AssertTrue([PurrTypeInputBehavior candidateSelectionIndexFromIndex:2 offset:1 candidateCount:3] == 2,
                   @"Pinyin selected candidate clamps at the last candidate");
        AssertTrue([PurrTypeInputBehavior candidateSelectionIndexFromIndex:0 offset:-1 candidateCount:3] == 0,
                   @"Pinyin selected candidate clamps at the first candidate");

        NSMutableArray<MKCandidate *> *pool = [NSMutableArray array];
        for (NSUInteger index = 1; index <= 12; index += 1) {
            [pool addObject:Candidate([NSString stringWithFormat:@"字%lu", (unsigned long)index], @"code")];
        }
        NSUInteger pageIndex = 0;
        NSArray<MKCandidate *> *firstPage = [PurrTypeInputBehavior candidatePageFromPool:pool pageIndex:&pageIndex];
        AssertTrue(firstPage.count == 9 && pageIndex == 0, @"first candidate page has nine candidates");
        AssertTrue([firstPage[0].text isEqualToString:@"字1"] && [firstPage[8].text isEqualToString:@"字9"], @"first page keeps candidate order");
        pageIndex = 0;
        NSArray<MKCandidate *> *compactFirstPage = [PurrTypeInputBehavior candidatePageFromPool:pool pageIndex:&pageIndex pageSize:5];
        AssertTrue(compactFirstPage.count == 5 && pageIndex == 0, @"compact candidate page has five candidates");
        AssertTrue([compactFirstPage[0].text isEqualToString:@"字1"] && [compactFirstPage[4].text isEqualToString:@"字5"], @"compact page keeps candidate order");
        pageIndex = 99;
        NSArray<MKCandidate *> *lastPage = [PurrTypeInputBehavior candidatePageFromPool:pool pageIndex:&pageIndex];
        AssertTrue(lastPage.count == 3 && pageIndex == 1, @"out-of-range page clamps to last page");
        AssertTrue([lastPage[0].text isEqualToString:@"字10"] && [lastPage[2].text isEqualToString:@"字12"], @"last page slices remaining candidates");

        NSArray<NSString *> *displayTexts = [PurrTypeInputBehavior displayTextsForCandidates:[pool subarrayWithRange:NSMakeRange(0, 2)]
                                                                                         buffer:@"d"
                                                                           rawEnglishModeActive:NO
                                                                          associationModeActive:NO
                                                                    rawEnglishCandidateEnabled:YES];
        AssertTrue(displayTexts.count == 3, @"display list includes raw English option");
        AssertTrue([displayTexts[0] isEqualToString:@"0 d"], @"0 commits raw English buffer before Chinese candidates");
        AssertTrue([displayTexts[1] isEqualToString:@"1 字1"], @"first candidate has numeric label");
        AssertTrue([displayTexts[2] isEqualToString:@"2 字2"], @"second candidate has numeric label");
        NSArray<NSString *> *trailingRawDisplayTexts =
            [PurrTypeInputBehavior displayTextsForCandidates:[pool subarrayWithRange:NSMakeRange(0, 2)]
                                                      buffer:@"d"
                                        rawEnglishModeActive:NO
                                       associationModeActive:NO
                                 rawEnglishCandidateEnabled:YES
                                rawEnglishCandidatePosition:MKRawEnglishCandidatePositionTrailing];
        AssertTrue(trailingRawDisplayTexts.count == 3, @"trailing raw-English display still includes every option");
        AssertTrue([trailingRawDisplayTexts[0] isEqualToString:@"1 字1"] &&
                   [trailingRawDisplayTexts[1] isEqualToString:@"2 字2"] &&
                   [trailingRawDisplayTexts[2] isEqualToString:@"0 d"],
                   @"0 raw-English candidate can be shown after Chinese candidates");
        AssertTrue(![PurrTypeInputBehavior shouldShowRawEnglishCandidateForBuffer:@"d1"
                                                              rawEnglishModeActive:NO
                                                              associationModeActive:NO
                                                         rawEnglishCandidateEnabled:YES
                                                                     candidateCount:2], @"mixed alphanumeric buffers do not show raw-English candidate");
        AssertTrue(![PurrTypeInputBehavior shouldShowRawEnglishCandidateForBuffer:@"d"
                                                              rawEnglishModeActive:YES
                                                              associationModeActive:NO
                                                         rawEnglishCandidateEnabled:YES
                                                                     candidateCount:2], @"raw English mode suppresses 0 candidate");
        AssertTrue(![PurrTypeInputBehavior shouldShowRawEnglishCandidateForBuffer:@"d"
                                                              rawEnglishModeActive:NO
                                                              associationModeActive:YES
                                                         rawEnglishCandidateEnabled:YES
                                                                     candidateCount:2], @"association mode suppresses 0 candidate");
        AssertTrue(![PurrTypeInputBehavior shouldShowRawEnglishCandidateForBuffer:@"d"
                                                              rawEnglishModeActive:NO
                                                              associationModeActive:NO
                                                         rawEnglishCandidateEnabled:NO
                                                                     candidateCount:2], @"preference toggle suppresses 0 candidate");
        NSArray<MKCandidate *> *quickPhraseCandidates = @[ CandidateWithSource(@"founder@example.com", @";email", @"quickPhrase") ];
        NSArray<NSString *> *quickPhraseDisplayTexts =
            [PurrTypeInputBehavior displayTextsForCandidates:quickPhraseCandidates
                                                      buffer:@";email"
                                        rawEnglishModeActive:YES
                                       associationModeActive:NO
                                 rawEnglishCandidateEnabled:YES];
        AssertTrue(quickPhraseDisplayTexts.count == 1 &&
                   [quickPhraseDisplayTexts[0] isEqualToString:@"1 founder@example.com"],
                   @"quick phrase candidate display includes the replacement text");

        NSArray<MKCandidate *> *spellingCandidates = @[
            CandidateWithSource(@"spelling", @"speling", @"spelling"),
            CandidateWithSource(@"spieling", @"speling", @"spelling"),
            CandidateWithSource(@"sperling", @"speling", @"spelling")
        ];
        NSArray<MKCandidate *> *compactMerged =
            [PurrTypeInputBehavior candidatePoolByMergingPrimaryCandidates:[pool subarrayWithRange:NSMakeRange(0, 5)]
                                                        spellingCandidates:spellingCandidates
                                                                  pageSize:5];
        AssertTrue(compactMerged.count == 7, @"compact merge keeps all primary candidates and two spelling suggestions");
        AssertTrue([compactMerged[0].text isEqualToString:@"字1"] &&
                   [compactMerged[2].text isEqualToString:@"字3"] &&
                   [compactMerged[3].text isEqualToString:@"spelling"] &&
                   [compactMerged[4].text isEqualToString:@"spieling"] &&
                   [compactMerged[5].text isEqualToString:@"字4"],
                   @"compact merge makes spelling visible without replacing the first primary candidate");
        NSArray<MKCandidate *> *wideMerged =
            [PurrTypeInputBehavior candidatePoolByMergingPrimaryCandidates:[pool subarrayWithRange:NSMakeRange(0, 8)]
                                                        spellingCandidates:spellingCandidates
                                                                  pageSize:9];
        AssertTrue(wideMerged.count == 11, @"wide merge keeps all primary candidates and three spelling suggestions");
        AssertTrue([wideMerged[5].text isEqualToString:@"字6"] &&
                   [wideMerged[6].text isEqualToString:@"spelling"] &&
                   [wideMerged[8].text isEqualToString:@"sperling"] &&
                   [wideMerged[9].text isEqualToString:@"字7"],
                   @"wide merge reserves three first-page slots for spelling suggestions");
        AssertTrue([PurrTypeInputBehavior spellingSuggestionLimitForCandidatePageSize:5] == 2,
                   @"compact candidate pages reserve two spelling suggestions");
        AssertTrue([PurrTypeInputBehavior spellingSuggestionLimitForCandidatePageSize:9] == 3,
                   @"wide candidate pages reserve three spelling suggestions");
        AssertTrue([PurrTypeInputBehavior candidatePoolByMergingPrimaryCandidates:@[]
                                                              spellingCandidates:spellingCandidates
                                                                        pageSize:5].count == 3,
                   @"spelling-only merge keeps spelling candidates available");

        NSArray<NSString *> *commaCandidates = [PurrTypeInputBehavior punctuationCandidateDisplayTextsForString:@","];
        AssertTrue(commaCandidates.count == 3, @"comma opens half-width and Chinese punctuation candidates");
        AssertTrue([commaCandidates[0] isEqualToString:@"1 ,"], @"comma keeps half-width option");
        AssertTrue([commaCandidates[1] isEqualToString:@"2 ，"], @"comma includes full-width comma");
        AssertTrue([commaCandidates[2] isEqualToString:@"3 、"], @"comma includes ideographic comma");
        NSArray<NSString *> *periodCandidates = [PurrTypeInputBehavior punctuationCandidateDisplayTextsForString:@"."];
        AssertTrue(periodCandidates.count == 5, @"period opens half-width and open-table punctuation candidates");
        AssertTrue([periodCandidates[1] isEqualToString:@"2 。"], @"period includes Chinese full stop");
        AssertTrue([periodCandidates[4] isEqualToString:@"5 …"], @"period includes ellipsis");
        NSArray<NSString *> *quoteCandidates = [PurrTypeInputBehavior punctuationCandidateDisplayTextsForString:@"\""];
        AssertTrue(quoteCandidates.count == 5, @"double quote opens open-table quote candidates");
        AssertTrue([quoteCandidates[0] isEqualToString:@"1 \""], @"double quote keeps half-width option");
        AssertTrue([quoteCandidates[1] isEqualToString:@"2 “"], @"double quote includes opening quote");
        AssertTrue([quoteCandidates[4] isEqualToString:@"5 〞"], @"double quote includes corner quote mark");
        NSArray<NSString *> *leftBracketCandidates = [PurrTypeInputBehavior punctuationCandidateDisplayTextsForString:@"["];
        AssertTrue(leftBracketCandidates.count == 6, @"left bracket opens bracket and book-title candidates");
        AssertTrue([leftBracketCandidates[1] isEqualToString:@"2 「"], @"left bracket includes opening corner bracket");
        AssertTrue([leftBracketCandidates[3] isEqualToString:@"4 《"], @"left bracket includes book-title bracket");
        NSArray<NSString *> *asteriskCandidates = [PurrTypeInputBehavior punctuationCandidateDisplayTextsForString:@"*"];
        AssertTrue(asteriskCandidates.count == 5, @"asterisk opens operator and reference mark candidates");
        AssertTrue([asteriskCandidates[1] isEqualToString:@"2 ＊"], @"asterisk includes full-width asterisk");
        AssertTrue([asteriskCandidates[4] isEqualToString:@"5 §"], @"asterisk includes section mark");
        NSArray<NSString *> *underscoreCandidates = [PurrTypeInputBehavior punctuationCandidateDisplayTextsForString:@"_"];
        AssertTrue(underscoreCandidates.count == 6, @"underscore opens dash and line candidates");
        AssertTrue([underscoreCandidates[2] isEqualToString:@"3 ＿"], @"underscore includes full-width underscore");
        AssertTrue([underscoreCandidates[5] isEqualToString:@"6 —"], @"underscore includes em dash");
        NSArray<NSString *> *atCandidates = [PurrTypeInputBehavior punctuationCandidateDisplayTextsForString:@"@"];
        AssertTrue(atCandidates.count == 2, @"at sign opens half-width and full-width candidates");
        AssertTrue([atCandidates[1] isEqualToString:@"2 ＠"], @"at sign includes full-width at sign");
        AssertTrue([[PurrTypeInputBehavior punctuationTextForDisplayText:@"2 ，"] isEqualToString:@"，"], @"punctuation display text maps back to committed text");
        AssertTrue([[PurrTypeInputBehavior punctuationTextForDisplayText:@"5 §"] isEqualToString:@"§"], @"symbol display text maps back to committed text");
        AssertTrue([PurrTypeInputBehavior punctuationTextForDisplayText:@"0 abc"] == nil, @"raw English display text is not punctuation");
        AssertTrue([PurrTypeInputBehavior shouldAutoCommitDefaultPunctuationForInputString:@","
                                                                                      keyCode:43
                                                                               candidateCount:3],
                   @"typing another punctuation key auto-commits the pending default punctuation");
        AssertTrue([PurrTypeInputBehavior shouldAutoCommitDefaultPunctuationForInputString:@"a"
                                                                                      keyCode:0
                                                                               candidateCount:3],
                   @"typing a non-selection key auto-commits the pending default punctuation");
        AssertTrue(![PurrTypeInputBehavior shouldAutoCommitDefaultPunctuationForInputString:@"2"
                                                                                       keyCode:19
                                                                                candidateCount:3],
                   @"valid number keys still select alternate punctuation candidates");
        AssertTrue([PurrTypeInputBehavior shouldAutoCommitDefaultPunctuationForInputString:@"9"
                                                                                      keyCode:25
                                                                               candidateCount:3],
                   @"out-of-range number keys commit default punctuation and continue as literal input");
        AssertTrue(![PurrTypeInputBehavior shouldAutoCommitDefaultPunctuationForInputString:@"\r"
                                                                                       keyCode:36
                                                                                candidateCount:3],
                   @"Return keeps the existing immediate default commit path");
        AssertTrue(![PurrTypeInputBehavior shouldAutoCommitDefaultPunctuationForInputString:@""
                                                                                       keyCode:53
                                                                                candidateCount:3],
                   @"Escape keeps cancelling pending punctuation");

        AssertTrue([PurrTypeInputBehavior isShiftOnlyLetterInputWithModifiers:NSEventModifierFlagShift], @"Shift-only input enters uppercase English");
        AssertTrue(![PurrTypeInputBehavior isShiftOnlyLetterInputWithModifiers:(NSEventModifierFlagShift | NSEventModifierFlagControl)], @"Control+Shift is not uppercase English");
        AssertTrue([PurrTypeInputBehavior isAsciiCodeString:@"ABCxyz"], @"ASCII letter buffer is code-like");
        AssertTrue(![PurrTypeInputBehavior isAsciiCodeString:@""], @"empty string is not code-like");
        AssertTrue(![PurrTypeInputBehavior isAsciiCodeString:@"abc1"], @"numbers are not code-like");

        NSLog(@"PASS: PurrTypeInputBehaviorTests");
    }
    return 0;
}
