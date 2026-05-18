#import <Foundation/Foundation.h>
#import "../src/PurrTypeEngine.h"

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
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

static NSString *JoinedCandidates(NSArray<NSString *> *candidates) {
    return candidates.count == 0 ? @"None" : [candidates componentsJoinedByString:@" "];
}

static NSString *JoinedRows(NSArray<NSString *> *rows) {
    return rows.count == 0 ? @"None" : [rows componentsJoinedByString:@"\n"];
}

static NSArray<NSDictionary<NSString *, NSArray<NSString *> *> *> *LoadSuchengSnapshotRows(NSString *path) {
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    AssertTrue(contents.length > 0, @"loads Sucheng first-page snapshot");

    NSMutableArray<NSDictionary<NSString *, NSArray<NSString *> *> *> *rows = [NSMutableArray array];
    NSArray<NSString *> *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if (line.length == 0 || [line hasPrefix:@"#"]) {
            continue;
        }

        NSArray<NSString *> *columns = [line componentsSeparatedByString:@"\t"];
        if (columns.count < 2) {
            continue;
        }
        [rows addObject:@{
            @"code": @[columns.firstObject],
            @"candidates": [columns subarrayWithRange:NSMakeRange(1, columns.count - 1)]
        }];
    }
    return [rows copy];
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *snapshotPath = [root stringByAppendingPathComponent:@"resources/sucheng_first_pages.tsv"];
        NSString *cangjieDirectory = [root stringByAppendingPathComponent:@"third_party/rime-cangjie"];
        NSString *pinyinPath = [root stringByAppendingPathComponent:@"resources/pinyin_seed.tsv"];
        NSString *reportDirectory = [root stringByAppendingPathComponent:@"build"];
        NSString *reportPath = [reportDirectory stringByAppendingPathComponent:@"sucheng_ranking_audit.md"];

        PurrTypeEngine *engine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                            pinyinPath:pinyinPath];
        NSArray<NSDictionary<NSString *, NSArray<NSString *> *> *> *snapshotRows = LoadSuchengSnapshotRows(snapshotPath);
        NSMutableArray<NSString *> *unexpectedRows = [NSMutableArray array];

        for (NSDictionary<NSString *, NSArray<NSString *> *> *row in snapshotRows) {
            NSString *code = row[@"code"].firstObject;
            NSArray<NSString *> *expected = row[@"candidates"];
            NSArray<MKCandidate *> *actualCandidates = [engine candidatesForInput:code
                                                                            limit:expected.count
                                                                             mode:MKInputModeSucheng];
            NSMutableArray<NSString *> *actual = [NSMutableArray arrayWithCapacity:actualCandidates.count];
            for (MKCandidate *candidate in actualCandidates) {
                [actual addObject:candidate.text];
            }

            if (!TextArrayEquals(expected, actual)) {
                [unexpectedRows addObject:[NSString stringWithFormat:@"- `%@`\n  - snapshot: %@\n  - runtime: %@",
                                           code,
                                           JoinedCandidates(expected),
                                           JoinedCandidates(actual)]];
            }
        }

        NSString *result = unexpectedRows.count == 0 ? @"PASS" : @"FAIL";
        NSString *report = [NSString stringWithFormat:
            @"# Sucheng Ranking Audit\n\n"
             "- Baseline: `PurrTypeEngine` runtime Sucheng order.\n"
             "- Runtime source: `third_party/ibus-table-chinese/quick-classic.txt` plus `resources/sucheng_order_guards.tsv`.\n"
             "- Snapshot: `resources/sucheng_first_pages.tsv`.\n"
             "- Scope: populated alphabetic one-key and two-key Sucheng codes.\n"
             "- Codes checked: %lu\n"
             "- Unexpected mismatches: %lu\n"
             "- Result: %@\n\n"
             "## Unexpected Mismatches\n\n%@\n",
            (unsigned long)snapshotRows.count,
            (unsigned long)unexpectedRows.count,
            result,
            JoinedRows(unexpectedRows)];

        NSError *error = nil;
        BOOL createdDirectory = [[NSFileManager defaultManager] createDirectoryAtPath:reportDirectory
                                                          withIntermediateDirectories:YES
                                                                           attributes:nil
                                                                                error:&error];
        AssertTrue(createdDirectory, [NSString stringWithFormat:@"creates ranking report directory %@", error.localizedDescription ?: @""]);
        BOOL wrote = [report writeToFile:reportPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        AssertTrue(wrote, [NSString stringWithFormat:@"writes Sucheng ranking audit %@", error.localizedDescription ?: @""]);
        AssertTrue(snapshotRows.count >= 650, @"Sucheng snapshot covers populated alphabetic one/two-key codes");
        AssertTrue(unexpectedRows.count == 0, @"Sucheng first pages match runtime Quick Classic order plus verified guards");
        NSLog(@"PASS: PurrTypeSuchengRankingAudit %@", reportPath);
    }
    return 0;
}
