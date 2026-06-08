#import "PurrTypeSpeechInputController.h"
#import "PurrTypePreferencesConstants.h"
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>

NSErrorDomain const PurrTypeSpeechInputErrorDomain = @"org.purrtype.inputmethod.PurrType.SpeechInput";
NSErrorUserInfoKey const PurrTypeSpeechInputErrorLocaleIdentifierKey = @"PurrTypeSpeechInputLocaleIdentifier";
NSUInteger const PurrTypeSpeechInputMaximumContextualPhraseCount = 100;

static NSString *const PurrTypeSpeechInputErrorPermissionStatusKey = @"PurrTypeSpeechInputPermissionStatus";
static NSString *const PurrTypeSpeechInputContextualPhrasesResourceName = @"cantonese_voice_contextual_phrases";
static NSString *const PurrTypeSpeechInputContextualPhrasesResourceExtension = @"txt";
static NSString *const PurrTypeSpeechInputCustomLanguageModelResourceName = @"cantonese_voice_language_model_zh-HK";
static NSString *const PurrTypeSpeechInputCustomLanguageModelResourceExtension = @"bin";
static NSString *const PurrTypeSpeechInputCustomLanguageModelLocaleIdentifier = @"zh-HK";
static NSString *const PurrTypeSpeechInputCustomLanguageModelCacheVersion = @"v1";
static NSUInteger const PurrTypeSpeechInputMaximumAlternativeTranscriptCount = 24;

static NSString *PurrTypeCanonicalLocaleIdentifier(NSString *identifier) {
    return [[[identifier ?: @"" stringByReplacingOccurrencesOfString:@"_" withString:@"-"] lowercaseString] copy];
}

static NSString *PurrTypeStringByReplacingRegularExpression(NSString *input, NSString *pattern, NSString *template) {
    if (input.length == 0 || pattern.length == 0) {
        return input ?: @"";
    }
    NSError *error = nil;
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    if (!expression) {
        return input;
    }
    NSRange range = NSMakeRange(0, input.length);
    return [expression stringByReplacingMatchesInString:input options:0 range:range withTemplate:template ?: @""];
}

static NSError *PurrTypeSpeechInputError(PurrTypeSpeechInputErrorCode code, NSString *description, NSDictionary<NSErrorUserInfoKey, id> *extraUserInfo) {
    NSMutableDictionary<NSErrorUserInfoKey, id> *userInfo = [NSMutableDictionary dictionary];
    if (description.length > 0) {
        userInfo[NSLocalizedDescriptionKey] = description;
    }
    [userInfo addEntriesFromDictionary:extraUserInfo ?: @{}];
    return [NSError errorWithDomain:PurrTypeSpeechInputErrorDomain code:code userInfo:userInfo];
}

static NSString *PurrTypeSpeechInputPermissionStatusDescription(PurrTypeSpeechInputPermissionStatus status) {
    switch (status) {
        case PurrTypeSpeechInputPermissionStatusNotDetermined:
            return @"notDetermined";
        case PurrTypeSpeechInputPermissionStatusDenied:
            return @"denied";
        case PurrTypeSpeechInputPermissionStatusRestricted:
            return @"restricted";
        case PurrTypeSpeechInputPermissionStatusAuthorized:
            return @"authorized";
    }
}

@interface PurrTypeDefaultSpeechInputRuntime : NSObject <PurrTypeSpeechInputRuntime>

@property(nonatomic, strong) SFSpeechRecognizer *recognizer;
@property(nonatomic, strong) AVAudioEngine *audioEngine;
@property(nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property(nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property(nonatomic, strong) id preparedCustomLanguageModelConfiguration;
@property(nonatomic, copy) NSString *preparedCustomLanguageModelLocaleIdentifier;
@property(nonatomic, assign) BOOL tapInstalled;
@property(nonatomic, assign) NSUInteger customLanguageModelPrepareSerial;

@end

@implementation PurrTypeDefaultSpeechInputRuntime

- (NSSet<NSString *> *)supportedLocaleIdentifiers {
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (NSLocale *locale in [SFSpeechRecognizer supportedLocales]) {
        if (locale.localeIdentifier.length > 0) {
            [identifiers addObject:locale.localeIdentifier];
        }
    }
    return [identifiers copy];
}

- (PurrTypeSpeechInputPermissionStatus)speechAuthorizationStatus {
    switch ([SFSpeechRecognizer authorizationStatus]) {
        case SFSpeechRecognizerAuthorizationStatusNotDetermined:
            return PurrTypeSpeechInputPermissionStatusNotDetermined;
        case SFSpeechRecognizerAuthorizationStatusDenied:
            return PurrTypeSpeechInputPermissionStatusDenied;
        case SFSpeechRecognizerAuthorizationStatusRestricted:
            return PurrTypeSpeechInputPermissionStatusRestricted;
        case SFSpeechRecognizerAuthorizationStatusAuthorized:
            return PurrTypeSpeechInputPermissionStatusAuthorized;
    }
}

- (void)requestSpeechAuthorizationWithCompletion:(void (^)(PurrTypeSpeechInputPermissionStatus status))completion {
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        PurrTypeSpeechInputPermissionStatus mappedStatus = PurrTypeSpeechInputPermissionStatusDenied;
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                mappedStatus = PurrTypeSpeechInputPermissionStatusNotDetermined;
                break;
            case SFSpeechRecognizerAuthorizationStatusDenied:
                mappedStatus = PurrTypeSpeechInputPermissionStatusDenied;
                break;
            case SFSpeechRecognizerAuthorizationStatusRestricted:
                mappedStatus = PurrTypeSpeechInputPermissionStatusRestricted;
                break;
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
                mappedStatus = PurrTypeSpeechInputPermissionStatusAuthorized;
                break;
        }
        if (completion) {
            completion(mappedStatus);
        }
    }];
}

