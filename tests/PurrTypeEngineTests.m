#import <Foundation/Foundation.h>
#import "../src/PurrTypeEngine.h"

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static BOOL CandidatesContainText(NSArray<MKCandidate *> *candidates, NSString *text) {
    for (MKCandidate *candidate in candidates) {
        if ([candidate.text isEqualToString:text]) {
            return YES;
        }
    }
    return NO;
}

static BOOL FirstCandidateIsText(NSArray<MKCandidate *> *candidates, NSString *text) {
    return candidates.count > 0 && [candidates.firstObject.text isEqualToString:text];
}

static MKCandidate *CandidateWithText(NSArray<MKCandidate *> *candidates, NSString *text) {
    for (MKCandidate *candidate in candidates) {
        if ([candidate.text isEqualToString:text]) {
            return candidate;
        }
    }
    return nil;
}

static NSArray<NSString *> *CandidateTexts(NSArray<MKCandidate *> *candidates) {
    NSMutableArray<NSString *> *texts = [NSMutableArray arrayWithCapacity:candidates.count];
    for (MKCandidate *candidate in candidates) {
        [texts addObject:candidate.text ?: @""];
    }
    return texts;
}

static BOOL CandidateTextsHavePrefix(NSArray<MKCandidate *> *candidates, NSArray<NSString *> *expectedTexts) {
    if (candidates.count < expectedTexts.count) {
        return NO;
    }

    for (NSUInteger index = 0; index < expectedTexts.count; index += 1) {
        if (![candidates[index].text isEqualToString:expectedTexts[index]]) {
            return NO;
        }
    }

    return YES;
}

static BOOL CandidateTextAtPosition(NSArray<MKCandidate *> *candidates, NSUInteger oneBasedPosition, NSString *expectedText) {
    if (oneBasedPosition == 0 || candidates.count < oneBasedPosition) {
        return NO;
    }
    return [candidates[oneBasedPosition - 1].text isEqualToString:expectedText];
}

static BOOL TextArrayEquals(NSArray<NSString *> *left, NSArray<NSString *> *right) {
    if (left.count != right.count) {
        return NO;
    }

    for (NSUInteger index = 0; index < left.count; index += 1) {
        if (![left[index] isEqualToString:right[index]]) {
            return NO;
        }
    }
    return YES;
}

