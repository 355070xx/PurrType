#import <Foundation/Foundation.h>
#import "../src/PurrTypeVoiceHomophoneStore.h"

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
        NSURL *resourceURL = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"resources/cantonese_voice_homophones.tsv"]];
        PurrTypeVoiceHomophoneStore *store = [[PurrTypeVoiceHomophoneStore alloc] initWithResourceURL:resourceURL];

        NSArray<NSString *> *faatCandidates = [store homophonesForCharacter:@"發" limit:5];
        AssertTrue(faatCandidates.count >= 3 &&
                   [faatCandidates[0] isEqualToString:@"發"] &&
                   [faatCandidates containsObject:@"法"] &&
                   [faatCandidates containsObject:@"髮"],
                   @"faat3 fallback offers the recognized character plus same-sound alternatives");

        NSArray<NSString *> *limitedCandidates = [store homophonesForCharacter:@"法" limit:2];
        AssertTrue(limitedCandidates.count == 2 &&
                   [limitedCandidates[0] isEqualToString:@"法"],
                   @"homophone lookup respects the panel limit and keeps the recognized character first");

        NSArray<NSString *> *geiCandidates = [store homophonesForCharacter:@"記" limit:5];
        AssertTrue(geiCandidates.count >= 4 &&
                   [geiCandidates[0] isEqualToString:@"記"] &&
                   [geiCandidates containsObject:@"幾"],
                   @"voice fallback covers common Cantonese tone-confusable gei words from live dictation");

        NSArray<NSString *> *haiCandidates = [store homophonesForCharacter:@"係" limit:5];
        AssertTrue(haiCandidates.count >= 2 &&
                   [haiCandidates[0] isEqualToString:@"係"] &&
                   [haiCandidates containsObject:@"喺"],
                   @"voice fallback offers common spoken Cantonese location marker confusions");

        store.learningEnabled = NO;
        [store recordSelectionForCharacter:@"記" candidate:@"寄"];
        NSArray<NSString *> *disabledLearningCandidates = [store homophonesForCharacter:@"記" limit:5];
        AssertTrue([disabledLearningCandidates[1] isEqualToString:@"幾"],
                   @"disabled voice candidate learning does not change fallback order");

        store.learningEnabled = YES;
        [store recordSelectionForCharacter:@"記" candidate:@"寄"];
        NSArray<NSString *> *learnedCandidates = [store homophonesForCharacter:@"記" limit:5];
        AssertTrue([learnedCandidates[0] isEqualToString:@"記"] &&
                   [learnedCandidates[1] isEqualToString:@"寄"],
                   @"voice candidate learning keeps the recognized character visible and promotes repeated corrections");

        AssertTrue([store homophonesForCharacter:@"A" limit:5].count == 0,
                   @"non-seeded characters do not trigger a candidate panel");
        AssertTrue([store homophonesForCharacter:@"發法" limit:5].count == 0,
                   @"multi-character input is rejected for single-character homophone lookup");

        NSLog(@"PASS: PurrTypeVoiceHomophoneStoreTests");
    }
    return 0;
}