- (PurrTypeSpeechInputPermissionStatus)microphoneAuthorizationStatus {
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
        case AVAuthorizationStatusNotDetermined:
            return PurrTypeSpeechInputPermissionStatusNotDetermined;
        case AVAuthorizationStatusRestricted:
            return PurrTypeSpeechInputPermissionStatusRestricted;
        case AVAuthorizationStatusDenied:
            return PurrTypeSpeechInputPermissionStatusDenied;
        case AVAuthorizationStatusAuthorized:
            return PurrTypeSpeechInputPermissionStatusAuthorized;
    }
}

- (void)requestMicrophoneAuthorizationWithCompletion:(void (^)(PurrTypeSpeechInputPermissionStatus status))completion {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
        if (completion) {
            completion(granted ? PurrTypeSpeechInputPermissionStatusAuthorized : PurrTypeSpeechInputPermissionStatusDenied);
        }
    }];
}

- (NSURL *)customLanguageModelCacheDirectoryURL {
    NSURL *cachesURL = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    if (!cachesURL) {
        return nil;
    }
    return [[cachesURL URLByAppendingPathComponent:@"PurrType" isDirectory:YES]
                      URLByAppendingPathComponent:@"SpeechLanguageModels" isDirectory:YES];
}

- (BOOL)isUsableCustomLanguageModelConfiguration:(SFSpeechLanguageModelConfiguration *)configuration API_AVAILABLE(macos(14.0)) {
    if (!configuration) {
        return NO;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSNumber *languageModelSize = nil;
    NSNumber *vocabularySize = nil;
    NSDictionary<NSFileAttributeKey, id> *languageModelAttributes = [fileManager attributesOfItemAtPath:configuration.languageModel.path error:nil];
    NSDictionary<NSFileAttributeKey, id> *vocabularyAttributes = [fileManager attributesOfItemAtPath:configuration.vocabulary.path error:nil];
    languageModelSize = languageModelAttributes[NSFileSize];
    vocabularySize = vocabularyAttributes[NSFileSize];
    return languageModelSize.unsignedLongLongValue > 0 && vocabularySize.unsignedLongLongValue > 0;
}

- (void)prepareAudioRecognitionWithLocaleIdentifier:(NSString *)localeIdentifier
                                  contextualStrings:(NSArray<NSString *> *)contextualStrings
                                         completion:(void (^)(void))completion {
    (void)contextualStrings;
    self.customLanguageModelPrepareSerial += 1;
    NSUInteger serial = self.customLanguageModelPrepareSerial;
    self.preparedCustomLanguageModelConfiguration = nil;
    self.preparedCustomLanguageModelLocaleIdentifier = nil;

    void (^finish)(void) = ^{
        if (!completion) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    };

    if (![PurrTypeCanonicalLocaleIdentifier(localeIdentifier) isEqualToString:PurrTypeCanonicalLocaleIdentifier(PurrTypeSpeechInputCustomLanguageModelLocaleIdentifier)]) {
        finish();
        return;
    }

    if (@available(macOS 14.0, *)) {
        NSURL *assetURL = [[NSBundle mainBundle] URLForResource:PurrTypeSpeechInputCustomLanguageModelResourceName
                                                  withExtension:PurrTypeSpeechInputCustomLanguageModelResourceExtension];
        if (!assetURL) {
            finish();
            return;
        }

        NSURL *cacheDirectoryURL = [self customLanguageModelCacheDirectoryURL];
        if (!cacheDirectoryURL) {
            finish();
            return;
        }

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *directoryError = nil;
        if (![fileManager createDirectoryAtURL:cacheDirectoryURL
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&directoryError]) {
            finish();
            return;
        }

        NSString *baseName = [NSString stringWithFormat:@"cantonese-voice-%@-%@",
                                                        PurrTypeSpeechInputCustomLanguageModelLocaleIdentifier,
                                                        PurrTypeSpeechInputCustomLanguageModelCacheVersion];
        NSURL *languageModelURL = [cacheDirectoryURL URLByAppendingPathComponent:[baseName stringByAppendingPathExtension:@"lm"]];
        NSURL *vocabularyURL = [cacheDirectoryURL URLByAppendingPathComponent:[baseName stringByAppendingPathExtension:@"vocab"]];
        SFSpeechLanguageModelConfiguration *configuration = [[SFSpeechLanguageModelConfiguration alloc] initWithLanguageModel:languageModelURL
                                                                                                                   vocabulary:vocabularyURL];

        if ([self isUsableCustomLanguageModelConfiguration:configuration]) {
            if (serial == self.customLanguageModelPrepareSerial) {
                self.preparedCustomLanguageModelConfiguration = configuration;
                self.preparedCustomLanguageModelLocaleIdentifier = localeIdentifier ?: @"";
            }
            finish();
            return;
        }

        NSString *clientIdentifier = [NSBundle mainBundle].bundleIdentifier ?: @"org.purrtype.inputmethod.PurrType";
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [SFSpeechLanguageModel prepareCustomLanguageModelForUrl:assetURL
                                               clientIdentifier:clientIdentifier
                                                  configuration:configuration
                                                     completion:^(NSError * _Nullable error) {
            if (serial != self.customLanguageModelPrepareSerial) {
                finish();
                return;
            }
            if (!error && [self isUsableCustomLanguageModelConfiguration:configuration]) {
                self.preparedCustomLanguageModelConfiguration = configuration;
                self.preparedCustomLanguageModelLocaleIdentifier = localeIdentifier ?: @"";
            }
            finish();
        }];
#pragma clang diagnostic pop
        return;
    }

    finish();
}

- (BOOL)startAudioRecognitionWithLocaleIdentifier:(NSString *)localeIdentifier
                                contextualStrings:(NSArray<NSString *> *)contextualStrings
                          transcriptUpdateHandler:(PurrTypeSpeechInputTranscriptUpdateHandler)transcriptUpdateHandler
                                     errorHandler:(PurrTypeSpeechInputErrorHandler)errorHandler
                                            error:(NSError **)error {
    [self stopAudioRecognition];

    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:localeIdentifier ?: @""];
    self.recognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
    if (!self.recognizer || !self.recognizer.isAvailable) {
        if (error) {
            *error = PurrTypeSpeechInputError(PurrTypeSpeechInputErrorRecognizerUnavailable,
                                              @"Voice recognition is not currently available for the selected locale.",
                                              @{ PurrTypeSpeechInputErrorLocaleIdentifierKey: localeIdentifier ?: @"" });
        }
        return NO;
    }

    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    self.recognitionRequest.shouldReportPartialResults = YES;
    self.recognitionRequest.taskHint = SFSpeechRecognitionTaskHintDictation;
    self.recognitionRequest.contextualStrings = contextualStrings ?: @[];
    if (@available(macOS 14.0, *)) {
        if ([PurrTypeCanonicalLocaleIdentifier(self.preparedCustomLanguageModelLocaleIdentifier) isEqualToString:PurrTypeCanonicalLocaleIdentifier(localeIdentifier)] &&
            [self.preparedCustomLanguageModelConfiguration isKindOfClass:[SFSpeechLanguageModelConfiguration class]]) {
            self.recognitionRequest.customizedLanguageModel = (SFSpeechLanguageModelConfiguration *)self.preparedCustomLanguageModelConfiguration;
        }
    }

    __weak PurrTypeDefaultSpeechInputRuntime *weakSelf = self;
    self.recognitionTask = [self.recognizer recognitionTaskWithRequest:self.recognitionRequest
                                                         resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable recognitionError) {
        if (result) {
            NSString *transcript = result.bestTranscription.formattedString ?: @"";
            if (transcriptUpdateHandler) {
                transcriptUpdateHandler(transcript, [weakSelf alternativeTranscriptStringsForResult:result bestTranscript:transcript], result.isFinal);
            }
        }
        if (recognitionError) {
            if (errorHandler) {
                errorHandler(PurrTypeSpeechInputError(PurrTypeSpeechInputErrorRecognitionFailed,
                                                      recognitionError.localizedDescription ?: @"Speech recognition failed.",
                                                      @{ NSUnderlyingErrorKey: recognitionError }));
            }
            [weakSelf stopAudioRecognition];
        }
    }];

    self.audioEngine = [[AVAudioEngine alloc] init];
    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    AVAudioFormat *format = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0
                    bufferSize:8192
                        format:format
                         block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        (void)when;
        [weakSelf.recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    self.tapInstalled = YES;

    NSError *startError = nil;
    if (![self.audioEngine startAndReturnError:&startError]) {
        [self stopAudioRecognition];
        if (error) {
            *error = PurrTypeSpeechInputError(PurrTypeSpeechInputErrorAudioStartFailed,
                                              startError.localizedDescription ?: @"Microphone capture could not start.",
                                              startError ? @{ NSUnderlyingErrorKey: startError } : @{});
        }
        return NO;
    }

    return YES;
}

