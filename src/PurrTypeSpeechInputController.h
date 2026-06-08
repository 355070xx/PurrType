#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const PurrTypeSpeechInputErrorDomain;
extern NSErrorUserInfoKey const PurrTypeSpeechInputErrorLocaleIdentifierKey;
extern NSUInteger const PurrTypeSpeechInputMaximumContextualPhraseCount;

typedef NS_ENUM(NSInteger, PurrTypeSpeechInputErrorCode) {
    PurrTypeSpeechInputErrorUnsupportedLocale = 1,
    PurrTypeSpeechInputErrorSpeechPermissionDenied = 2,
    PurrTypeSpeechInputErrorMicrophonePermissionDenied = 3,
    PurrTypeSpeechInputErrorRecognizerUnavailable = 4,
    PurrTypeSpeechInputErrorAudioStartFailed = 5,
    PurrTypeSpeechInputErrorAlreadyActive = 6,
    PurrTypeSpeechInputErrorRecognitionFailed = 7,
};

typedef NS_ENUM(NSInteger, PurrTypeSpeechInputPermissionStatus) {
    PurrTypeSpeechInputPermissionStatusNotDetermined = 0,
    PurrTypeSpeechInputPermissionStatusDenied = 1,
    PurrTypeSpeechInputPermissionStatusRestricted = 2,
    PurrTypeSpeechInputPermissionStatusAuthorized = 3,
};

typedef void (^PurrTypeSpeechInputTranscriptHandler)(NSString *transcript, BOOL isFinal);
typedef void (^PurrTypeSpeechInputTranscriptUpdateHandler)(NSString *transcript, NSArray<NSString *> *alternativeTranscripts, BOOL isFinal);
typedef void (^PurrTypeSpeechInputErrorHandler)(NSError *error);

@protocol PurrTypeSpeechInputRuntime <NSObject>

- (NSSet<NSString *> *)supportedLocaleIdentifiers;
- (PurrTypeSpeechInputPermissionStatus)speechAuthorizationStatus;
- (void)requestSpeechAuthorizationWithCompletion:(void (^)(PurrTypeSpeechInputPermissionStatus status))completion;
- (PurrTypeSpeechInputPermissionStatus)microphoneAuthorizationStatus;
- (void)requestMicrophoneAuthorizationWithCompletion:(void (^)(PurrTypeSpeechInputPermissionStatus status))completion;
- (void)prepareAudioRecognitionWithLocaleIdentifier:(NSString *)localeIdentifier
                                  contextualStrings:(NSArray<NSString *> *)contextualStrings
                                         completion:(void (^)(void))completion;
- (BOOL)startAudioRecognitionWithLocaleIdentifier:(NSString *)localeIdentifier
                                contextualStrings:(NSArray<NSString *> *)contextualStrings
                          transcriptUpdateHandler:(PurrTypeSpeechInputTranscriptUpdateHandler)transcriptUpdateHandler
                                     errorHandler:(PurrTypeSpeechInputErrorHandler)errorHandler
                                            error:(NSError **)error;
- (void)stopAudioRecognition;

@end

@interface PurrTypeSpeechInputController : NSObject

@property(nonatomic, readonly, getter=isActive) BOOL active;
@property(nonatomic, readonly) BOOL startInProgress;
@property(nonatomic, readonly, copy, nullable) NSString *activeLocaleIdentifier;
@property(nonatomic, readonly, copy, nullable) NSString *activeLocaleSelectionIdentifier;
@property(nonatomic, readonly, strong, nullable) NSError *lastError;

- (instancetype)init;
- (instancetype)initWithRuntime:(id<PurrTypeSpeechInputRuntime>)runtime NS_DESIGNATED_INITIALIZER;

+ (NSArray<NSString *> *)preferredLocaleIdentifiers;
+ (NSArray<NSString *> *)selectableLocaleSelectionIdentifiers;
+ (NSString *)normalizedLocaleSelectionIdentifier:(nullable NSString *)localeSelectionIdentifier;
+ (nullable NSString *)selectedLocaleIdentifierFromSupportedLocaleIdentifiers:(NSSet<NSString *> *)supportedLocaleIdentifiers;
+ (nullable NSString *)selectedLocaleIdentifierFromSupportedLocaleIdentifiers:(NSSet<NSString *> *)supportedLocaleIdentifiers
                                                    localeSelectionIdentifier:(nullable NSString *)localeSelectionIdentifier;
+ (NSArray<NSString *> *)contextualStringsFromBundle:(nullable NSBundle *)bundle;
+ (NSArray<NSString *> *)contextualStringsFromBundle:(nullable NSBundle *)bundle
                                   additionalStrings:(nullable NSArray<NSString *> *)additionalStrings;
+ (NSArray<NSString *> *)contextualStringsFromResourceURL:(nullable NSURL *)resourceURL;
+ (NSArray<NSString *> *)cappedContextualStringsFromStrings:(NSArray<NSString *> *)strings;
+ (NSString *)normalizedVoiceTranscriptForVoiceInput:(nullable NSString *)transcript;

- (BOOL)startWithTranscriptHandler:(nullable PurrTypeSpeechInputTranscriptHandler)transcriptHandler
                      errorHandler:(nullable PurrTypeSpeechInputErrorHandler)errorHandler;
- (BOOL)startWithLocaleSelectionIdentifier:(nullable NSString *)localeSelectionIdentifier
                         contextualStrings:(nullable NSArray<NSString *> *)contextualStrings
                         transcriptHandler:(nullable PurrTypeSpeechInputTranscriptHandler)transcriptHandler
                              errorHandler:(nullable PurrTypeSpeechInputErrorHandler)errorHandler;
- (BOOL)startWithLocaleSelectionIdentifier:(nullable NSString *)localeSelectionIdentifier
                         contextualStrings:(nullable NSArray<NSString *> *)contextualStrings
                   transcriptUpdateHandler:(nullable PurrTypeSpeechInputTranscriptUpdateHandler)transcriptUpdateHandler
                              errorHandler:(nullable PurrTypeSpeechInputErrorHandler)errorHandler;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
