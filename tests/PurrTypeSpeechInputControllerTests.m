#import <Foundation/Foundation.h>
#import "../src/PurrTypeSpeechInputController.h"

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSString *FileTextAtPath(NSString *path) {
    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    AssertTrue(text.length > 0, [NSString stringWithFormat:@"file is readable: %@ %@", path, error.localizedDescription ?: @""]);
    return text;
}

@interface FakeSpeechRuntime : NSObject <PurrTypeSpeechInputRuntime>

@property(nonatomic, copy) NSSet<NSString *> *supportedLocaleIdentifiers;
@property(nonatomic, assign) PurrTypeSpeechInputPermissionStatus speechStatus;
@property(nonatomic, assign) PurrTypeSpeechInputPermissionStatus requestedSpeechStatus;
@property(nonatomic, assign) PurrTypeSpeechInputPermissionStatus microphoneStatus;
@property(nonatomic, assign) PurrTypeSpeechInputPermissionStatus requestedMicrophoneStatus;
@property(nonatomic, assign) NSUInteger speechRequestCount;
@property(nonatomic, assign) NSUInteger microphoneRequestCount;
@property(nonatomic, assign) NSUInteger prepareCount;
@property(nonatomic, assign) NSUInteger startCount;
@property(nonatomic, assign) NSUInteger stopCount;
@property(nonatomic, assign) BOOL startShouldFail;
@property(nonatomic, assign) BOOL holdPrepareCompletion;
@property(nonatomic, copy) NSString *startedLocaleIdentifier;
@property(nonatomic, copy) NSArray<NSString *> *startedContextualStrings;
@property(nonatomic, copy) NSString *preparedLocaleIdentifier;
@property(nonatomic, copy) NSArray<NSString *> *preparedContextualStrings;
@property(nonatomic, copy) void (^pendingPrepareCompletion)(void);
@property(nonatomic, copy) PurrTypeSpeechInputTranscriptUpdateHandler transcriptUpdateHandler;
@property(nonatomic, copy) PurrTypeSpeechInputErrorHandler errorHandler;

@end

@implementation FakeSpeechRuntime

- (instancetype)init {
    self = [super init];
    if (self) {
        _supportedLocaleIdentifiers = [NSSet setWithObject:@"zh-HK"];
        _speechStatus = PurrTypeSpeechInputPermissionStatusAuthorized;
        _requestedSpeechStatus = PurrTypeSpeechInputPermissionStatusAuthorized;
        _microphoneStatus = PurrTypeSpeechInputPermissionStatusAuthorized;
        _requestedMicrophoneStatus = PurrTypeSpeechInputPermissionStatusAuthorized;
    }
    return self;
}

- (void)requestSpeechAuthorizationWithCompletion:(void (^)(PurrTypeSpeechInputPermissionStatus status))completion {
    self.speechRequestCount += 1;
    if (completion) {
        completion(self.requestedSpeechStatus);
    }
}

- (PurrTypeSpeechInputPermissionStatus)speechAuthorizationStatus {
    return self.speechStatus;
}

- (void)requestMicrophoneAuthorizationWithCompletion:(void (^)(PurrTypeSpeechInputPermissionStatus status))completion {
    self.microphoneRequestCount += 1;
    if (completion) {
        completion(self.requestedMicrophoneStatus);
    }
}

- (PurrTypeSpeechInputPermissionStatus)microphoneAuthorizationStatus {
    return self.microphoneStatus;
}

- (void)prepareAudioRecognitionWithLocaleIdentifier:(NSString *)localeIdentifier
                                  contextualStrings:(NSArray<NSString *> *)contextualStrings
                                         completion:(void (^)(void))completion {
    self.prepareCount += 1;
    self.preparedLocaleIdentifier = [localeIdentifier copy];
    self.preparedContextualStrings = [contextualStrings copy];
    if (self.holdPrepareCompletion) {
        self.pendingPrepareCompletion = completion;
        return;
    }
    if (completion) {
        completion();
    }
}