- (NSArray<NSString *> *)alternativeTranscriptStringsForResult:(SFSpeechRecognitionResult *)result
                                                bestTranscript:(NSString *)bestTranscript {
    NSMutableArray<NSString *> *alternatives = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    void (^addAlternative)(NSString *) = ^(NSString *candidate) {
        NSString *text = candidate ?: @"";
        if (text.length == 0 ||
            alternatives.count >= PurrTypeSpeechInputMaximumAlternativeTranscriptCount ||
            [seen containsObject:text]) {
            return;
        }
        [seen addObject:text];
        [alternatives addObject:text];
    };

    for (SFTranscription *transcription in result.transcriptions ?: @[]) {
        addAlternative(transcription.formattedString);
        if (alternatives.count >= PurrTypeSpeechInputMaximumAlternativeTranscriptCount) {
            break;
        }
    }

    for (SFTranscriptionSegment *segment in result.bestTranscription.segments ?: @[]) {
        if (alternatives.count >= PurrTypeSpeechInputMaximumAlternativeTranscriptCount ||
            segment.substringRange.location == NSNotFound ||
            segment.substringRange.length == 0 ||
            NSMaxRange(segment.substringRange) > bestTranscript.length) {
            continue;
        }
        for (NSString *alternativeSubstring in segment.alternativeSubstrings ?: @[]) {
            if (alternativeSubstring.length == 0 || [alternativeSubstring isEqualToString:segment.substring ?: @""]) {
                continue;
            }
            NSMutableString *candidate = [bestTranscript mutableCopy];
            [candidate replaceCharactersInRange:segment.substringRange withString:alternativeSubstring];
            addAlternative(candidate);
            if (alternatives.count >= PurrTypeSpeechInputMaximumAlternativeTranscriptCount) {
                break;
            }
        }
    }

    return [alternatives copy];
}

