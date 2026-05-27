#import <Foundation/Foundation.h>
#import "../src/PurrTypeQuickPhraseStore.h"

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSString *TemporaryQuickPhraseDirectory(void) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"PurrTypeQuickPhraseStoreTests-%@", [NSUUID UUID].UUIDString]];
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSString *directory = TemporaryQuickPhraseDirectory();
        PurrTypeQuickPhraseStore *store = [[PurrTypeQuickPhraseStore alloc] initWithDirectoryPath:directory];
        NSError *error = nil;

        AssertTrue([PurrTypeQuickPhraseStore isValidTrigger:@";email"], @"semicolon trigger is valid");
        AssertTrue(![PurrTypeQuickPhraseStore isValidTrigger:@"email"], @"trigger must start with semicolon");
        AssertTrue(![PurrTypeQuickPhraseStore isValidTrigger:@";bad space"], @"trigger rejects spaces");
        AssertTrue([PurrTypeQuickPhraseStore isTriggerContinuationString:@"e"], @"quick phrase continuation accepts letters");
        AssertTrue([PurrTypeQuickPhraseStore isTriggerContinuationString:@"1"], @"quick phrase continuation accepts digits");
        AssertTrue([PurrTypeQuickPhraseStore isTriggerContinuationString:@"_"], @"quick phrase continuation accepts underscore");
        AssertTrue(![PurrTypeQuickPhraseStore isTriggerContinuationString:@"."], @"quick phrase continuation rejects punctuation outside trigger syntax");
        AssertTrue([PurrTypeQuickPhraseStore isValidReplacement:@"hello@example.com"], @"one-line replacement is valid");
        AssertTrue(![PurrTypeQuickPhraseStore isValidReplacement:@"hello\nworld"], @"replacement rejects newlines for candidate display safety");

        PurrTypeQuickPhraseEntry *email =
            [store upsertTrigger:@";Email"
                     replacement:@"founder@example.com"
                           label:@"Work email"
                         enabled:YES
                           error:&error];
        AssertTrue(email != nil && error == nil, @"store accepts a valid quick phrase");
        AssertTrue([email.normalizedTrigger isEqualToString:@";email"], @"trigger lookup is case-insensitive");
        AssertTrue([[store enabledEntryForTrigger:@";EMAIL"].replacement isEqualToString:@"founder@example.com"],
                   @"enabled quick phrase can be looked up by trigger");

        PurrTypeQuickPhraseEntry *support =
            [store upsertTrigger:@";email"
                     replacement:@"support@example.com"
                           label:@"Support email"
                         enabled:YES
                           error:&error];
        AssertTrue(support != nil && store.entries.count == 2, @"same trigger can save multiple quick phrase replacements");
        AssertTrue([store enabledEntriesForTrigger:@";email"].count == 2, @"enabled lookup returns every saved replacement for the trigger");
        PurrTypeQuickPhraseEntry *updated =
            [store upsertTrigger:@";email"
                     replacement:@"founder@example.com"
                           label:@"Work email"
                         enabled:NO
                           error:&error];
        AssertTrue(updated != nil && store.entries.count == 2, @"same trigger and replacement updates the existing quick phrase only");
        AssertTrue([store enabledEntriesForTrigger:@";email"].count == 1 &&
                   [[[store enabledEntryForTrigger:@";email"] replacement] isEqualToString:@"support@example.com"],
                   @"disabled duplicate replacement is hidden while other replacements remain available");

        AssertTrue([store saveWithError:&error] && error == nil, @"quick phrase store saves to disk");
        PurrTypeQuickPhraseStore *reloaded = [[PurrTypeQuickPhraseStore alloc] initWithDirectoryPath:directory];
        AssertTrue(reloaded.entries.count == 2 &&
                   [reloaded entriesForTrigger:@";email"].count == 2,
                   @"quick phrase store reloads repeated trigger entries");

        NSData *exported = [reloaded exportJSONDataWithError:&error];
        AssertTrue(exported.length > 0 && error == nil, @"quick phrase store exports JSON");
        PurrTypeQuickPhraseStore *importTarget = [[PurrTypeQuickPhraseStore alloc] initWithDirectoryPath:TemporaryQuickPhraseDirectory()];
        PurrTypeQuickPhraseImportSummary *summary = [importTarget importEntriesFromJSONData:exported error:&error];
        AssertTrue(summary.importedCount == 2 && summary.updatedCount == 0 && summary.invalidCount == 0,
                   @"quick phrase import summary reports imported entries");
        AssertTrue([importTarget entriesForTrigger:@";email"].count == 2,
                   @"quick phrase import restores repeated trigger entries");
        NSString *exportedText = [importTarget exportText];
        AssertTrue([exportedText containsString:@";email\tsupport@example.com"],
                   @"quick phrase TXT export is a user-editable tab-separated file");
        PurrTypeQuickPhraseImportSummary *textSummary =
            [importTarget importEntriesFromText:@";phone\t69771119\nbad\tNope\n;email\tfounder@example.com\n" error:&error];
        AssertTrue(textSummary.importedCount == 1 && textSummary.updatedCount == 1 && textSummary.invalidCount == 1,
                   @"quick phrase TXT import reports added, updated, and invalid rows");
        AssertTrue([[importTarget entryForTrigger:@";phone"].replacement isEqualToString:@"69771119"] &&
                   [importTarget entriesForTrigger:@";email"].count == 2,
                   @"quick phrase TXT import upserts valid rows without collapsing repeated triggers");

        NSData *invalidMixedData =
            [@"{\"entries\":[{\"trigger\":\";ok\",\"replacement\":\"OK\",\"enabled\":true},{\"trigger\":\"bad\",\"replacement\":\"Bad\"}]}"
                dataUsingEncoding:NSUTF8StringEncoding];
        PurrTypeQuickPhraseImportSummary *mixedSummary = [importTarget importEntriesFromJSONData:invalidMixedData error:&error];
        AssertTrue(mixedSummary.importedCount == 1 && mixedSummary.invalidCount == 1,
                   @"quick phrase import skips invalid entries without importing arbitrary text");

        AssertTrue([importTarget removeTrigger:@";ok" error:&error], @"quick phrase remove accepts valid trigger");
        AssertTrue([importTarget entryForTrigger:@";ok"] == nil, @"quick phrase remove deletes the entry");
        AssertTrue([reloaded reloadIfChangedWithError:&error] && error == nil,
                   @"quick phrase store reload-if-changed succeeds when the file is unchanged");

        PurrTypeQuickPhraseStore *limitStore = [[PurrTypeQuickPhraseStore alloc] initWithDirectoryPath:TemporaryQuickPhraseDirectory()];
        for (NSUInteger index = 0; index < 1000; index += 1) {
            NSString *trigger = [NSString stringWithFormat:@";limit%lu", (unsigned long)index];
            NSError *limitError = nil;
            AssertTrue([limitStore upsertTrigger:trigger
                                     replacement:@"OK"
                                           label:@""
                                         enabled:YES
                                           error:&limitError] != nil && limitError == nil,
                       @"quick phrase store accepts entries up to the configured limit");
        }
        NSError *overflowError = nil;
        AssertTrue([limitStore upsertTrigger:@";limit-overflow"
                                 replacement:@"Nope"
                                       label:@""
                                     enabled:YES
                                       error:&overflowError] == nil &&
                   limitStore.entries.count == 1000,
                   @"manual quick phrase insert enforces the configured entry limit");
        PurrTypeQuickPhraseImportSummary *overflowTextSummary =
            [limitStore importEntriesFromText:@";limit-text\tNope\n" error:&overflowError];
        AssertTrue(overflowTextSummary.invalidCount == 1 &&
                   [limitStore entryForTrigger:@";limit-text"] == nil &&
                   limitStore.entries.count == 1000,
                   @"TXT import cannot grow the quick phrase store beyond the configured entry limit");

        PurrTypeQuickPhraseStore *jsonLimitStore = [[PurrTypeQuickPhraseStore alloc] initWithDirectoryPath:TemporaryQuickPhraseDirectory()];
        for (NSUInteger index = 0; index < 999; index += 1) {
            NSString *trigger = [NSString stringWithFormat:@";jsonlimit%lu", (unsigned long)index];
            NSError *limitError = nil;
            AssertTrue([jsonLimitStore upsertTrigger:trigger
                                         replacement:@"OK"
                                               label:@""
                                             enabled:YES
                                               error:&limitError] != nil && limitError == nil,
                       @"quick phrase JSON limit setup succeeds");
        }
        NSData *overflowJSONData =
            [@"{\"entries\":[{\"trigger\":\";jsonlimit-a\",\"replacement\":\"A\",\"enabled\":true},{\"trigger\":\";jsonlimit-b\",\"replacement\":\"B\",\"enabled\":true}]}"
                dataUsingEncoding:NSUTF8StringEncoding];
        PurrTypeQuickPhraseImportSummary *overflowJSONSummary =
            [jsonLimitStore importEntriesFromJSONData:overflowJSONData error:&overflowError];
        AssertTrue(overflowJSONSummary.importedCount == 1 &&
                   overflowJSONSummary.invalidCount == 1 &&
                   [jsonLimitStore entryForTrigger:@";jsonlimit-a"] != nil &&
                   [jsonLimitStore entryForTrigger:@";jsonlimit-b"] == nil &&
                   jsonLimitStore.entries.count == 1000,
                   @"JSON import cannot grow the quick phrase store beyond the configured entry limit");

        [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
    }

    NSLog(@"PASS: PurrTypeQuickPhraseStoreTests");
    return 0;
}
