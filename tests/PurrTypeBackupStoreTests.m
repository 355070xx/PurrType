#import <Foundation/Foundation.h>
#import "../src/PurrTypeBackupStore.h"

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSString *TemporaryBackupDirectory(void) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"PurrTypeBackupStoreTests-%@", [NSUUID UUID].UUIDString]];
}

static void WriteJSONObject(NSString *directory, NSString *fileName, id object) {
    NSError *error = nil;
    AssertTrue([[NSFileManager defaultManager] createDirectoryAtPath:directory
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:&error],
               @"test creates backup source directory");
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                   options:(NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys)
                                                     error:&error];
    AssertTrue(data != nil && error == nil, @"test serializes JSON fixture");
    NSString *path = [directory stringByAppendingPathComponent:fileName];
    AssertTrue([data writeToFile:path options:NSDataWritingAtomic error:&error] && error == nil,
               [NSString stringWithFormat:@"test writes %@", fileName]);
}

static NSDictionary *JSONObjectFromData(NSData *data) {
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    AssertTrue([object isKindOfClass:[NSDictionary class]] && error == nil, @"test reads JSON object");
    return (NSDictionary *)object;
}

static NSDictionary *JSONObjectFromFile(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    AssertTrue(data.length > 0, @"test reads JSON file");
    return JSONObjectFromData(data);
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSString *sourceDirectory = TemporaryBackupDirectory();
        WriteJSONObject(sourceDirectory,
                        @"quick-phrases.json",
                        @{ @"version": @1,
                           @"entries": @[ @{ @"trigger": @";email",
                                             @"replacement": @"founder@example.com",
                                             @"enabled": @YES } ] });
        WriteJSONObject(sourceDirectory,
                        @"private-cache.json",
                        @{ @"state": @"enabled", @"secretToken": @"SECRET" });
        WriteJSONObject(sourceDirectory,
                        @"app-rules.json",
                        @{ @"version": @1, @"appRules": @{ @"com.apple.TextEdit": @"writing" } });
        WriteJSONObject(sourceDirectory,
                        @"dictionary-notes.json",
                        @{ @"entries": @[ @{ @"word": @"Private" } ] });

        PurrTypeBackupStore *sourceStore = [[PurrTypeBackupStore alloc] initWithDirectoryPath:sourceDirectory];
        NSError *error = nil;
        NSData *backupData = [sourceStore exportBackupDataWithError:&error];
        AssertTrue(backupData.length > 0 && error == nil, @"basic backup exports JSON");
        NSDictionary *backupRoot = JSONObjectFromData(backupData);
        AssertTrue([backupRoot[@"format"] isEqualToString:@"purrtype-basic-backup"],
                   @"backup records the public basic format");
        NSDictionary *payload = backupRoot[@"payload"];
        AssertTrue([payload[@"quickPhrases"] isKindOfClass:[NSDictionary class]],
                   @"public basic backup includes quick phrases");
        AssertTrue(payload[@"private-cache"] == nil &&
                   payload[@"secretToken"] == nil &&
                   payload[@"appRules"] == nil &&
                   payload[@"dictionaryNotes"] == nil,
                   @"public basic backup excludes unrelated payloads");
        NSString *backupText = [[NSString alloc] initWithData:backupData encoding:NSUTF8StringEncoding];
        AssertTrue([backupText rangeOfString:@"SECRET"].location == NSNotFound,
                   @"backup JSON does not leak unrelated private values");

        NSString *targetDirectory = TemporaryBackupDirectory();
        WriteJSONObject(targetDirectory,
                        @"quick-phrases.json",
                        @{ @"version": @1,
                           @"entries": @[ @{ @"trigger": @";old",
                                             @"replacement": @"old@example.com",
                                             @"enabled": @YES } ] });
        PurrTypeBackupStore *targetStore = [[PurrTypeBackupStore alloc] initWithDirectoryPath:targetDirectory];
        PurrTypeBackupSummary *summary = [targetStore restoreBackupData:backupData error:&error];
        AssertTrue(summary != nil && error == nil, @"restore accepts a valid public basic backup");
        AssertTrue(summary.importedCount == 1 && summary.replacedCount == 1 && summary.invalidCount == 0,
                   @"restore summary reports imported and replaced quick phrases");
        AssertTrue(summary.preRestoreBackupURL != nil &&
                   [[NSFileManager defaultManager] fileExistsAtPath:summary.preRestoreBackupURL.path],
                   @"restore creates a pre-restore backup before writing public data");
        NSDictionary *restoredQuickPhrases = JSONObjectFromFile([targetDirectory stringByAppendingPathComponent:@"quick-phrases.json"]);
        NSArray *entries = restoredQuickPhrases[@"entries"];
        AssertTrue([entries isKindOfClass:[NSArray class]] &&
                   entries.count == 1 &&
                   [entries[0][@"trigger"] isEqualToString:@";email"],
                   @"restore writes only quick phrases in the original store format");

        NSMutableDictionary *invalidPayloadRoot = [backupRoot mutableCopy];
        NSMutableDictionary *invalidPayload = [payload mutableCopy];
        invalidPayload[@"quickPhrases"] = @"not-json-object";
        invalidPayloadRoot[@"payload"] = invalidPayload;
        NSData *invalidPayloadData = [NSJSONSerialization dataWithJSONObject:invalidPayloadRoot
                                                                     options:NSJSONWritingSortedKeys
                                                                       error:&error];
        PurrTypeBackupSummary *invalidSummary = [targetStore restoreBackupData:invalidPayloadData error:&error];
        AssertTrue(invalidSummary.invalidCount == 1 && invalidSummary.importedCount == 0,
                   @"restore skips invalid quick phrase payloads");

        NSMutableDictionary *missingEntriesRoot = [backupRoot mutableCopy];
        NSMutableDictionary *missingEntriesPayload = [payload mutableCopy];
        missingEntriesPayload[@"quickPhrases"] = @{ @"version": @1, @"wrongKey": @[] };
        missingEntriesRoot[@"payload"] = missingEntriesPayload;
        NSData *missingEntriesData = [NSJSONSerialization dataWithJSONObject:missingEntriesRoot
                                                                     options:NSJSONWritingSortedKeys
                                                                       error:&error];
        error = nil;
        PurrTypeBackupSummary *missingEntriesSummary = [targetStore restoreBackupData:missingEntriesData error:&error];
        AssertTrue(missingEntriesSummary.invalidCount == 1 && missingEntriesSummary.importedCount == 0,
                   @"restore rejects malformed quick phrase backup shape");

        NSMutableDictionary *emptyQuickPhrasesRoot = [backupRoot mutableCopy];
        NSMutableDictionary *emptyQuickPhrasesPayload = [payload mutableCopy];
        emptyQuickPhrasesPayload[@"quickPhrases"] = @{ @"version": @1, @"entries": @[] };
        emptyQuickPhrasesRoot[@"payload"] = emptyQuickPhrasesPayload;
        NSData *emptyQuickPhrasesData = [NSJSONSerialization dataWithJSONObject:emptyQuickPhrasesRoot
                                                                        options:NSJSONWritingSortedKeys
                                                                          error:&error];
        error = nil;
        PurrTypeBackupSummary *emptyQuickPhrasesSummary = [targetStore restoreBackupData:emptyQuickPhrasesData error:&error];
        AssertTrue(emptyQuickPhrasesSummary.importedCount == 1 &&
                   emptyQuickPhrasesSummary.invalidCount == 0,
                   @"restore accepts a valid empty quick phrase backup");
        NSDictionary *emptyQuickPhrases = JSONObjectFromFile([targetDirectory stringByAppendingPathComponent:@"quick-phrases.json"]);
        AssertTrue([emptyQuickPhrases[@"entries"] isKindOfClass:[NSArray class]] &&
                   [emptyQuickPhrases[@"entries"] count] == 0,
                   @"valid empty backup clears quick phrases with canonical store format");

        error = nil;
        NSData *badFormatData = [@"{\"format\":\"purrtype-advanced-backup\",\"version\":1,\"payload\":{}}" dataUsingEncoding:NSUTF8StringEncoding];
        AssertTrue([targetStore restoreBackupData:badFormatData error:&error] == nil &&
                   [error.domain isEqualToString:MKPurrTypeBackupStoreErrorDomain],
                   @"public restore rejects unknown backup formats");

        [[NSFileManager defaultManager] removeItemAtPath:sourceDirectory error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:targetDirectory error:nil];
    }

    NSLog(@"PASS: PurrTypeBackupStoreTests");
    return 0;
}