- (void)stopAudioRecognition {
    self.customLanguageModelPrepareSerial += 1;
    if (self.tapInstalled && self.audioEngine) {
        [self.audioEngine.inputNode removeTapOnBus:0];
        self.tapInstalled = NO;
    }
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
    }
    [self.recognitionRequest endAudio];
    [self.recognitionTask cancel];
    self.recognitionTask = nil;
    self.recognitionRequest = nil;
    self.audioEngine = nil;
    self.recognizer = nil;
}

@end

@interface PurrTypeSpeechInputController ()

@property(nonatomic, strong) id<PurrTypeSpeechInputRuntime> runtime;
@property(nonatomic, readwrite, getter=isActive) BOOL active;
@property(nonatomic, readwrite) BOOL startInProgress;
@property(nonatomic, readwrite, copy, nullable) NSString *activeLocaleIdentifier;
@property(nonatomic, readwrite, copy, nullable) NSString *activeLocaleSelectionIdentifier;
@property(nonatomic, readwrite, strong, nullable) NSError *lastError;
@property(nonatomic, copy, nullable) PurrTypeSpeechInputTranscriptUpdateHandler transcriptUpdateHandler;
@property(nonatomic, copy, nullable) PurrTypeSpeechInputErrorHandler errorHandler;
@property(nonatomic, copy) NSArray<NSString *> *contextualStrings;
@property(nonatomic, copy, nullable) NSString *currentSessionIdentifier;

- (BOOL)beginPreparedAudioRecognitionForSessionIdentifier:(NSString *)sessionIdentifier;

@end

@implementation PurrTypeSpeechInputController

- (instancetype)init {
    return [self initWithRuntime:[[PurrTypeDefaultSpeechInputRuntime alloc] init]];
}

- (instancetype)initWithRuntime:(id<PurrTypeSpeechInputRuntime>)runtime {
    self = [super init];
    if (self) {
        _runtime = runtime;
        _contextualStrings = @[];
    }
    return self;
}