static void ValidateSuchengFirstPageSnapshot(PurrTypeEngine *engine, NSString *path) {
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    AssertTrue(contents.length > 0, @"loads Sucheng first-page snapshot");

    NSUInteger checkedCodes = 0;
    BOOL checkedHi = NO;
    BOOL checkedOr = NO;
    NSArray<NSString *> *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if (line.length == 0 || [line hasPrefix:@"#"]) {
            continue;
        }

        NSArray<NSString *> *columns = [line componentsSeparatedByString:@"\t"];
        AssertTrue(columns.count >= 2, [NSString stringWithFormat:@"Sucheng snapshot row has candidates: %@", line]);

        NSString *code = columns.firstObject;
        NSArray<NSString *> *expectedTexts = [columns subarrayWithRange:NSMakeRange(1, columns.count - 1)];
        NSArray<MKCandidate *> *actualCandidates = [engine candidatesForInput:code
                                                                        limit:expectedTexts.count
                                                                         mode:MKInputModeSucheng];
        AssertTrue(actualCandidates.count == expectedTexts.count,
                   [NSString stringWithFormat:@"Sucheng %@ first-page count stays locked", code]);
        AssertTrue(CandidateTextsHavePrefix(actualCandidates, expectedTexts),
                   [NSString stringWithFormat:@"Sucheng %@ first-page order stays locked", code]);
        if ([code isEqualToString:@"hi"]) {
            checkedHi = TextArrayEquals(expectedTexts, @[@"凡", @"么", @"丟", @"夙", @"舟", @"卵", @"我", @"私", @"的"]);
        } else if ([code isEqualToString:@"or"]) {
            checkedOr = TextArrayEquals(expectedTexts, @[@"合", @"何", @"估", @"佑", @"伽", @"伺", @"佔", @"佝", @"含"]);
        }
        checkedCodes += 1;
    }

    AssertTrue(checkedCodes >= 650, @"Sucheng snapshot locks all populated alphabetic one/two-key codes");
    AssertTrue(checkedHi, @"Sucheng snapshot keeps verified hi first page");
    AssertTrue(checkedOr, @"Sucheng snapshot keeps verified or first page");
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *cangjieDirectory = [root stringByAppendingPathComponent:@"third_party/rime-cangjie"];
        NSString *pinyinPath = [root stringByAppendingPathComponent:@"resources/pinyin_seed.tsv"];
        NSString *suchengSnapshotPath = [root stringByAppendingPathComponent:@"resources/sucheng_first_pages.tsv"];
        PurrTypeEngine *engine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory pinyinPath:pinyinPath];

        AssertTrue(engine.quickEntryCount > 10000, @"loads bundled Quick Classic Sucheng table during cold start");
        AssertTrue(engine.cangjieEntryCount == 0, @"defers Rime Cangjie dictionaries until Cangjie mode is used");
        AssertTrue(engine.pinyinEntryCount == 0, @"defers expanded Pinyin dictionaries until Pinyin mode is used");

        ValidateSuchengFirstPageSnapshot(engine, suchengSnapshotPath);

        AssertTrue(CandidatesContainText([engine candidatesForInput:@"rsya" limit:200 mode:MKInputModeCangjie], @"㗩"), @"Cangjie includes HKSCS 㗩 overlay");
        AssertTrue(engine.cangjieEntryCount > 70000, @"loads Rime Cangjie base and extended dictionaries on first Cangjie lookup");
        AssertTrue(engine.pinyinEntryCount == 0, @"keeps Pinyin dictionaries deferred after Cangjie lookup");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"ra" limit:2000 mode:MKInputModeSucheng], @"㗩"), @"Sucheng derives HKSCS 㗩 from official Cangjie code");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"rmnd" limit:200 mode:MKInputModeCangjie], @"𭉝"), @"Cangjie includes non-BMP HKSCS 𭉝 overlay");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"rd" limit:2000 mode:MKInputModeSucheng], @"𭉝"), @"Sucheng derives non-BMP HKSCS 𭉝 from official Cangjie code");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"royv" limit:200 mode:MKInputModeCangjie], @"𠵱"), @"Cangjie keeps displayable non-BMP Hong Kong characters");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"rv" limit:2000 mode:MKInputModeSucheng], @"𠵱"), @"Sucheng HKSCS overlay fills missing non-BMP Hong Kong characters");
        AssertTrue([[engine preferredSuchengCodeForText:@"𠵱"] isEqualToString:@"rv"], @"Sucheng reverse lookup indexes HKSCS overlay");

        AssertTrue(CandidatesContainText([engine candidatesForInput:@"hqi" limit:9 mode:MKInputModeCangjie], @"我"), @"Cangjie hqi returns 我");
        AssertTrue([engine candidatesForInput:@"hqi" limit:9 mode:MKInputModeCangjie].count > 1, @"Cangjie hqi exposes same-code candidates");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"onf" limit:9 mode:MKInputModeCangjie], @"你"), @"Cangjie onf returns 你");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"mks" limit:9 mode:MKInputModeCangjie], @"功"), @"Cangjie mks prioritizes 功");
        AssertTrue(!CandidatesContainText([engine candidatesForInput:@"ms" limit:30 mode:MKInputModeCangjie], @"功"), @"Cangjie ms does not include Quick-only 功");
        AssertTrue(CandidateTextsHavePrefix([engine candidatesForInput:@"ms" limit:9 mode:MKInputModeSucheng], @[@"丐", @"功", @"巧", @"勁", @"砟", @"雩", @"磅", @"勵", @"霧"]), @"Sucheng ms follows bundled Quick Classic order");
        AssertTrue([engine candidatesForInput:@"ms" limit:200 mode:MKInputModeSucheng].count > 9, @"Sucheng ms exposes a pageable Quick Classic candidate bucket");
        AssertTrue(!CandidatesContainText([engine candidatesForInput:@"mks" limit:30 mode:MKInputModeCangjie], @"历"), @"Cangjie candidates filter Simplified-only characters");
        AssertTrue(!CandidatesContainText([engine candidatesForInput:@"de" limit:30 mode:MKInputModeCangjie], @"权"), @"Cangjie de filters Simplified-only 权");
        NSArray<NSArray<NSString *> *> *traditionalCompatibilityFixtures = @[
            @[@"tu", @"着"], @[@"en", @"沉"], @[@"hs", @"彷"], @[@"to", @"羡"],
            @[@"yj", @"斗"], @[@"or", @"舍"], @[@"mi", @"云"], @[@"pm", @"恒"],
            @[@"mj", @"干"], @[@"hm", @"征"], @[@"yr", @"占"], @[@"ni", @"虱"],
            @[@"dm", @"杠"], @[@"dj", @"杆"], @[@"oy", @"仆"], @[@"eb", @"漓"],
            @[@"qg", @"挂"], @[@"qu", @"挽"], @[@"et", @"泄"], @[@"hr", @"后"],
            @[@"rb", @"踊"], @[@"md", @"于"], @[@"km", @"弑"]
        ];
        for (NSArray<NSString *> *fixture in traditionalCompatibilityFixtures) {
            AssertTrue(CandidatesContainText([engine candidatesForInput:fixture[0] limit:1000 mode:MKInputModeSucheng], fixture[1]),
                       [NSString stringWithFormat:@"Sucheng keeps CUV Traditional compatibility character %@", fixture[1]]);
            AssertTrue([[engine preferredSuchengCodeForText:fixture[1]] isEqualToString:fixture[0]],
                       [NSString stringWithFormat:@"Sucheng reverse lookup indexes CUV Traditional compatibility character %@", fixture[1]]);
        }
        NSArray<MKCandidate *> *suchengHi = [engine candidatesForInput:@"hi" limit:9 mode:MKInputModeSucheng];
        AssertTrue(CandidateTextsHavePrefix(suchengHi, @[@"凡", @"么", @"丟", @"夙", @"舟", @"卵", @"我", @"私", @"的"]), @"Sucheng hi uses verified Quick Classic first-page order");
        AssertTrue(!CandidatesContainText(suchengHi, @"䇝"), @"Sucheng hi does not place rare extension characters on the first page");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"hi" limit:30 mode:MKInputModeSucheng], 7, @"我"), @"Sucheng keeps verified hi 我 at page 1 slot 7");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"hi" limit:30 mode:MKInputModeSucheng], 16, @"得"), @"Sucheng keeps verified hi 得 at page 2 slot 7");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"hi" limit:30 mode:MKInputModeSucheng], 19, @"等"), @"Sucheng keeps verified hi 等 at page 3 slot 1");
        AssertTrue(CandidateTextsHavePrefix([engine candidatesForInput:@"bs" limit:9 mode:MKInputModeSucheng], @[@"凸", @"肋", @"助", @"肪", @"胯", @"勝", @"膀", @"贓", @"臟"]), @"Sucheng bs uses Quick Classic ordering");
        AssertTrue(CandidateTextsHavePrefix([engine candidatesForInput:@"aa" limit:9 mode:MKInputModeSucheng], @[@"昌", @"晶", @"暑", @"間", @"暗", @"曙", @"昍", @"暙", @"闍"]), @"Sucheng aa uses Quick Classic ordering");
        AssertTrue(CandidateTextsHavePrefix([engine candidatesForInput:@"bo" limit:9 mode:MKInputModeSucheng], @[@"冢", @"眨", @"眺", @"豚", @"腴", @"貶", @"睫", @"睞", @"賅"]), @"Sucheng bo uses Quick Classic first-page candidates");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"or" limit:30 mode:MKInputModeSucheng], 10, @"知"), @"Sucheng keeps verified or 知 at page 2 slot 1");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"or" limit:30 mode:MKInputModeSucheng], 20, @"個"), @"Sucheng keeps verified or 個 at page 3 slot 2");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"rr" limit:9 mode:MKInputModeSucheng], 9, @"唔"), @"Sucheng keeps verified rr 唔 at page 1 slot 9");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"yr" limit:30 mode:MKInputModeSucheng], 14, @"這"), @"Sucheng keeps verified yr 這 at page 2 slot 5");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"yr" limit:30 mode:MKInputModeSucheng], 24, @"話"), @"Sucheng keeps verified yr 話 at page 3 slot 6");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"of" limit:9 mode:MKInputModeSucheng], 2, @"你"), @"Sucheng keeps verified of 你 at page 1 slot 2");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"di" limit:20 mode:MKInputModeSucheng], 12, @"樹"), @"Sucheng keeps verified di 樹 at page 2 slot 3");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"ho" limit:9 mode:MKInputModeSucheng], 4, @"失"), @"Sucheng keeps verified ho 失 at page 1 slot 4");
        AssertTrue(CandidateTextAtPosition([engine candidatesForInput:@"ho" limit:9 mode:MKInputModeSucheng], 5, @"瓜"), @"Sucheng keeps verified ho 瓜 at page 1 slot 5");
        AssertTrue(CandidateTextsHavePrefix([engine candidatesForInput:@"de" limit:3 mode:MKInputModeSucheng], @[@"皮", @"枝", @"板"]), @"Sucheng de follows Quick Classic table order");
        AssertTrue(CandidateTextsHavePrefix([engine candidatesForInput:@"ma" limit:9 mode:MKInputModeSucheng], @[@"百", @"珀", @"厝", @"晉", @"殉", @"豬", @"醋", @"曆", @"珣"]), @"Sucheng ma follows Quick Classic table order");
        AssertTrue(CandidateTextsHavePrefix([engine candidatesForInput:@"hi" limit:9 mode:MKInputModeSmartSucheng], @[@"凡", @"么", @"丟", @"夙", @"舟", @"卵", @"我", @"私", @"的"]), @"New Sucheng starts from the same fixed Sucheng order before learning");
        AssertTrue([engine candidatesForInput:@"hionaomjoo" limit:9 mode:MKInputModeSucheng].count == 0, @"Sucheng does not use long-code phrase candidates");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"hionaomjoo" limit:9 mode:MKInputModeSmartSucheng], @"我們是一家人"), @"New Sucheng phrase seed composes hionaomjoo");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"hion" limit:9 mode:MKInputModeSmartSucheng], @"我們"), @"New Sucheng phrase seed composes hion");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"jnohei" limit:9 mode:MKInputModeSmartSucheng], @"輸入法"), @"New Sucheng phrase seed composes jnohei");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"qnjd" limit:9 mode:MKInputModeSmartSucheng], @"打字"), @"New Sucheng phrase seed composes qnjd");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"mubw" limit:9 mode:MKInputModeSmartSucheng], @"電腦"), @"New Sucheng phrase seed composes mubw");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"atvr" limit:9 mode:MKInputModeSmartSucheng], @"開始"), @"New Sucheng phrase seed composes atvr");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"aiaa" limit:9 mode:MKInputModeSmartSucheng], @"時間"), @"New Sucheng phrase seed composes aiaa");
        AssertTrue([engine candidatesForInput:@"lykjnohei" limit:9 mode:MKInputModeSucheng].count == 0, @"Sucheng does not use auto smart phrase seeds");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"lykjnohei" limit:9 mode:MKInputModeSmartSucheng], @"中文輸入法"), @"New Sucheng auto phrase seed composes 中文輸入法");
        AssertTrue([engine hasCandidatesOrPrefixesForInput:@"lykjnohe" mode:MKInputModeSmartSucheng], @"New Sucheng auto phrase seed keeps prefixes composing");
        AssertTrue([engine candidatesForInput:@"onaatvr" limit:9 mode:MKInputModeSucheng].count == 0, @"Sucheng does not use expanded corpus smart phrase seeds");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"onaatvr" limit:9 mode:MKInputModeSmartSucheng], @"今日開始"), @"New Sucheng expanded corpus composes 今日開始");
        AssertTrue([engine hasCandidatesOrPrefixesForInput:@"hionaomjo" mode:MKInputModeSmartSucheng], @"New Sucheng keeps long phrase prefixes composing");
        AssertTrue(![engine isLikelyRawToken:@"hionaomjoo" mode:MKInputModeSmartSucheng], @"New Sucheng phrase stream is not treated as raw English");
        AssertTrue(!CandidatesContainText([engine candidatesForInput:@"hionao" limit:200 mode:MKInputModeSucheng], @"我們是"), @"Sucheng does not generate smart phrases");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"hionao" limit:9 mode:MKInputModeSmartSucheng], @"我們是"), @"New Sucheng generated phrase ranking composes 我們是");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"ni" limit:9 mode:MKInputModePinyin], @"你"), @"Pinyin ni returns 你");
        AssertTrue([engine hasCandidatesOrPrefixesForInput:@"nih" mode:MKInputModePinyin], @"Pinyin keeps composing after a complete syllable plus next-syllable prefix");
        AssertTrue([engine hasCandidatesOrPrefixesForInput:@"niha" mode:MKInputModePinyin], @"Pinyin keeps composing while the next syllable is still incomplete");
        AssertTrue(![engine prefersRawEnglishForInput:@"nih" mode:MKInputModePinyin], @"Pinyin segmented prefixes are not treated as raw English");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"nihao" limit:9 mode:MKInputModePinyin], @"你好"), @"Pinyin composes continuous multi-syllable input nihao into 你好");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"woshi" limit:9 mode:MKInputModePinyin], @"我是"), @"Pinyin composes continuous multi-syllable input woshi into 我是");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"womenshi" limit:9 mode:MKInputModePinyin], @"我們是"), @"Pinyin composes continuous multi-syllable input womenshi into 我們是");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"zhongwen" limit:9 mode:MKInputModePinyin], @"中文"), @"Pinyin composes continuous multi-syllable input zhongwen into 中文");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"shurufa" limit:9 mode:MKInputModePinyin], @"輸入法"), @"Pinyin composes local phrase seed shurufa into 輸入法");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"jintian" limit:9 mode:MKInputModePinyin], @"今天"), @"Pinyin prefers full syllables for jintian");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"dianhua" limit:9 mode:MKInputModePinyin], @"電話"), @"Pinyin composes continuous multi-syllable input dianhua into 電話");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"zaijian" limit:9 mode:MKInputModePinyin], @"再見"), @"Pinyin seed composes zaijian into 再見");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"xiexie" limit:9 mode:MKInputModePinyin], @"謝謝"), @"Pinyin seed composes xiexie into 謝謝");
        AssertTrue([engine hasCandidatesOrPrefixesForInput:@"shuruf" mode:MKInputModePinyin], @"Pinyin keeps local phrase prefixes composing");
        AssertTrue(![engine prefersRawEnglishForInput:@"zhongguoren" mode:MKInputModePinyin], @"Pinyin long segmented inputs are not treated as raw English");
        AssertTrue(engine.pinyinEntryCount > 10000, @"loads expanded pinyin seed table plus full Rime pinyin dictionary on first Pinyin lookup");
        AssertTrue(FirstCandidateIsText([engine candidatesForInput:@"de" limit:9 mode:MKInputModePinyin], @"的"), @"Pinyin de prioritizes 的");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"kai" limit:9 mode:MKInputModePinyin], @"開"), @"Pinyin kai returns 開");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"wen" limit:9 mode:MKInputModePinyin], @"問"), @"Pinyin wen returns 問");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"zui" limit:9 mode:MKInputModePinyin], @"最"), @"Pinyin zui returns 最");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"zhuan" limit:9 mode:MKInputModePinyin], @"轉"), @"Pinyin zhuan returns 轉");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"qiu" limit:9 mode:MKInputModePinyin], @"秋"), @"Pinyin qiu returns dictionary candidates beyond the seed table");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"long" limit:9 mode:MKInputModePinyin], @"龍"), @"Pinyin long returns full dictionary Traditional candidates");
        AssertTrue(CandidatesContainText([engine candidatesForInput:@"zhongguoneidi" limit:9 mode:MKInputModePinyin], @"中國內地"), @"Pinyin supports exact multi-syllable dictionary phrases");
        NSArray<NSString *> *saaiDictionaryCandidates = [engine dictionaryCandidateTextsForCharacter:@"晒" limit:5];
        AssertTrue(saaiDictionaryCandidates.count >= 2 &&
                   [saaiDictionaryCandidates.firstObject isEqualToString:@"晒"] &&
                   [saaiDictionaryCandidates containsObject:@"曬"],
                   @"voice dictionary fallback uses the full input dictionaries for common written variants");
        NSArray<NSString *> *faatDictionaryCandidates = [engine dictionaryCandidateTextsForCharacter:@"發" limit:5];
        AssertTrue(faatDictionaryCandidates.count >= 2 &&
                   [faatDictionaryCandidates.firstObject isEqualToString:@"發"] &&
                   [faatDictionaryCandidates containsObject:@"法"],
                   @"voice dictionary fallback exposes broad same-pronunciation alternatives from the engine");
        AssertTrue([engine dictionaryCandidateTextsForCharacter:@"AB" limit:5].count == 0,
                   @"voice dictionary fallback rejects multi-character non-Han input");
        AssertTrue(!CandidatesContainText([engine candidatesForInput:@"ni" limit:9 mode:MKInputModeCangjie], @"你"), @"Cangjie ni does not return Pinyin 你");
        AssertTrue([engine candidatesForInput:@"hqi" limit:9 mode:MKInputModeEnglish].count == 0, @"English mode does not expose Chinese candidates");
        AssertTrue([engine hasCandidatesOrPrefixesForInput:@"hq" mode:MKInputModeCangjie], @"Cangjie prefix hq is recognized");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"我" limit:9], @"們"), @"association candidates include 我們");
        AssertTrue(FirstCandidateIsText([engine associatedCandidatesForText:@"們" limit:9], @"是"), @"association candidates include 我們是");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"輸" limit:9], @"入"), @"association candidates include 輸入");
        NSArray<MKInputMode> *associationModes = @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
        for (MKInputMode mode in associationModes) {
            AssertTrue(FirstCandidateIsText([engine associatedCandidatesForText:@"你" limit:9 mode:mode], @"好"),
                       [NSString stringWithFormat:@"%@ post-commit associations keep 你 -> 好 first", mode]);
            AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"你" limit:120 mode:mode], @"想"),
                       [NSString stringWithFormat:@"%@ post-commit associations expose expanded common-character pages", mode]);
        }
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"輸" limit:20 mode:MKInputModeSucheng], @"入法"), @"Sucheng generated associations include multi-character suffixes");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"候" limit:9 mode:MKInputModeSucheng], @"選"), @"Sucheng uses association phrase seed data");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"排" limit:9 mode:MKInputModeSmartSucheng], @"位"), @"New Sucheng uses association phrase seed data");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"敏" limit:20 mode:MKInputModeSmartSucheng], @"感"), @"association seed includes privacy phrases");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"偏" limit:20 mode:MKInputModeSucheng], @"好"), @"association seed includes preferences phrases");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"重" limit:20 mode:MKInputModeSmartSucheng], @"設"), @"association seed includes maintenance phrases");
        AssertTrue([engine associatedCandidatesForText:@"你" limit:120 mode:MKInputModeSucheng].count > 40, @"Sucheng exposes expanded association pages for common characters");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"字" limit:40 mode:MKInputModeSucheng], @"單"), @"Sucheng association seed includes candidate-list wording");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"候選" limit:40 mode:MKInputModeSucheng], @"頁數"), @"Sucheng association seed includes candidate page wording");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"關連" limit:40 mode:MKInputModeSucheng], @"字"), @"Sucheng association seed includes common 關連字 wording");
        AssertTrue(FirstCandidateIsText([engine associatedCandidatesForText:@"關連字" limit:9 mode:MKInputModeSucheng], @"庫"), @"Sucheng overlap-normalizes 關連字庫 continuation");
        AssertTrue(!CandidatesContainText([engine associatedCandidatesForText:@"關連字" limit:20 mode:MKInputModeSucheng], @"字庫"), @"Sucheng does not duplicate the 字 in 關連字庫 associations");
        AssertTrue(FirstCandidateIsText([engine associatedCandidatesForText:@"關聯字" limit:9 mode:MKInputModeSucheng], @"庫"), @"Sucheng overlap-normalizes 關聯字庫 continuation");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"字庫" limit:20 mode:MKInputModeSucheng], @"資料"), @"Sucheng association seed covers dictionary maintenance wording");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"咁" limit:20 mode:MKInputModeSucheng], @"樣"), @"Sucheng association seed includes common Cantonese continuations");
        AssertTrue(FirstCandidateIsText([engine associatedCandidatesForText:@"可以" limit:9 mode:MKInputModeSucheng], @"用"), @"Sucheng checks full committed phrases before falling back to the last character");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"神" limit:20 mode:MKInputModeSucheng], @"說"), @"Sucheng loads generated association corpus");
        AssertTrue(CandidatesContainText([engine associatedCandidatesForText:@"耶" limit:20 mode:MKInputModeSucheng], @"和華"), @"Sucheng generated associations include open-source corpus suffixes");
        AssertTrue([engine isLikelyRawToken:@"www."], @"URL-like token is raw");
        AssertTrue(![engine prefersRawEnglishForInput:@"hi" mode:MKInputModeSucheng], @"Sucheng keeps two-letter codes as Chinese input");
        AssertTrue([engine prefersRawEnglishForInput:@"setting" mode:MKInputModeSucheng], @"Sucheng treats long alphabetic words as raw English");
        AssertTrue([engine prefersRawEnglishForInput:@"setting" mode:MKInputModeSmartSucheng], @"New Sucheng treats common English words as raw English");
        AssertTrue([engine prefersRawEnglishForInput:@"new" mode:MKInputModeSmartSucheng], @"New Sucheng treats common short English words as raw English");
        AssertTrue([engine prefersRawEnglishForInput:@"app" mode:MKInputModeSmartSucheng], @"New Sucheng treats short app/UI words as raw English");
        AssertTrue([engine candidatesForInput:@"new" limit:9 mode:MKInputModeSmartSucheng].count == 0, @"New Sucheng suppresses generated Chinese phrases for common short English words");
        AssertTrue([engine candidatesForInput:@"about" limit:9 mode:MKInputModeSmartSucheng].count == 0, @"New Sucheng suppresses generated Chinese phrases for common English tokens");
        AssertTrue(![engine prefersRawEnglishForInput:@"hionaomjoo" mode:MKInputModeSmartSucheng], @"New Sucheng protects seeded phrase codes from raw English detection");
        AssertTrue(![engine prefersRawEnglishForInput:@"lykjnohei" mode:MKInputModeSmartSucheng], @"New Sucheng protects corpus-generated phrase codes from raw English detection");
        AssertTrue([engine prefersRawEnglishForInput:@"setting" mode:MKInputModeCangjie], @"Cangjie treats overlong alphabetic words as raw English");

        NSString *learningRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"PurrTypeEngineTests-%@", [NSUUID UUID].UUIDString]];
        NSString *learningPath = [[[learningRoot stringByAppendingPathComponent:@"Library/Application Support"]
            stringByAppendingPathComponent:@"PurrType"] stringByAppendingPathComponent:@"learning-rankings.json"];
        PurrTypeEngine *learningEngine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                                    pinyinPath:pinyinPath
                                                                                  learningPath:learningPath];
        AssertTrue(!learningEngine.learningEnabled, @"New Sucheng learning defaults off until explicitly enabled");
        MKCandidate *learnedHiCandidate = CandidateWithText([learningEngine candidatesForInput:@"hi" limit:30 mode:MKInputModeSucheng], @"我");
        AssertTrue(learnedHiCandidate != nil, @"learning fixture can find Sucheng hi 我");
        [learningEngine recordSelectionForCandidate:learnedHiCandidate previousText:nil mode:MKInputModeSucheng];
        AssertTrue(CandidateTextsHavePrefix([learningEngine candidatesForInput:@"hi" limit:9 mode:MKInputModeSucheng], @[@"凡", @"么", @"丟", @"夙", @"舟", @"卵", @"我", @"私", @"的"]), @"Sucheng ignores learning and keeps fixed positions");
        learningEngine.learningEnabled = YES;
        [learningEngine recordSelectionForCandidate:learnedHiCandidate previousText:nil mode:MKInputModeSmartSucheng];
        AssertTrue(FirstCandidateIsText([learningEngine candidatesForInput:@"hi" limit:9 mode:MKInputModeSmartSucheng], @"我"), @"New Sucheng learned candidate moves to first position");
        learningEngine.learningEnabled = NO;
        AssertTrue(CandidateTextsHavePrefix([learningEngine candidatesForInput:@"hi" limit:9 mode:MKInputModeSmartSucheng], @[@"凡", @"么", @"丟", @"夙", @"舟", @"卵", @"我", @"私", @"的"]), @"New Sucheng can disable local learning overlay");
        [learningEngine recordCommittedText:@"我想測試" code:@"hidpyryr" mode:MKInputModeSmartSucheng];
        AssertTrue(!FirstCandidateIsText([learningEngine candidatesForInput:@"hidpyryr" limit:9 mode:MKInputModeSmartSucheng], @"我想測試"), @"New Sucheng does not learn while learning is disabled");
        learningEngine.learningEnabled = YES;
        [learningEngine recordCommittedText:@"銀行密碼" code:@"ovecphhr" mode:MKInputModeSmartSucheng];
        AssertTrue(!FirstCandidateIsText([learningEngine candidatesForInput:@"ovecphhr" limit:9 mode:MKInputModeSmartSucheng], @"銀行密碼"), @"New Sucheng refuses to learn sensitive banking/password phrases");

        NSArray<MKCandidate *> *associationFixtureCandidates = [learningEngine associatedCandidatesForText:@"我" limit:20 mode:MKInputModeSmartSucheng];
        MKCandidate *learnedAssociationCandidate = associationFixtureCandidates.count > 1 ? associationFixtureCandidates[1] : nil;
        AssertTrue(learnedAssociationCandidate != nil, @"New Sucheng association fixture can find a non-first association candidate");
        NSString *learnedAssociationText = learnedAssociationCandidate.text;
        NSArray<NSString *> *classicSuchengAssociationBaseline = CandidateTexts([learningEngine associatedCandidatesForText:@"我"
                                                                                                                      limit:9
                                                                                                                       mode:MKInputModeSucheng]);
        [learningEngine recordSelectionForCandidate:learnedAssociationCandidate previousText:nil mode:MKInputModeSucheng];
        AssertTrue(FirstCandidateIsText([learningEngine associatedCandidatesForText:@"我" limit:9 mode:MKInputModeSucheng], @"們"), @"Sucheng associations ignore learning");
        [learningEngine recordSelectionForCandidate:learnedAssociationCandidate previousText:nil mode:MKInputModeSmartSucheng];
        AssertTrue(FirstCandidateIsText([learningEngine associatedCandidatesForText:@"我" limit:9 mode:MKInputModeSmartSucheng], learnedAssociationText), @"New Sucheng learned association moves before seed associations");
        AssertTrue(TextArrayEquals(CandidateTexts([learningEngine associatedCandidatesForText:@"我"
                                                                                        limit:9
                                                                                         mode:MKInputModeSucheng]),
                                   classicSuchengAssociationBaseline),
                   @"Classic Sucheng fixed associations stay unchanged after New Sucheng association learning");

        NSArray<MKCandidate *> *generatedPhraseFixtureCandidates = [learningEngine candidatesForInput:@"aojo" limit:200 mode:MKInputModeSmartSucheng];
        NSString *baseGeneratedPhraseFirstText = generatedPhraseFixtureCandidates.firstObject.text ?: @"";
        MKCandidate *learnedGeneratedPhraseCandidate = nil;
        for (MKCandidate *candidate in generatedPhraseFixtureCandidates) {
            if ([candidate.source isEqualToString:@"smart_phrase_generated"] &&
                ![candidate.text isEqualToString:baseGeneratedPhraseFirstText]) {
                learnedGeneratedPhraseCandidate = candidate;
                break;
            }
        }
        AssertTrue(learnedGeneratedPhraseCandidate != nil, @"New Sucheng generated phrase fixture can find a non-first generated phrase");
        [learningEngine recordSelectionForCandidate:learnedGeneratedPhraseCandidate previousText:nil mode:MKInputModeSmartSucheng];
        AssertTrue(FirstCandidateIsText([learningEngine candidatesForInput:@"aojo" limit:9 mode:MKInputModeSmartSucheng], learnedGeneratedPhraseCandidate.text), @"New Sucheng learned generated phrase moves to first position");
        [learningEngine recordCommittedText:@"我想繼續" code:@"hidpvivc" mode:MKInputModeSucheng];
        AssertTrue(!FirstCandidateIsText([learningEngine candidatesForInput:@"hidpvivc" limit:9 mode:MKInputModeSucheng], @"我想繼續"), @"Sucheng ignores committed phrase learning");
        [learningEngine recordCommittedText:@"我想繼續" code:@"hidpvivc" mode:MKInputModeSmartSucheng];
        AssertTrue([learningEngine hasCandidatesOrPrefixesForInput:@"hidpvi" mode:MKInputModeSmartSucheng], @"New Sucheng learned phrase prefix is recognized");
        AssertTrue(FirstCandidateIsText([learningEngine candidatesForInput:@"hidpvivc" limit:9 mode:MKInputModeSmartSucheng], @"我想繼續"), @"New Sucheng learns committed user phrase");
        NSData *learningData = [NSData dataWithContentsOfFile:learningPath];
        NSString *learningText = [[NSString alloc] initWithData:learningData encoding:NSUTF8StringEncoding];
        AssertTrue([learningText containsString:@"\"candidateHashes\""], @"New Sucheng stores hashed candidate ranking");
        AssertTrue([learningText containsString:@"\"associationHashes\""], @"New Sucheng stores hashed association ranking");
        NSDictionary<NSFileAttributeKey, id> *learningFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:learningPath error:nil];
        NSDictionary<NSFileAttributeKey, id> *learningDirectoryAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[learningPath stringByDeletingLastPathComponent] error:nil];
        AssertTrue(([learningFileAttributes[NSFilePosixPermissions] unsignedIntegerValue] & 0777) == 0600,
                   @"New Sucheng learning file is private to the current user");
        AssertTrue(([learningDirectoryAttributes[NSFilePosixPermissions] unsignedIntegerValue] & 0777) == 0700,
                   @"New Sucheng learning directory is private to the current user");
        AssertTrue(![learningText containsString:@"我"], @"New Sucheng ranking file does not store learned candidate plaintext");
        AssertTrue(![learningText containsString:learnedAssociationText], @"New Sucheng ranking file does not store learned association plaintext");
        AssertTrue(![learningText containsString:learnedGeneratedPhraseCandidate.text], @"New Sucheng ranking file does not store generated phrase plaintext");
        AssertTrue(![learningText containsString:@"我想繼續"], @"New Sucheng committed custom phrase remains session-only");

        PurrTypeEngine *reloadedLearningEngine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                                             pinyinPath:pinyinPath
                                                                                           learningPath:learningPath];
        AssertTrue(CandidateTextsHavePrefix([reloadedLearningEngine candidatesForInput:@"hi" limit:9 mode:MKInputModeSucheng], @[@"凡", @"么", @"丟", @"夙", @"舟", @"卵", @"我", @"私", @"的"]), @"Sucheng still keeps fixed positions after learning reload");
        AssertTrue(CandidateTextsHavePrefix([reloadedLearningEngine candidatesForInput:@"hi" limit:9 mode:MKInputModeSmartSucheng], @[@"凡", @"么", @"丟", @"夙", @"舟", @"卵", @"我", @"私", @"的"]), @"New Sucheng reload starts from base order");
        reloadedLearningEngine.learningEnabled = YES;
        AssertTrue(FirstCandidateIsText([reloadedLearningEngine candidatesForInput:@"hi" limit:9 mode:MKInputModeSmartSucheng], @"我"), @"New Sucheng hashed ranking persists candidate ranking across engine reload");
        AssertTrue(FirstCandidateIsText([reloadedLearningEngine associatedCandidatesForText:@"我" limit:9 mode:MKInputModeSucheng], @"們"), @"Sucheng associations still keep seed order after learning reload");
        AssertTrue(FirstCandidateIsText([reloadedLearningEngine associatedCandidatesForText:@"我" limit:9 mode:MKInputModeSmartSucheng], learnedAssociationText), @"New Sucheng hashed ranking persists association ranking across engine reload");
        AssertTrue(FirstCandidateIsText([reloadedLearningEngine candidatesForInput:@"aojo" limit:9 mode:MKInputModeSmartSucheng], learnedGeneratedPhraseCandidate.text), @"New Sucheng hashed ranking persists generated phrase ranking across engine reload");
        AssertTrue(!FirstCandidateIsText([reloadedLearningEngine candidatesForInput:@"hidpvivc" limit:9 mode:MKInputModeSmartSucheng], @"我想繼續"), @"New Sucheng custom committed phrase remains session-only after engine reload");
        [learningEngine resetLearningState];
        AssertTrue(CandidateTextsHavePrefix([learningEngine candidatesForInput:@"hi" limit:9 mode:MKInputModeSmartSucheng], @[@"凡", @"么", @"丟", @"夙", @"舟", @"卵", @"我", @"私", @"的"]), @"New Sucheng reset learning restores base candidate order");
        AssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:learningPath], @"reset learning removes hashed ranking file");
        [[NSFileManager defaultManager] removeItemAtPath:learningRoot error:nil];

        NSString *migrationPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"PurrTypeEngineLegacyLearningTests-%@.json", [NSUUID UUID].UUIDString]];
        NSDictionary *legacyLearningRoot = @{
            @"version": @1,
            @"candidates": @{ @"quick:hi": @{ @"我": @3 } },
            @"associations": @{},
            @"phrases": @{}
        };
        NSData *legacyData = [NSJSONSerialization dataWithJSONObject:legacyLearningRoot options:0 error:nil];
        [legacyData writeToFile:migrationPath options:NSDataWritingAtomic error:nil];
        PurrTypeEngine *migrationEngine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                                      pinyinPath:pinyinPath
                                                                                    learningPath:migrationPath];
        migrationEngine.learningEnabled = YES;
        AssertTrue(CandidateTextsHavePrefix([migrationEngine candidatesForInput:@"hi" limit:9 mode:MKInputModeSmartSucheng], @[@"凡", @"么", @"丟", @"夙", @"舟", @"卵", @"我", @"私", @"的"]), @"legacy learning file is ignored by hashed ranking loader");
        [migrationEngine recordCommittedText:@"我想繼續" code:@"hidpvivc" mode:MKInputModeSmartSucheng];
        AssertTrue([[NSData dataWithContentsOfFile:migrationPath] isEqualToData:legacyData], @"custom phrase session learning does not rewrite legacy files");
        [migrationEngine resetLearningState];
        AssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:migrationPath], @"reset learning removes legacy file");
        [[NSFileManager defaultManager] removeItemAtPath:migrationPath error:nil];

        NSLog(@"PASS: PurrTypeEngineTests");
    }

    return 0;
}
