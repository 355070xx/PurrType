#import <Foundation/Foundation.h>
#import "PurrTypeInputState.h"

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        PurrTypeInputState *state = [[PurrTypeInputState alloc] init];

        [state appendRawEnglishText:@"S"];
        [state appendRawEnglishText:@"e"];
        AssertTrue(state.rawEnglishModeActive, @"raw English mode starts after raw text append");
        AssertTrue([state.buffer isEqualToString:@"Se"], @"raw English preserves typed case");

        [state deleteBackward];
        AssertTrue(state.rawEnglishModeActive, @"raw English mode remains active while buffer still has text");
        AssertTrue([state.buffer isEqualToString:@"S"], @"delete removes one raw English character");

        [state deleteBackward];
        AssertTrue(state.buffer.length == 0, @"delete clears final raw English character");
        AssertTrue(!state.rawEnglishModeActive, @"delete to empty exits raw English mode");
        AssertTrue(!state.associationModeActive, @"delete to empty exits association mode");

        NSArray<NSString *> *rawContinuations = @[
            @"a", @"Z", @"0", @"9", @"@", @"/", @":", @".", @"_", @"-", @"+", @"#", @"'",
            @"?", @"&", @"=", @"%", @"(", @")", @",", @"!", @"[", @"]", @"{", @"}", @"|", @"~"
        ];
        for (NSString *text in rawContinuations) {
            AssertTrue([PurrTypeInputState isRawEnglishContinuationString:text],
                       [NSString stringWithFormat:@"raw English accepts %@", text]);
        }

        NSArray<NSString *> *nonRawContinuations = @[@"", @"ab", @"，", @"我", @" ", @"\n", @"\t"];
        for (NSString *text in nonRawContinuations) {
            AssertTrue(![PurrTypeInputState isRawEnglishContinuationString:text],
                       [NSString stringWithFormat:@"raw English rejects %@", text]);
        }

        state.associationModeActive = YES;
        state.rawEnglishModeActive = YES;
        [state clearAssociations];
        AssertTrue(!state.associationModeActive, @"clear associations resets association mode");
        AssertTrue(!state.rawEnglishModeActive, @"clear associations resets raw English mode");

        [state appendCodeText:@"hi"];
        AssertTrue([state.buffer isEqualToString:@"hi"], @"code text appends to buffer");
        AssertTrue(!state.associationModeActive, @"code append exits association mode");
        [state resetComposition];
        AssertTrue(state.buffer.length == 0, @"reset clears buffer");
        AssertTrue(!state.rawEnglishModeActive, @"reset exits raw English mode");

        NSLog(@"PASS: PurrTypeInputStateTests");
    }

    return 0;
}