+ (NSArray<NSString *> *)preferredLocaleIdentifiers {
    return @[
        MKVoiceRecognitionLocaleZhHK,
        MKVoiceRecognitionLocaleZhTW
    ];
}

+ (NSArray<NSString *> *)selectableLocaleSelectionIdentifiers {
    return @[ MKVoiceRecognitionLocaleAuto,
              MKVoiceRecognitionLocaleZhHK,
              MKVoiceRecognitionLocaleZhTW ];
}

+ (NSString *)normalizedLocaleSelectionIdentifier:(NSString *)localeSelectionIdentifier {
    NSString *canonical = PurrTypeCanonicalLocaleIdentifier(localeSelectionIdentifier);
    if ([canonical isEqualToString:PurrTypeCanonicalLocaleIdentifier(MKVoiceRecognitionLocaleZhHK)]) {
        return MKVoiceRecognitionLocaleZhHK;
    }
    if ([canonical isEqualToString:PurrTypeCanonicalLocaleIdentifier(MKVoiceRecognitionLocaleZhTW)]) {
        return MKVoiceRecognitionLocaleZhTW;
    }
    return MKVoiceRecognitionLocaleAuto;
}

+ (nullable NSString *)selectedLocaleIdentifierFromSupportedLocaleIdentifiers:(NSSet<NSString *> *)supportedLocaleIdentifiers {
    return [self selectedLocaleIdentifierFromSupportedLocaleIdentifiers:supportedLocaleIdentifiers
                                              localeSelectionIdentifier:MKVoiceRecognitionLocaleAuto];
}

+ (nullable NSString *)selectedLocaleIdentifierFromSupportedLocaleIdentifiers:(NSSet<NSString *> *)supportedLocaleIdentifiers
                                                    localeSelectionIdentifier:(NSString *)localeSelectionIdentifier {
    NSMutableSet<NSString *> *canonicalSupported = [NSMutableSet setWithCapacity:supportedLocaleIdentifiers.count];
    for (NSString *identifier in supportedLocaleIdentifiers) {
        NSString *canonical = PurrTypeCanonicalLocaleIdentifier(identifier);
        if (canonical.length > 0) {
            [canonicalSupported addObject:canonical];
        }
    }

    NSString *normalizedSelection = [self normalizedLocaleSelectionIdentifier:localeSelectionIdentifier];
    if (![normalizedSelection isEqualToString:MKVoiceRecognitionLocaleAuto]) {
        return [canonicalSupported containsObject:PurrTypeCanonicalLocaleIdentifier(normalizedSelection)] ? normalizedSelection : nil;
    }

    for (NSString *preferredIdentifier in [self preferredLocaleIdentifiers]) {
        if ([canonicalSupported containsObject:PurrTypeCanonicalLocaleIdentifier(preferredIdentifier)]) {
            return preferredIdentifier;
        }
    }
    return nil;
}

+ (NSArray<NSString *> *)contextualStringsFromBundle:(NSBundle *)bundle {
    NSBundle *sourceBundle = bundle ?: [NSBundle mainBundle];
    NSURL *resourceURL = [sourceBundle URLForResource:PurrTypeSpeechInputContextualPhrasesResourceName
                                        withExtension:PurrTypeSpeechInputContextualPhrasesResourceExtension];
    return [self contextualStringsFromResourceURL:resourceURL];
}

+ (NSArray<NSString *> *)contextualStringsFromBundle:(NSBundle *)bundle
                                   additionalStrings:(NSArray<NSString *> *)additionalStrings {
    NSMutableArray<NSString *> *strings = [[self contextualStringsFromBundle:bundle] mutableCopy];
    [strings addObjectsFromArray:additionalStrings ?: @[]];
    return [self cappedContextualStringsFromStrings:strings ?: @[]];
}

+ (NSArray<NSString *> *)contextualStringsFromResourceURL:(NSURL *)resourceURL {
    if (!resourceURL) {
        return @[];
    }
    NSError *error = nil;
    NSString *contents = [NSString stringWithContentsOfURL:resourceURL encoding:NSUTF8StringEncoding error:&error];
    if (contents.length == 0) {
        return @[];
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [contents enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        (void)stop;
        [lines addObject:line ?: @""];
    }];
    return [self cappedContextualStringsFromStrings:lines];
}