- (BOOL)startAudioRecognitionWithLocaleIdentifier:(NSString *)localeIdentifier
                                contextualStrings:(NSArray<NSString *> *)contextualStrings
                          transcriptUpdateHandler:(PurrTypeSpeechInputTranscriptUpdateHandler)transcriptUpdateHandler
                                     errorHandler:(PurrTypeSpeechInputErrorHandler)errorHandler
                                            error:(NSError **)error {
    self.startCount += 1;
    self.startedLocaleIdentifier = [localeIdentifier copy];
    self.startedContextualStrings = [contextualStrings copy];
    if (self.startShouldFail) {
        if (error) {
            *error = [NSError errorWithDomain:PurrTypeSpeechInputErrorDomain
                                         code:PurrTypeSpeechInputErrorAudioStartFailed
                                     userInfo:@{ NSLocalizedDescriptionKey: @"fake audio start failure" }];
        }
        return NO;
    }
    self.transcriptUpdateHandler = transcriptUpdateHandler;
    self.errorHandler = errorHandler;
    return YES;
}

- (void)stopAudioRecognition {
    self.stopCount += 1;
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        FakeSpeechRuntime *runtime = [[FakeSpeechRuntime alloc] init];
        PurrTypeSpeechInputController *controller = [[PurrTypeSpeechInputController alloc] initWithRuntime:runtime];
        AssertTrue(controller != nil, @"controller instantiates with fake runtime");
        AssertTrue(runtime.speechRequestCount == 0 && runtime.microphoneRequestCount == 0 && runtime.prepareCount == 0 && runtime.startCount == 0,
                   @"instantiation does not request permissions or start audio");

        NSString *selectedLocale = [PurrTypeSpeechInputController selectedLocaleIdentifierFromSupportedLocaleIdentifiers:
            [NSSet setWithArray:@[ @"zh_CN", @"zh_HK", @"zh_TW" ]]];
        AssertTrue([selectedLocale isEqualToString:@"zh-HK"], @"locale selection prefers zh-HK and normalizes underscores");
        NSString *autoLocale = [PurrTypeSpeechInputController selectedLocaleIdentifierFromSupportedLocaleIdentifiers:[NSSet setWithArray:@[ @"zh_CN", @"zh_TW" ]]
                                                                                          localeSelectionIdentifier:@"auto"];
        AssertTrue([autoLocale isEqualToString:@"zh-TW"], @"Auto locale falls back to Mandarin Taiwan when zh-HK is unavailable");
        NSString *mainlandOnlyLocale = [PurrTypeSpeechInputController selectedLocaleIdentifierFromSupportedLocaleIdentifiers:[NSSet setWithArray:@[ @"zh_CN", @"yue_CN" ]]
                                                                                                  localeSelectionIdentifier:@"auto"];
        AssertTrue(mainlandOnlyLocale == nil, @"Auto does not select Mainland-only locales in the public build");
        NSString *manualLocale = [PurrTypeSpeechInputController selectedLocaleIdentifierFromSupportedLocaleIdentifiers:[NSSet setWithArray:@[ @"zh_HK", @"zh_TW" ]]
                                                                                            localeSelectionIdentifier:@"zh-TW"];
        AssertTrue([manualLocale isEqualToString:@"zh-TW"], @"manual Mandarin Taiwan locale override selects supported locale");
        NSString *unsupportedManualLocale = [PurrTypeSpeechInputController selectedLocaleIdentifierFromSupportedLocaleIdentifiers:[NSSet setWithObject:@"zh_TW"]
                                                                                                       localeSelectionIdentifier:@"zh-HK"];
        AssertTrue(unsupportedManualLocale == nil, @"unsupported manual locale override fails closed");

        FakeSpeechRuntime *unsupportedRuntime = [[FakeSpeechRuntime alloc] init];
        unsupportedRuntime.supportedLocaleIdentifiers = [NSSet setWithObject:@"en-US"];
        unsupportedRuntime.speechStatus = PurrTypeSpeechInputPermissionStatusNotDetermined;
        unsupportedRuntime.microphoneStatus = PurrTypeSpeechInputPermissionStatusNotDetermined;
        PurrTypeSpeechInputController *unsupportedController = [[PurrTypeSpeechInputController alloc] initWithRuntime:unsupportedRuntime];
        __block NSError *unsupportedError = nil;
        BOOL unsupportedStarted = [unsupportedController startWithTranscriptHandler:nil errorHandler:^(NSError *error) {
            unsupportedError = error;
        }];
        AssertTrue(!unsupportedStarted, @"Auto fails closed when zh-HK is unsupported");
        AssertTrue(unsupportedError.code == PurrTypeSpeechInputErrorUnsupportedLocale, @"unsupported locale reports structured error");
        AssertTrue(unsupportedRuntime.speechRequestCount == 0 && unsupportedRuntime.microphoneRequestCount == 0 && unsupportedRuntime.startCount == 0,
                   @"unsupported locale does not request permissions or start audio");

        FakeSpeechRuntime *unsupportedManualRuntime = [[FakeSpeechRuntime alloc] init];
        unsupportedManualRuntime.supportedLocaleIdentifiers = [NSSet setWithObject:@"zh-TW"];
        PurrTypeSpeechInputController *unsupportedManualController = [[PurrTypeSpeechInputController alloc] initWithRuntime:unsupportedManualRuntime];
        __block NSError *unsupportedManualError = nil;
        BOOL unsupportedManualStarted = [unsupportedManualController startWithLocaleSelectionIdentifier:@"zh-HK"
                                                                                     contextualStrings:@[@"PurrType"]
                                                                                     transcriptHandler:nil
                                                                                          errorHandler:^(NSError *error) {
            unsupportedManualError = error;
        }];
        AssertTrue(!unsupportedManualStarted, @"unsupported manual locale fails closed");
        AssertTrue(unsupportedManualError.code == PurrTypeSpeechInputErrorUnsupportedLocale, @"unsupported manual locale reports structured error");
        AssertTrue([unsupportedManualError.userInfo[PurrTypeSpeechInputErrorLocaleIdentifierKey] isEqualToString:@"zh-HK"],
                   @"unsupported manual locale error identifies the selected locale");
        AssertTrue(unsupportedManualRuntime.speechRequestCount == 0 &&
                   unsupportedManualRuntime.microphoneRequestCount == 0 &&
                   unsupportedManualRuntime.startCount == 0,
                   @"unsupported manual locale does not request permissions or start audio");

        FakeSpeechRuntime *speechDeniedRuntime = [[FakeSpeechRuntime alloc] init];
        speechDeniedRuntime.speechStatus = PurrTypeSpeechInputPermissionStatusDenied;
        PurrTypeSpeechInputController *speechDeniedController = [[PurrTypeSpeechInputController alloc] initWithRuntime:speechDeniedRuntime];
        __block NSError *speechDeniedError = nil;
        BOOL speechDeniedStarted = [speechDeniedController startWithTranscriptHandler:nil errorHandler:^(NSError *error) {
            speechDeniedError = error;
        }];
        AssertTrue(!speechDeniedStarted, @"speech permission denied fails closed");
        AssertTrue(speechDeniedError.code == PurrTypeSpeechInputErrorSpeechPermissionDenied, @"speech denial reports structured error");
        AssertTrue(speechDeniedRuntime.microphoneRequestCount == 0 && speechDeniedRuntime.startCount == 0,
                   @"speech denial does not request microphone or start audio");

        FakeSpeechRuntime *microphoneDeniedRuntime = [[FakeSpeechRuntime alloc] init];
        microphoneDeniedRuntime.microphoneStatus = PurrTypeSpeechInputPermissionStatusDenied;
        PurrTypeSpeechInputController *microphoneDeniedController = [[PurrTypeSpeechInputController alloc] initWithRuntime:microphoneDeniedRuntime];
        __block NSError *microphoneDeniedError = nil;
        BOOL microphoneDeniedStarted = [microphoneDeniedController startWithTranscriptHandler:nil errorHandler:^(NSError *error) {
            microphoneDeniedError = error;
        }];
        AssertTrue(!microphoneDeniedStarted, @"microphone permission denied fails closed");
        AssertTrue(microphoneDeniedError.code == PurrTypeSpeechInputErrorMicrophonePermissionDenied, @"microphone denial reports structured error");
        AssertTrue(microphoneDeniedRuntime.startCount == 0, @"microphone denial does not start audio");

        FakeSpeechRuntime *requestRuntime = [[FakeSpeechRuntime alloc] init];
        requestRuntime.speechStatus = PurrTypeSpeechInputPermissionStatusNotDetermined;
        requestRuntime.requestedSpeechStatus = PurrTypeSpeechInputPermissionStatusAuthorized;
        requestRuntime.microphoneStatus = PurrTypeSpeechInputPermissionStatusNotDetermined;
        requestRuntime.requestedMicrophoneStatus = PurrTypeSpeechInputPermissionStatusAuthorized;
        PurrTypeSpeechInputController *requestController = [[PurrTypeSpeechInputController alloc] initWithRuntime:requestRuntime];
        BOOL requestStarted = [requestController startWithTranscriptHandler:nil errorHandler:nil];
        AssertTrue(requestStarted, @"not-determined permissions can continue after grants");
        AssertTrue(requestRuntime.speechRequestCount == 1 && requestRuntime.microphoneRequestCount == 1,
                   @"not-determined path requests speech and microphone once");
        AssertTrue(requestRuntime.prepareCount == 1 && requestRuntime.startCount == 1 && requestController.isActive,
                   @"authorized permission flow prepares custom language model assets before recognition starts");

        FakeSpeechRuntime *heldPrepareRuntime = [[FakeSpeechRuntime alloc] init];
        heldPrepareRuntime.holdPrepareCompletion = YES;
        PurrTypeSpeechInputController *heldPrepareController = [[PurrTypeSpeechInputController alloc] initWithRuntime:heldPrepareRuntime];
        AssertTrue([heldPrepareController startWithLocaleSelectionIdentifier:@"zh-HK"
                                                           contextualStrings:@[@"PurrType", @"Apple Speech"]
                                                     transcriptUpdateHandler:nil
                                                                errorHandler:nil],
                   @"held prepare session enters start-in-progress state");
        AssertTrue(heldPrepareController.startInProgress && !heldPrepareController.isActive &&
                   heldPrepareRuntime.prepareCount == 1 && heldPrepareRuntime.startCount == 0,
                   @"recognition does not start until custom language model preparation completes");
        [heldPrepareController stop];
        if (heldPrepareRuntime.pendingPrepareCompletion) {
            heldPrepareRuntime.pendingPrepareCompletion();
        }
        AssertTrue(heldPrepareRuntime.startCount == 0 && !heldPrepareController.isActive,
                   @"stale custom language model prepare callbacks cannot start a stopped voice session");

        FakeSpeechRuntime *activeRuntime = [[FakeSpeechRuntime alloc] init];
        PurrTypeSpeechInputController *activeController = [[PurrTypeSpeechInputController alloc] initWithRuntime:activeRuntime];
        __block NSMutableArray<NSString *> *transcripts = [NSMutableArray array];
        BOOL activeStarted = [activeController startWithTranscriptHandler:^(NSString *transcript, BOOL isFinal) {
            [transcripts addObject:[NSString stringWithFormat:@"%@:%@", isFinal ? @"final" : @"partial", transcript]];
        } errorHandler:nil];
        AssertTrue(activeStarted && activeController.isActive, @"authorized controller starts active recognition");
        AssertTrue([activeRuntime.startedLocaleIdentifier isEqualToString:@"zh-HK"], @"start uses selected locale");
        activeRuntime.transcriptUpdateHandler(@"你好", @[], NO);
        AssertTrue(transcripts.count == 1 && [transcripts.firstObject isEqualToString:@"partial:你好"], @"partial transcript callback is forwarded");
        activeRuntime.transcriptUpdateHandler(@"你好世界", @[], YES);
        AssertTrue(transcripts.count == 2 && [transcripts.lastObject isEqualToString:@"final:你好世界"], @"final transcript callback is forwarded");
        AssertTrue(!activeController.isActive && activeRuntime.stopCount == 1, @"final transcript stops recognition");
        activeRuntime.transcriptUpdateHandler(@"重複", @[], YES);
        AssertTrue(transcripts.count == 2, @"transcripts after stop are ignored");
        [activeController stop];
        [activeController stop];
        AssertTrue(activeRuntime.stopCount == 1, @"stop is idempotent after final result");

        FakeSpeechRuntime *updateRuntime = [[FakeSpeechRuntime alloc] init];
        PurrTypeSpeechInputController *updateController = [[PurrTypeSpeechInputController alloc] initWithRuntime:updateRuntime];
        __block NSString *updatedTranscript = nil;
        __block NSArray<NSString *> *updatedAlternatives = nil;
        AssertTrue([updateController startWithLocaleSelectionIdentifier:@"zh-HK"
                                                      contextualStrings:@[]
                                                transcriptUpdateHandler:^(NSString *transcript, NSArray<NSString *> *alternativeTranscripts, BOOL isFinal) {
            (void)isFinal;
            updatedTranscript = transcript;
            updatedAlternatives = alternativeTranscripts;
        } errorHandler:nil], @"transcript update handler starts recognition");
        updateRuntime.transcriptUpdateHandler(@"測試文字", @[@"測試文子", @"測試文字"], NO);
        AssertTrue([updatedTranscript isEqualToString:@"測試文字"] &&
                   [updatedAlternatives isEqualToArray:@[@"測試文子", @"測試文字"]],
                   @"transcript update handler forwards alternatives");

        FakeSpeechRuntime *manualStopRuntime = [[FakeSpeechRuntime alloc] init];
        PurrTypeSpeechInputController *manualStopController = [[PurrTypeSpeechInputController alloc] initWithRuntime:manualStopRuntime];
        AssertTrue([manualStopController startWithTranscriptHandler:nil errorHandler:nil], @"manual stop test starts recognition");
        [manualStopController stop];
        [manualStopController stop];
        AssertTrue(manualStopRuntime.stopCount == 1 && !manualStopController.isActive, @"manual stop is idempotent");

        FakeSpeechRuntime *staleRuntime = [[FakeSpeechRuntime alloc] init];
        PurrTypeSpeechInputController *staleController = [[PurrTypeSpeechInputController alloc] initWithRuntime:staleRuntime];
        __block NSMutableArray<NSString *> *sessionScopedTranscripts = [NSMutableArray array];
        AssertTrue([staleController startWithLocaleSelectionIdentifier:@"zh-HK"
                                                     contextualStrings:@[]
                                               transcriptUpdateHandler:^(NSString *transcript, NSArray<NSString *> *alternativeTranscripts, BOOL isFinal) {
            (void)alternativeTranscripts;
            [sessionScopedTranscripts addObject:[NSString stringWithFormat:@"%@:%@", isFinal ? @"final" : @"partial", transcript]];
        } errorHandler:nil], @"first stale-session test starts recognition");
        PurrTypeSpeechInputTranscriptUpdateHandler staleTranscriptHandler = [staleRuntime.transcriptUpdateHandler copy];
        [staleController stop];
        AssertTrue([staleController startWithLocaleSelectionIdentifier:@"zh-HK"
                                                     contextualStrings:@[]
                                               transcriptUpdateHandler:^(NSString *transcript, NSArray<NSString *> *alternativeTranscripts, BOOL isFinal) {
            (void)alternativeTranscripts;
            [sessionScopedTranscripts addObject:[NSString stringWithFormat:@"%@:%@", isFinal ? @"final" : @"partial", transcript]];
        } errorHandler:nil], @"second stale-session test starts recognition");
        staleTranscriptHandler(@"上一段", @[], NO);
        AssertTrue(sessionScopedTranscripts.count == 0, @"stale transcript callbacks from a stopped voice session are ignored after restart");
        staleRuntime.transcriptUpdateHandler(@"新一段", @[], NO);
        AssertTrue(sessionScopedTranscripts.count == 1 && [sessionScopedTranscripts.firstObject isEqualToString:@"partial:新一段"],
                   @"current session transcript still reaches the handler after stale callback is ignored");
        [staleController stop];

        FakeSpeechRuntime *manualLocaleRuntime = [[FakeSpeechRuntime alloc] init];
        manualLocaleRuntime.supportedLocaleIdentifiers = [NSSet setWithArray:@[@"zh-HK", @"zh-TW"]];
        PurrTypeSpeechInputController *manualLocaleController = [[PurrTypeSpeechInputController alloc] initWithRuntime:manualLocaleRuntime];
        NSArray<NSString *> *contextualStrings = @[@"PurrType", @"香港", @"PurrType"];
        BOOL manualLocaleStarted = [manualLocaleController startWithLocaleSelectionIdentifier:@"zh-TW"
                                                                           contextualStrings:contextualStrings
                                                                           transcriptHandler:nil
                                                                                errorHandler:nil];
        AssertTrue(manualLocaleStarted, @"manual supported locale starts recognition");
        AssertTrue([manualLocaleRuntime.startedLocaleIdentifier isEqualToString:@"zh-TW"], @"manual supported locale is passed to runtime");
        AssertTrue([manualLocaleRuntime.startedContextualStrings isEqualToArray:@[@"PurrType", @"香港"]],
                   @"contextual strings are capped and de-duplicated before runtime start");

        NSMutableArray<NSString *> *manyPhrases = [NSMutableArray array];
        [manyPhrases addObject:@"# comment"];
        [manyPhrases addObject:@" "];
        for (NSUInteger index = 0; index < 105; index += 1) {
            [manyPhrases addObject:[NSString stringWithFormat:@"phrase-%03lu", (unsigned long)index]];
        }
        NSArray<NSString *> *cappedPhrases = [PurrTypeSpeechInputController cappedContextualStringsFromStrings:manyPhrases];
        AssertTrue(cappedPhrases.count == PurrTypeSpeechInputMaximumContextualPhraseCount,
                   @"contextual strings cap at the documented 100 phrase limit");
        AssertTrue([cappedPhrases.firstObject isEqualToString:@"phrase-000"] &&
                   [cappedPhrases.lastObject isEqualToString:@"phrase-099"],
                   @"contextual string cap preserves source order");

        NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
        NSURL *phraseURL = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"resources/cantonese_voice_contextual_phrases.txt"]];
        NSArray<NSString *> *resourcePhrases = [PurrTypeSpeechInputController contextualStringsFromResourceURL:phraseURL];
        AssertTrue(resourcePhrases.count > 0 && resourcePhrases.count <= PurrTypeSpeechInputMaximumContextualPhraseCount,
                   @"bundled contextual phrase resource loads within cap");
        AssertTrue([resourcePhrases containsObject:@"PurrType"] &&
                   [resourcePhrases containsObject:@"Cantonese Voice Input"] &&
                   [resourcePhrases containsObject:@"Apple Speech"] &&
                   [resourcePhrases containsObject:@"Privacy Lock"] &&
                   [resourcePhrases containsObject:@"香港"],
                   @"bundled contextual phrase resource includes product, user-facing feature, and Hong Kong terms");
        NSArray<NSString *> *combinedPhrases = [PurrTypeSpeechInputController contextualStringsFromBundle:nil
                                                                                         additionalStrings:@[@"用戶短語", @"用戶短語", @" "]];
        NSUInteger userPhraseCount = 0;
        for (NSString *phrase in combinedPhrases) {
            if ([phrase isEqualToString:@"用戶短語"]) {
                userPhraseCount += 1;
            }
        }
        AssertTrue(userPhraseCount == 1, @"contextual strings include short user lexical hints once");

        AssertTrue([[PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:nil] isEqualToString:@""],
                   @"nil voice transcript normalizes to empty string");
        AssertTrue([[PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:@"  你好 ， 世界  "] isEqualToString:@"你好，世界"],
                   @"voice transcript normalization trims and fixes Chinese punctuation spacing");
        AssertTrue([[PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:@"Hello   world , test"] isEqualToString:@"Hello world, test"],
                   @"voice transcript normalization collapses repeated whitespace and spacing before punctuation");
        AssertTrue([[PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:@"Purr Type 語音輸入"] isEqualToString:@"PurrType 語音輸入"],
                   @"voice transcript normalization applies tested product phrase replacement");
        AssertTrue([[PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:@"Cantonese Voice input"] isEqualToString:@"Cantonese Voice Input"],
                   @"voice transcript normalization applies stable product feature casing only");

        NSString *speechSource = FileTextAtPath([root stringByAppendingPathComponent:@"src/PurrTypeSpeechInputController.m"]);
        AssertTrue([speechSource containsString:@"PurrTypeSpeechInputMaximumAlternativeTranscriptCount"] &&
                   [speechSource containsString:@"for (SFTranscriptionSegment *segment in result.bestTranscription.segments ?: @[])"] &&
                   [speechSource containsString:@"segment.alternativeSubstrings"] &&
                   ![speechSource containsString:@"result.bestTranscription.segments.lastObject"],
                   @"Apple Speech segment alternatives are collected across the utterance instead of only the last segment");
        AssertTrue([speechSource containsString:@"prepareCustomLanguageModelForUrl:assetURL"] &&
                   [speechSource containsString:@"customizedLanguageModel"] &&
                   ![speechSource containsString:@"requiresOnDeviceRecognition = YES"] &&
                   [speechSource containsString:@"PurrTypeSpeechInputCustomLanguageModelLocaleIdentifier"],
                   @"Apple Speech can attach a prepared zh-HK custom language model without forcing the lower-accuracy on-device path");

        NSLog(@"PASS: PurrTypeSpeechInputControllerTests");
    }
    return 0;
}
