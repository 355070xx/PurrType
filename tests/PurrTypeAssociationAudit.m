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

static NSArray<NSString *> *CandidateTexts(NSArray<MKCandidate *> *candidates) {
    NSMutableArray<NSString *> *texts = [NSMutableArray arrayWithCapacity:candidates.count];
    for (MKCandidate *candidate in candidates) {
        [texts addObject:candidate.text ?: @""];
    }
    return texts;
}

static NSUInteger CountDataRowsAtPath(NSString *path) {
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    AssertTrue(contents.length > 0, [NSString stringWithFormat:@"loads %@", path.lastPathComponent]);

    NSUInteger rowCount = 0;
    for (NSString *line in [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        if (line.length == 0 || [line hasPrefix:@"#"]) {
            continue;
        }
        rowCount += 1;
    }
    return rowCount;
}

static NSString *JoinedTexts(NSArray<NSString *> *texts) {
    return [texts componentsJoinedByString:@" "];
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *cangjieDirectory = [root stringByAppendingPathComponent:@"third_party/rime-cangjie"];
        NSString *pinyinPath = [root stringByAppendingPathComponent:@"resources/pinyin_seed.tsv"];
        NSString *manualAssociationPath = [root stringByAppendingPathComponent:@"resources/association_phrases.tsv"];
        NSString *generatedAssociationPath = [root stringByAppendingPathComponent:@"resources/association_generated.tsv"];
        NSString *generatedAssociationIndexPath = [root stringByAppendingPathComponent:@"resources/association_generated.index"];
        NSString *reportPath = [root stringByAppendingPathComponent:@"build/association_audit.md"];

        NSUInteger manualRows = CountDataRowsAtPath(manualAssociationPath);
        NSUInteger generatedRows = CountDataRowsAtPath(generatedAssociationPath);
        AssertTrue(manualRows >= 180, @"manual association seed keeps reviewed coverage");
        AssertTrue(generatedRows >= 40000, @"generated association table keeps broad association coverage");
        AssertTrue([[NSFileManager defaultManager] fileExistsAtPath:generatedAssociationIndexPath],
                   @"generated association index exists before runtime lookup");

        CFAbsoluteTime loadStart = CFAbsoluteTimeGetCurrent();
        PurrTypeEngine *engine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                            pinyinPath:pinyinPath];
        CFAbsoluteTime loadSeconds = CFAbsoluteTimeGetCurrent() - loadStart;
        AssertTrue(loadSeconds < 10.0, @"association corpus does not push engine load above 10 seconds");

        CFAbsoluteTime firstGeneratedLookupStart = CFAbsoluteTimeGetCurrent();
        NSArray<MKCandidate *> *firstGeneratedLookup = [engine associatedCandidatesForText:@"神"
                                                                                     limit:20
                                                                                      mode:MKInputModeSucheng];
        CFAbsoluteTime firstGeneratedLookupSeconds = CFAbsoluteTimeGetCurrent() - firstGeneratedLookupStart;
        AssertTrue(CandidatesContainText(firstGeneratedLookup, @"說"),
                   @"first generated association lookup reads indexed corpus");
        AssertTrue(firstGeneratedLookupSeconds < 0.25,
                   @"first generated association lookup stays below 250 ms");

        NSDictionary<NSString *, NSArray<NSString *> *> *requiredAssociations = @{
            @"我": @[@"們"],
            @"你": @[@"好"],
            @"佢": @[@"哋"],
            @"可以": @[@"用"],
            @"今天": @[@"在"],
            @"一個": @[@"人"],
            @"輸": @[@"入", @"入法"],
            @"神": @[@"說"],
            @"耶": @[@"和華"],
            @"候": @[@"選"],
            @"排": @[@"位"],
            @"偏": @[@"好"],
            @"重": @[@"設"],
            @"字": @[@"單"],
            @"候選": @[@"頁數"],
            @"關連": @[@"字"],
            @"關連字": @[@"庫"],
            @"關聯字": @[@"庫"],
            @"字庫": @[@"資料"],
            @"咁": @[@"樣"]
        };

        NSMutableArray<NSString *> *reportLines = [NSMutableArray array];
        [reportLines addObject:@"# Association Audit"];
        [reportLines addObject:@""];
        [reportLines addObject:@"Generated by `make audit-associations`."];
        [reportLines addObject:@""];
        [reportLines addObject:[NSString stringWithFormat:@"- Manual association rows: %lu", (unsigned long)manualRows]];
        [reportLines addObject:[NSString stringWithFormat:@"- Generated association rows: %lu", (unsigned long)generatedRows]];
        [reportLines addObject:[NSString stringWithFormat:@"- Engine load time: %.3f seconds", loadSeconds]];
        [reportLines addObject:[NSString stringWithFormat:@"- First generated association lookup: %.3f seconds", firstGeneratedLookupSeconds]];
        [reportLines addObject:@""];
        [reportLines addObject:@"## Locked Samples"];

        for (NSString *key in [requiredAssociations.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSArray<MKCandidate *> *candidates = [engine associatedCandidatesForText:key
                                                                               limit:20
                                                                                mode:MKInputModeSucheng];
            for (NSString *expected in requiredAssociations[key]) {
                AssertTrue(CandidatesContainText(candidates, expected),
                           [NSString stringWithFormat:@"association %@ includes %@", key, expected]);
            }
            [reportLines addObject:[NSString stringWithFormat:@"- `%@`: %@", key, JoinedTexts(CandidateTexts(candidates))]];
        }

        AssertTrue(FirstCandidateIsText([engine associatedCandidatesForText:@"我" limit:9 mode:MKInputModeSucheng], @"們"),
                   @"manual association keeps 我 -> 們 first");
        AssertTrue(FirstCandidateIsText([engine associatedCandidatesForText:@"可以" limit:9 mode:MKInputModeSucheng], @"用"),
                   @"full-phrase association keeps 可以 -> 用 first");
        AssertTrue([engine associatedCandidatesForText:@"你" limit:120 mode:MKInputModeSucheng].count > 40,
                   @"common association keys expose more than the legacy 40-candidate cap");
        AssertTrue(FirstCandidateIsText([engine associatedCandidatesForText:@"關連字" limit:9 mode:MKInputModeSucheng], @"庫"),
                   @"overlap-normalized association keeps 關連字 -> 庫 first");
        AssertTrue(!CandidatesContainText([engine associatedCandidatesForText:@"關連字" limit:20 mode:MKInputModeSucheng], @"字庫"),
                   @"overlap-normalized association avoids 關連字 -> 字庫 duplication");

        NSArray<MKInputMode> *associationModes = @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
        [reportLines addObject:@""];
        [reportLines addObject:@"## Mode Coverage"];
        for (MKInputMode mode in associationModes) {
            NSArray<MKCandidate *> *modeCandidates = [engine associatedCandidatesForText:@"你"
                                                                                   limit:20
                                                                                    mode:mode];
            AssertTrue(FirstCandidateIsText(modeCandidates, @"好"),
                       [NSString stringWithFormat:@"%@ associations keep 你 -> 好 first", mode]);
            AssertTrue(CandidatesContainText(modeCandidates, @"想"),
                       [NSString stringWithFormat:@"%@ associations include expanded 你 -> 想 continuation", mode]);
            [reportLines addObject:[NSString stringWithFormat:@"- `%@`: %@", mode, JoinedTexts(CandidateTexts(modeCandidates))]];
        }

        NSArray<NSString *> *lookupKeys = @[@"我", @"你", @"佢", @"可以", @"輸", @"神", @"耶", @"候", @"排", @"偏",
                                           @"重", @"今", @"日", @"中", @"文", @"入", @"法", @"設", @"定", @"問"];
        CFAbsoluteTime lookupStart = CFAbsoluteTimeGetCurrent();
        for (NSUInteger iteration = 0; iteration < 1000; iteration += 1) {
            for (NSString *key in lookupKeys) {
                [engine associatedCandidatesForText:key limit:20 mode:MKInputModeSucheng];
            }
        }
        CFAbsoluteTime lookupSeconds = CFAbsoluteTimeGetCurrent() - lookupStart;
        AssertTrue(lookupSeconds < 5.0, @"20k association lookups stay below 5 seconds");
        [reportLines addObject:@""];
        [reportLines addObject:@"## Performance Guard"];
        [reportLines addObject:[NSString stringWithFormat:@"- 20,000 association lookups: %.3f seconds", lookupSeconds]];
        [reportLines addObject:@"- Load threshold: 10.000 seconds"];
        [reportLines addObject:@"- Lookup threshold: 5.000 seconds"];
        [reportLines addObject:@""];
        [reportLines addObject:@"## Result"];
        [reportLines addObject:@""];
        [reportLines addObject:@"PASS"];
        [reportLines addObject:@""];

        NSString *report = [reportLines componentsJoinedByString:@"\n"];
        NSString *reportDirectory = [reportPath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:reportDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        NSError *writeError = nil;
        BOOL wrote = [report writeToFile:reportPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        AssertTrue(wrote, [NSString stringWithFormat:@"writes association audit report: %@", writeError.localizedDescription ?: @""]);

        NSLog(@"PASS: PurrTypeAssociationAudit %@", reportPath);
    }

    return 0;
}