+ (NSArray<NSString *> *)cappedContextualStringsFromStrings:(NSArray<NSString *> *)strings {
    NSMutableArray<NSString *> *phrases = [NSMutableArray arrayWithCapacity:MIN(strings.count, PurrTypeSpeechInputMaximumContextualPhraseCount)];
    NSMutableSet<NSString *> *seenPhrases = [NSMutableSet set];
    NSCharacterSet *trimSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSString *rawPhrase in strings) {
        if (![rawPhrase isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *phrase = [rawPhrase stringByTrimmingCharactersInSet:trimSet];
        if (phrase.length == 0 || [phrase hasPrefix:@"#"] || [seenPhrases containsObject:phrase]) {
            continue;
        }
        [phrases addObject:phrase];
        [seenPhrases addObject:phrase];
        if (phrases.count >= PurrTypeSpeechInputMaximumContextualPhraseCount) {
            break;
        }
    }
    return [phrases copy];
}

+ (NSString *)normalizedVoiceTranscriptForVoiceInput:(NSString *)transcript {
    NSString *normalized = [transcript ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (normalized.length == 0) {
        return @"";
    }

    normalized = PurrTypeStringByReplacingRegularExpression(normalized, @"\\s+", @" ");
    normalized = PurrTypeStringByReplacingRegularExpression(normalized, @"(?i)\\bPurr\\s+Type\\b", @"PurrType");
    normalized = PurrTypeStringByReplacingRegularExpression(normalized, @"(?i)\\bCantonese\\s+Voice\\s+input\\b", @"Cantonese Voice Input");
    normalized = PurrTypeStringByReplacingRegularExpression(normalized, @"\\s+([,.;:!?，。！？；：、）」』》】])", @"$1");
    normalized = PurrTypeStringByReplacingRegularExpression(normalized, @"([（「『《【])\\s+", @"$1");
    normalized = PurrTypeStringByReplacingRegularExpression(normalized, @"([，。！？；：、])\\s+([\\p{Han}])", @"$1$2");
    return [normalized stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)startWithTranscriptHandler:(PurrTypeSpeechInputTranscriptHandler)transcriptHandler
                      errorHandler:(PurrTypeSpeechInputErrorHandler)errorHandler {
    return [self startWithLocaleSelectionIdentifier:MKVoiceRecognitionLocaleAuto
                                 contextualStrings:[[self class] contextualStringsFromBundle:[NSBundle mainBundle]]
                                 transcriptHandler:transcriptHandler
                                      errorHandler:errorHandler];
}

- (BOOL)startWithLocaleSelectionIdentifier:(NSString *)localeSelectionIdentifier
                         contextualStrings:(NSArray<NSString *> *)contextualStrings
                         transcriptHandler:(PurrTypeSpeechInputTranscriptHandler)transcriptHandler
                              errorHandler:(PurrTypeSpeechInputErrorHandler)errorHandler {
    PurrTypeSpeechInputTranscriptUpdateHandler updateHandler = nil;
    if (transcriptHandler) {
        updateHandler = ^(NSString *transcript, NSArray<NSString *> *alternativeTranscripts, BOOL isFinal) {
            (void)alternativeTranscripts;
            transcriptHandler(transcript, isFinal);
        };
    }
    return [self startWithLocaleSelectionIdentifier:localeSelectionIdentifier
                                 contextualStrings:contextualStrings
                           transcriptUpdateHandler:updateHandler
                                      errorHandler:errorHandler];
}

- (BOOL)startWithLocaleSelectionIdentifier:(NSString *)localeSelectionIdentifier
                         contextualStrings:(NSArray<NSString *> *)contextualStrings
                   transcriptUpdateHandler:(PurrTypeSpeechInputTranscriptUpdateHandler)transcriptUpdateHandler
                              errorHandler:(PurrTypeSpeechInputErrorHandler)errorHandler {
    if (self.active || self.startInProgress) {
        [self reportImmediateError:PurrTypeSpeechInputError(PurrTypeSpeechInputErrorAlreadyActive,
                                                            @"Cantonese voice input is already active.",
                                                            @{})
                      errorHandler:errorHandler];
        return NO;
    }

    NSString *normalizedLocaleSelection = [[self class] normalizedLocaleSelectionIdentifier:localeSelectionIdentifier];
    NSString *localeIdentifier = [[self class] selectedLocaleIdentifierFromSupportedLocaleIdentifiers:[self.runtime supportedLocaleIdentifiers]
                                                                            localeSelectionIdentifier:normalizedLocaleSelection];
    if (localeIdentifier.length == 0) {
        NSString *description = [normalizedLocaleSelection isEqualToString:MKVoiceRecognitionLocaleAuto] ?
            @"No supported Cantonese or Chinese speech recognition locale is available." :
            [NSString stringWithFormat:@"Selected voice recognition locale is not supported: %@.", normalizedLocaleSelection];
        [self reportImmediateError:PurrTypeSpeechInputError(PurrTypeSpeechInputErrorUnsupportedLocale,
                                                            description,
                                                            @{ PurrTypeSpeechInputErrorLocaleIdentifierKey: normalizedLocaleSelection })
                      errorHandler:errorHandler];
        return NO;
    }

    self.lastError = nil;
    self.activeLocaleIdentifier = localeIdentifier;
    self.activeLocaleSelectionIdentifier = normalizedLocaleSelection;
    self.contextualStrings = [[self class] cappedContextualStringsFromStrings:contextualStrings ?: @[]];
    self.transcriptUpdateHandler = transcriptUpdateHandler;
    self.errorHandler = errorHandler;
    self.currentSessionIdentifier = [NSUUID UUID].UUIDString;
    self.startInProgress = YES;

    return [self continueStartAfterSpeechAuthorizationStatus:[self.runtime speechAuthorizationStatus]
                                           sessionIdentifier:self.currentSessionIdentifier];
}

- (BOOL)continueStartAfterSpeechAuthorizationStatus:(PurrTypeSpeechInputPermissionStatus)status
                                  sessionIdentifier:(NSString *)sessionIdentifier {
    if (!self.startInProgress || ![self isCurrentSessionIdentifier:sessionIdentifier]) {
        return NO;
    }

    if (status == PurrTypeSpeechInputPermissionStatusNotDetermined) {
        __weak PurrTypeSpeechInputController *weakSelf = self;
        NSString *activeSessionIdentifier = [sessionIdentifier copy];
        [self.runtime requestSpeechAuthorizationWithCompletion:^(PurrTypeSpeechInputPermissionStatus nextStatus) {
            [weakSelf runOnMainQueue:^{
                [weakSelf continueStartAfterSpeechAuthorizationStatus:nextStatus
                                                    sessionIdentifier:activeSessionIdentifier];
            }];
        }];
        return YES;
    }

    if (status != PurrTypeSpeechInputPermissionStatusAuthorized) {
        [self failWithError:[self permissionErrorWithCode:PurrTypeSpeechInputErrorSpeechPermissionDenied
                                              description:@"Speech recognition permission was denied or restricted."
                                                   status:status]
            stopRuntime:NO];
        return NO;
    }

    return [self continueStartAfterMicrophoneAuthorizationStatus:[self.runtime microphoneAuthorizationStatus]
                                              sessionIdentifier:sessionIdentifier];
}

- (BOOL)continueStartAfterMicrophoneAuthorizationStatus:(PurrTypeSpeechInputPermissionStatus)status
                                      sessionIdentifier:(NSString *)sessionIdentifier {
    if (!self.startInProgress || ![self isCurrentSessionIdentifier:sessionIdentifier]) {
        return NO;
    }

    if (status == PurrTypeSpeechInputPermissionStatusNotDetermined) {
        __weak PurrTypeSpeechInputController *weakSelf = self;
        NSString *activeSessionIdentifier = [sessionIdentifier copy];
        [self.runtime requestMicrophoneAuthorizationWithCompletion:^(PurrTypeSpeechInputPermissionStatus nextStatus) {
            [weakSelf runOnMainQueue:^{
                [weakSelf continueStartAfterMicrophoneAuthorizationStatus:nextStatus
                                                        sessionIdentifier:activeSessionIdentifier];
            }];
        }];
        return YES;
    }

    if (status != PurrTypeSpeechInputPermissionStatusAuthorized) {
        [self failWithError:[self permissionErrorWithCode:PurrTypeSpeechInputErrorMicrophonePermissionDenied
                                              description:@"Microphone permission was denied or restricted."
                                                   status:status]
            stopRuntime:NO];
        return NO;
    }

    return [self beginAudioRecognitionForSessionIdentifier:sessionIdentifier];
}

- (BOOL)beginAudioRecognitionForSessionIdentifier:(NSString *)sessionIdentifier {
    if (![self isCurrentSessionIdentifier:sessionIdentifier]) {
        return NO;
    }

    __weak PurrTypeSpeechInputController *weakSelf = self;
    NSString *activeSessionIdentifier = [sessionIdentifier copy];
    [self.runtime prepareAudioRecognitionWithLocaleIdentifier:self.activeLocaleIdentifier ?: @""
                                            contextualStrings:self.contextualStrings ?: @[]
                                                   completion:^{
        [weakSelf runOnMainQueue:^{
            [weakSelf beginPreparedAudioRecognitionForSessionIdentifier:activeSessionIdentifier];
        }];
    }];
    return YES;
}

- (BOOL)beginPreparedAudioRecognitionForSessionIdentifier:(NSString *)sessionIdentifier {
    if (![self isCurrentSessionIdentifier:sessionIdentifier]) {
        return NO;
    }

    NSError *startError = nil;
    __weak PurrTypeSpeechInputController *weakSelf = self;
    NSString *activeSessionIdentifier = [sessionIdentifier copy];
    BOOL started = [self.runtime startAudioRecognitionWithLocaleIdentifier:self.activeLocaleIdentifier ?: @""
                                                         contextualStrings:self.contextualStrings ?: @[]
                                                   transcriptUpdateHandler:^(NSString *transcript, NSArray<NSString *> *alternativeTranscripts, BOOL isFinal) {
        [weakSelf handleTranscript:transcript
             alternativeTranscripts:alternativeTranscripts
                            isFinal:isFinal
                  sessionIdentifier:activeSessionIdentifier];
    }
                                                              errorHandler:^(NSError *error) {
        [weakSelf handleRuntimeError:error sessionIdentifier:activeSessionIdentifier];
    }
                                                                     error:&startError];
    if (!started) {
        [self failWithError:startError ?: PurrTypeSpeechInputError(PurrTypeSpeechInputErrorAudioStartFailed,
                                                                   @"Microphone capture could not start.",
                                                                   @{})
            stopRuntime:YES];
        return NO;
    }

    self.active = YES;
    self.startInProgress = NO;
    return YES;
}

- (void)handleTranscript:(NSString *)transcript
  alternativeTranscripts:(NSArray<NSString *> *)alternativeTranscripts
                 isFinal:(BOOL)isFinal
       sessionIdentifier:(NSString *)sessionIdentifier {
    [self runOnMainQueue:^{
        if (!self.active || ![self isCurrentSessionIdentifier:sessionIdentifier]) {
            return;
        }
        PurrTypeSpeechInputTranscriptUpdateHandler handler = self.transcriptUpdateHandler;
        if (handler) {
            handler(transcript ?: @"", alternativeTranscripts ?: @[], isFinal);
        }
        if (isFinal) {
            [self stop];
        }
    }];
}

- (void)handleRuntimeError:(NSError *)error sessionIdentifier:(NSString *)sessionIdentifier {
    [self runOnMainQueue:^{
        if ((!self.active && !self.startInProgress) || ![self isCurrentSessionIdentifier:sessionIdentifier]) {
            return;
        }
        [self failWithError:error ?: PurrTypeSpeechInputError(PurrTypeSpeechInputErrorRecognitionFailed,
                                                              @"Speech recognition failed.",
                                                              @{})
            stopRuntime:YES];
    }];
}

- (void)stop {
    BOOL shouldStopRuntime = self.active;
    self.active = NO;
    self.startInProgress = NO;
    self.activeLocaleIdentifier = nil;
    self.activeLocaleSelectionIdentifier = nil;
    self.contextualStrings = @[];
    self.currentSessionIdentifier = nil;
    self.transcriptUpdateHandler = nil;
    self.errorHandler = nil;

    if (shouldStopRuntime) {
        [self.runtime stopAudioRecognition];
    }
}

- (void)failWithError:(NSError *)error stopRuntime:(BOOL)stopRuntime {
    self.lastError = error;
    BOOL hadRuntime = self.active || self.startInProgress;
    self.active = NO;
    self.startInProgress = NO;
    self.activeLocaleIdentifier = nil;
    self.activeLocaleSelectionIdentifier = nil;
    self.contextualStrings = @[];
    self.currentSessionIdentifier = nil;

    if (stopRuntime && hadRuntime) {
        [self.runtime stopAudioRecognition];
    }

    PurrTypeSpeechInputErrorHandler handler = self.errorHandler;
    self.transcriptUpdateHandler = nil;
    self.errorHandler = nil;
    if (handler) {
        handler(error);
    }
}

- (void)reportImmediateError:(NSError *)error errorHandler:(PurrTypeSpeechInputErrorHandler)errorHandler {
    self.lastError = error;
    if (errorHandler) {
        errorHandler(error);
    }
}

- (BOOL)isCurrentSessionIdentifier:(NSString *)sessionIdentifier {
    return sessionIdentifier.length > 0 && [self.currentSessionIdentifier isEqualToString:sessionIdentifier];
}

- (NSError *)permissionErrorWithCode:(PurrTypeSpeechInputErrorCode)code
                         description:(NSString *)description
                              status:(PurrTypeSpeechInputPermissionStatus)status {
    return PurrTypeSpeechInputError(code,
                                    description,
                                    @{ PurrTypeSpeechInputErrorPermissionStatusKey: PurrTypeSpeechInputPermissionStatusDescription(status) });
}

- (void)runOnMainQueue:(dispatch_block_t)block {
    if (!block) {
        return;
    }
    if ([NSThread isMainThread]) {
        block();
        return;
    }
    dispatch_async(dispatch_get_main_queue(), block);
}

@end
