#import "PurrTypeEngine.h"
#import <CommonCrypto/CommonDigest.h>
#include <string.h>

MKInputMode MKInputModeMixed = @"mixed";
MKInputMode MKInputModeCangjie = @"cangjie";
MKInputMode MKInputModeSucheng = @"quick";
MKInputMode MKInputModeSmartSucheng = @"smart_quick";
MKInputMode MKInputModePinyin = @"pinyin";
MKInputMode MKInputModeEnglish = @"english";

static NSInteger const MKMaximumLearningScore = 1000000;
static NSInteger const MKLearningVersion = 3;
static NSString *const MKLearningVersionKey = @"version";
static NSString *const MKLearningSaltKey = @"salt";
static NSString *const MKLearningCandidatesKey = @"candidateHashes";
static NSString *const MKLearningAssociationsKey = @"associationHashes";
static NSString *const MKLearningCategoryCandidate = @"candidate";
static NSString *const MKLearningCategoryAssociation = @"association";
static NSUInteger const MKSmartPhraseMaximumInputLength = 24;
static NSUInteger const MKLearnedPhraseMaximumCharacterLength = 8;
static NSUInteger const MKRecentCommittedTextLimit = 16;
static NSUInteger const MKRecentCommittedCodeLimit = 24;
static NSUInteger const MKSmartPhraseMaximumGeneratedPaths = 24;
static NSUInteger const MKSmartPhraseBeamWidth = 24;
static NSUInteger const MKSmartPhraseSegmentCandidateLimit = 9;
static NSUInteger const MKPinyinMaximumContinuousInputLength = 48;
static NSUInteger const MKPinyinMaximumGeneratedInputLength = 32;
static NSUInteger const MKPinyinMaximumGeneratedSyllables = 6;
static NSUInteger const MKPinyinMaximumContinuousSyllables = 12;
static NSUInteger const MKPinyinMaximumSyllableCodeLength = 6;
static NSUInteger const MKPinyinMaximumGeneratedPaths = 24;
static NSUInteger const MKPinyinBeamWidth = 24;
static NSUInteger const MKPinyinSegmentCandidateLimit = 5;
static NSUInteger const MKLearningDirectoryPermissions = 0700;
static NSUInteger const MKLearningFilePermissions = 0600;
static NSInteger const MKSmartPhraseAssociationBoost = 6000;
static NSInteger const MKSmartPhraseSingleCodePenalty = 3500;
static NSInteger const MKPinyinSegmentPenalty = 1400;
static NSString *const MKPinyinGeneratedPhraseSource = @"pinyin_phrase";
static NSInteger const MKHKSCSOverlayCangjieWeight = -1000000;
static NSInteger const MKHKSCSOverlayQuickWeight = -1000000;
static NSString *const MKSmartPhraseStatePathKey = @"path";
static NSString *const MKSmartPhraseStateScoreKey = @"score";
static NSUInteger const MKGeneratedAssociationIndexHeaderSize = 12;
static NSUInteger const MKGeneratedAssociationIndexRecordSize = 16;
static const uint8_t MKGeneratedAssociationIndexMagic[8] = { 'P', 'T', 'A', 'I', 'D', 'X', '0', '1' };
static NSUInteger const MKCandidateTableIndexHeaderSize = 16;
static NSUInteger const MKCandidateTableIndexRecordSize = 16;
static const uint8_t MKCandidateTableIndexMagic[8] = { 'P', 'T', 'C', 'I', 'D', 'X', '0', '1' };

static uint32_t MKReadBigEndianUInt32(const uint8_t *bytes) {
    return ((uint32_t)bytes[0] << 24) |
           ((uint32_t)bytes[1] << 16) |
           ((uint32_t)bytes[2] << 8) |
           (uint32_t)bytes[3];
}

static BOOL MKAssociationIndexRangeIsValid(NSUInteger offset, NSUInteger length, NSUInteger totalLength) {
    return offset <= totalLength && length <= totalLength - offset;
}

static BOOL MKLearningDirectoryShouldBePrivate(NSString *directory) {
    NSArray<NSString *> *components = directory.stringByStandardizingPath.pathComponents;
    NSUInteger count = components.count;
    if (count < 3) {
        return NO;
    }

    return [components[count - 1] isEqualToString:@"PurrType"] &&
           [components[count - 2] isEqualToString:@"Application Support"] &&
           [components[count - 3] isEqualToString:@"Library"];
}

static int MKCompareAssociationIndexBytes(const uint8_t *left,
                                          NSUInteger leftLength,
                                          const uint8_t *right,
                                          NSUInteger rightLength) {
    NSUInteger comparableLength = MIN(leftLength, rightLength);
    int comparison = comparableLength > 0 ? memcmp(left, right, comparableLength) : 0;
    if (comparison != 0) {
        return comparison;
    }
    if (leftLength == rightLength) {
        return 0;
    }
    return leftLength < rightLength ? -1 : 1;
}

@implementation MKCandidate

- (instancetype)initWithText:(NSString *)text
                        code:(NSString *)code
                      source:(NSString *)source
                      weight:(NSInteger)weight {
    return [self initWithText:text code:code source:source weight:weight sequence:0];
}

- (instancetype)initWithText:(NSString *)text
                        code:(NSString *)code
                      source:(NSString *)source
                      weight:(NSInteger)weight
                    sequence:(NSUInteger)sequence {
    self = [super init];
    if (self) {
        _text = [text copy];
        _code = [code copy];
        _source = [source copy];
        _weight = weight;
        _sequence = sequence;
    }
    return self;
}

@end

@protocol MKCandidateProvider <NSObject>

- (NSArray<MKCandidate *> *)candidatesForInput:(NSString *)input;
- (NSSet<NSString *> *)prefixes;
- (BOOL)hasCandidatesOrPrefixesForInput:(NSString *)input;

@end

@protocol MKAssociationProvider <NSObject>

- (NSArray<MKCandidate *> *)associatedCandidatesForText:(NSString *)text
                                                  limit:(NSUInteger)limit
                                                   mode:(MKInputMode)mode;

@end

@class MKGeneratedAssociationIndex;
@class MKCandidateTableIndex;

@interface PurrTypeEngine ()

@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<MKCandidate *> *> *index;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSMutableArray<MKCandidate *> *> *> *indexBySource;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *seenTextsBySourceAndInput;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *textsBySource;
@property(nonatomic, strong) NSMutableSet<NSString *> *prefixes;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *prefixesBySource;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *associationIndex;
@property(nonatomic, strong) NSMutableArray<NSString *> *associationPhraseSeeds;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<MKCandidate *> *> *smartPhraseIndex;
@property(nonatomic, strong) NSMutableSet<NSString *> *smartPhrasePrefixes;
@property(nonatomic, strong) NSMutableSet<NSString *> *learnedPhrasePrefixes;
@property(nonatomic, strong) NSDictionary<NSString *, NSArray<NSString *> *> *candidateOrderOverrides;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *preferredQuickCodeByText;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *preferredCangjieCodeByText;
@property(nonatomic, copy) NSDictionary<NSString *, NSArray<NSString *> *> *dictionaryPronunciationCandidateTextsByKey;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *traditionalCompatibilityQuickCodeByText;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *learnedCandidateScores;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *learnedAssociationScores;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *learnedPhraseScores;
@property(nonatomic, strong) NSMutableArray<NSString *> *recentCommittedTextSegments;
@property(nonatomic, strong) NSMutableArray<NSString *> *recentCommittedCodeSegments;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *persistedCandidateScoresByHash;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *persistedAssociationScoresByHash;
@property(nonatomic, strong) NSSet<NSString *> *traditionalCompatibilityTexts;
@property(nonatomic, strong) NSMutableSet<NSString *> *hkscsCandidateTexts;
@property(nonatomic, copy) NSString *cangjieDirectory;
@property(nonatomic, copy) NSString *pinyinPath;
@property(nonatomic, copy) NSString *resourceDirectory;
@property(nonatomic, copy) NSString *hkscsDirectory;
@property(nonatomic, copy) NSString *candidateIndexDirectory;
@property(nonatomic, copy) NSString *associationGeneratedIndexPath;
@property(nonatomic, copy) NSString *smartPhrasesPath;
@property(nonatomic, assign) BOOL quickDataLoaded;
@property(nonatomic, assign) BOOL cangjieDataLoaded;
@property(nonatomic, assign) BOOL pinyinDataLoaded;
@property(nonatomic, assign) BOOL dictionaryPronunciationCandidateIndexBuilt;
@property(nonatomic, assign) BOOL generatedAssociationDataLoaded;
@property(nonatomic, assign) BOOL smartPhraseDataLoaded;
@property(nonatomic, copy, nullable) NSString *learningPath;
@property(nonatomic, copy) NSString *learningSalt;
@property(nonatomic, assign) NSUInteger nextCandidateSequence;
@property(nonatomic, assign) NSUInteger nextSmartPhraseSequence;
@property(nonatomic, assign, readwrite) NSUInteger cangjieEntryCount;
@property(nonatomic, assign, readwrite) NSUInteger quickEntryCount;
@property(nonatomic, assign, readwrite) NSUInteger pinyinEntryCount;
@property(nonatomic, strong) id<MKCandidateProvider> mixedCandidateProvider;
@property(nonatomic, strong) id<MKCandidateProvider> emptyCandidateProvider;
@property(nonatomic, strong) NSDictionary<NSString *, id<MKCandidateProvider>> *candidateProvidersByMode;
@property(nonatomic, strong) id<MKAssociationProvider> associationProvider;
@property(nonatomic, strong) MKGeneratedAssociationIndex *generatedAssociationIndex;
@property(nonatomic, strong) MKCandidateTableIndex *quickCandidateIndex;
@property(nonatomic, strong) MKCandidateTableIndex *cangjieCandidateIndex;
@property(nonatomic, strong) MKCandidateTableIndex *pinyinCandidateIndex;
@property(nonatomic, assign) BOOL preferredQuickCodeIndexBuilt;
@property(nonatomic, assign) BOOL preferredCangjieCodeIndexBuilt;

- (void)loadTraditionalCompatibilityCandidateSeedAtPath:(NSString *)path
                                      includingCangjie:(BOOL)includingCangjie
                                       includingSucheng:(BOOL)includingSucheng;
- (void)loadHKSCSOverlayInDirectory:(NSString *)directory
                  includingCangjie:(BOOL)includingCangjie
                   includingSucheng:(BOOL)includingSucheng;
- (void)ensureDataForMode:(MKInputMode)mode;
- (void)ensureAllCandidateDataLoaded;
- (void)ensureDictionaryPronunciationCandidateIndexBuilt;
- (void)ensureQuickDataLoaded;
- (void)ensureCangjieDataLoaded;
- (void)ensurePinyinDataLoaded;
- (void)ensureGeneratedAssociationDataLoaded;
- (void)ensureSmartPhraseDataLoaded;
- (void)addCandidateText:(NSString *)text
                    code:(NSString *)code
                  source:(NSString *)source
                  weight:(NSInteger)weight
 allowingTraditionalCompatibility:(BOOL)allowingTraditionalCompatibility;
- (void)addCandidateText:(NSString *)text
                    code:(NSString *)code
                  source:(NSString *)source
                  weight:(NSInteger)weight
 allowingTraditionalCompatibility:(BOOL)allowingTraditionalCompatibility
 includingInUnifiedIndex:(BOOL)includingInUnifiedIndex;
- (BOOL)isTraditionalCompatibilityCandidateText:(NSString *)text;
- (BOOL)isHKSCSCandidateTextDisplayable:(NSString *)text;
- (BOOL)isHKSCSChineseCandidateText:(NSString *)text;
- (uint32_t)firstUnicodeScalarInString:(NSString *)text;
- (BOOL)isPrivateUseScalar:(uint32_t)scalar;
- (BOOL)isHanScalar:(uint32_t)scalar;
- (BOOL)isCJKScalarForLearning:(uint32_t)scalar;
- (NSArray<NSString *> *)normalizedHKSCSCangjieCodesFromRawValue:(NSString *)rawValue;
- (NSString *)quickCodeFromCangjieCode:(NSString *)cangjieCode;
- (BOOL)candidateText:(NSString *)text existsInSource:(NSString *)source;
- (BOOL)candidateText:(NSString *)text existsInSource:(NSString *)source code:(NSString *)code;
- (BOOL)shouldUseIndexedCandidateText:(NSString *)text source:(NSString *)source;
- (NSInteger)fixedRankingBoostForText:(NSString *)text source:(NSString *)source;
- (NSArray<NSString *> *)associationLookupKeysForText:(NSString *)text;
- (NSString *)associationContinuationFromKey:(NSString *)key candidate:(NSString *)candidate;
- (NSArray<NSString *> *)fixedAssociationCandidatesForKey:(NSString *)key;
- (NSArray<NSString *> *)generatedAssociationCandidatesForKey:(NSString *)key;
- (id<MKCandidateProvider>)candidateProviderForMode:(MKInputMode)mode;
- (NSString *)candidateIndexDirectoryForResourceDirectory:(NSString *)resourceDirectory
                                        cangjieDirectory:(NSString *)cangjieDirectory;
- (MKCandidateTableIndex *)openCandidateIndexNamed:(NSString *)fileName source:(NSString *)source;
- (MKCandidateTableIndex *)candidateIndexForSource:(NSString *)source;
- (NSArray<NSString *> *)candidateIndexCodesForSource:(NSString *)source;
- (NSArray<MKCandidate *> *)candidateBucketForCode:(NSString *)code source:(NSString *)source;
- (void)addDictionaryCandidateText:(NSString *)text
               pronunciationKey:(NSString *)pronunciationKey
        charactersByPronunciation:(NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *)charactersByPronunciation
 seenCharactersByPronunciation:(NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *)seenCharactersByPronunciation;
- (NSString *)normalizedDictionaryFallbackCharacter:(NSString *)text;
- (NSString *)dictionaryPronunciationKeyForCharacter:(NSString *)character;
- (void)appendDictionaryCandidateTextsFromArray:(NSArray<NSString *> *)candidateTexts
                               recognizedText:(NSString *)recognizedText
                                     seenTexts:(NSMutableSet<NSString *> *)seenTexts
                                        result:(NSMutableArray<NSString *> *)result
                                         limit:(NSUInteger)limit;
- (void)appendDictionaryCandidateTextsForCode:(NSString *)code
                                         mode:(MKInputMode)mode
                               recognizedText:(NSString *)recognizedText
                                     seenTexts:(NSMutableSet<NSString *> *)seenTexts
                                        result:(NSMutableArray<NSString *> *)result
                                         limit:(NSUInteger)limit;
- (NSArray<MKCandidate *> *)unifiedCandidateBucketForCode:(NSString *)code;
- (BOOL)hasCandidatesOrPrefixesForCode:(NSString *)code source:(NSString *)source;
- (BOOL)unifiedHasCandidatesOrPrefixesForCode:(NSString *)code;
- (NSSet<NSString *> *)prefixesForSource:(NSString *)source;
- (NSSet<NSString *> *)unifiedPrefixes;
- (BOOL)shouldApplyLearningRankingForMode:(MKInputMode)mode;
- (void)trimRecentCommittedSegments;
- (void)recordRecentCommittedSuffixesForLearningWithMode:(MKInputMode)mode;
- (NSUInteger)recentCommittedTextLength;
- (NSUInteger)recentCommittedCodeLength;
- (BOOL)isCandidateTextDisplayable:(NSString *)text;
- (BOOL)isTraditionalCandidateText:(NSString *)text;
- (NSInteger)persistedLearningScoreForCategory:(NSString *)category
                                           key:(NSString *)key
                                          text:(NSString *)text
                                         table:(NSDictionary<NSString *, NSNumber *> *)table;
- (void)hardenLearningDirectoryIfNeeded:(NSString *)directory;
- (void)hardenLearningFileIfNeeded;
- (void)sortCandidateBucketsForSource:(NSString *)source;
- (void)sortUnifiedCandidateBuckets;
- (void)applyCandidateOrderOverridesForSource:(NSString *)source;
- (NSArray<MKCandidate *> *)pinyinCandidatesForInput:(NSString *)input
                                      baseCandidates:(NSArray<MKCandidate *> *)baseCandidates;
- (NSArray<MKCandidate *> *)generatedPinyinPhraseCandidatesForInput:(NSString *)input
                                                excludingCandidates:(NSArray<MKCandidate *> *)existingCandidates;
- (NSArray<NSDictionary *> *)generatedPinyinPhraseStatesForInput:(NSString *)input;
- (NSArray<MKCandidate *> *)pinyinSegmentCandidatesForCode:(NSString *)code previousText:(NSString *)previousText;
- (NSArray<MKCandidate *> *)pinyinSingleCharacterCandidatesForCode:(NSString *)code;
- (NSInteger)pinyinSegmentScoreForCandidate:(MKCandidate *)candidate previousText:(NSString *)previousText;
- (void)prunePinyinStateBeam:(NSMutableArray<NSDictionary *> *)states limit:(NSUInteger)limit;
- (BOOL)hasSegmentedPinyinCandidateOrPrefixForInput:(NSString *)input;
- (BOOL)canSegmentPinyinInputPrefix:(NSString *)input
                           position:(NSUInteger)position
                       syllableCount:(NSUInteger)syllableCount
                         failedMemo:(NSMutableSet<NSString *> *)failedMemo;

@end

@interface MKTableCandidateProvider : NSObject <MKCandidateProvider>

@property(nonatomic, weak) PurrTypeEngine *engine;
@property(nonatomic, copy, nullable) NSString *source;

- (instancetype)initWithEngine:(PurrTypeEngine *)engine source:(nullable NSString *)source;
- (instancetype)init NS_UNAVAILABLE;

@end

@implementation MKTableCandidateProvider

- (instancetype)initWithEngine:(PurrTypeEngine *)engine source:(nullable NSString *)source {
    self = [super init];
    if (self) {
        _engine = engine;
        _source = [source copy];
    }
    return self;
}

- (NSArray<MKCandidate *> *)candidatesForInput:(NSString *)input {
    if (self.source.length > 0) {
        return [self.engine candidateBucketForCode:input source:self.source];
    }
    return [self.engine unifiedCandidateBucketForCode:input];
}

- (NSSet<NSString *> *)prefixes {
    if (self.source.length > 0) {
        return [self.engine prefixesForSource:self.source];
    }
    return [self.engine unifiedPrefixes];
}

- (BOOL)hasCandidatesOrPrefixesForInput:(NSString *)input {
    if (self.source.length > 0) {
        return [self.engine hasCandidatesOrPrefixesForCode:input source:self.source];
    }
    return [self.engine unifiedHasCandidatesOrPrefixesForCode:input];
}

@end

@interface MKEmptyCandidateProvider : NSObject <MKCandidateProvider>

@end

@implementation MKEmptyCandidateProvider

- (NSArray<MKCandidate *> *)candidatesForInput:(NSString *)input {
    (void)input;
    return @[];
}

- (NSSet<NSString *> *)prefixes {
    return [NSSet set];
}

- (BOOL)hasCandidatesOrPrefixesForInput:(NSString *)input {
    (void)input;
    return NO;
}

@end

@interface MKGeneratedAssociationIndex : NSObject

@property(nonatomic, strong) NSData *data;
@property(nonatomic, assign) uint32_t entryCount;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSString *> *> *cache;

- (instancetype)initWithPath:(NSString *)path;
- (NSArray<NSString *> *)candidatesForKey:(NSString *)key;
- (NSArray<NSString *> *)candidatesFromValueBytes:(const uint8_t *)bytes length:(NSUInteger)length;
- (instancetype)init NS_UNAVAILABLE;

@end

@implementation MKGeneratedAssociationIndex

- (instancetype)initWithPath:(NSString *)path {
    if (path.length == 0) {
        return nil;
    }

    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&error];
    if (data.length < MKGeneratedAssociationIndexHeaderSize) {
        return nil;
    }

    const uint8_t *bytes = data.bytes;
    if (memcmp(bytes, MKGeneratedAssociationIndexMagic, sizeof(MKGeneratedAssociationIndexMagic)) != 0) {
        return nil;
    }

    uint32_t entryCount = MKReadBigEndianUInt32(bytes + sizeof(MKGeneratedAssociationIndexMagic));
    if ((NSUInteger)entryCount > (NSUIntegerMax - MKGeneratedAssociationIndexHeaderSize) / MKGeneratedAssociationIndexRecordSize) {
        return nil;
    }

    NSUInteger recordsEnd = MKGeneratedAssociationIndexHeaderSize + ((NSUInteger)entryCount * MKGeneratedAssociationIndexRecordSize);
    if (recordsEnd > data.length) {
        return nil;
    }

    self = [super init];
    if (self) {
        _data = data;
        _entryCount = entryCount;
        _cache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSArray<NSString *> *)candidatesForKey:(NSString *)key {
    if (key.length == 0 || self.entryCount == 0) {
        return @[];
    }

    NSArray<NSString *> *cached = self.cache[key];
    if (cached) {
        return cached;
    }

    NSData *targetData = [key dataUsingEncoding:NSUTF8StringEncoding];
    if (targetData.length == 0) {
        self.cache[key] = @[];
        return @[];
    }

    const uint8_t *bytes = self.data.bytes;
    const uint8_t *targetBytes = targetData.bytes;
    NSUInteger low = 0;
    NSUInteger high = self.entryCount;
    while (low < high) {
        NSUInteger mid = low + ((high - low) / 2);
        NSUInteger recordOffset = MKGeneratedAssociationIndexHeaderSize + (mid * MKGeneratedAssociationIndexRecordSize);
        const uint8_t *record = bytes + recordOffset;
        uint32_t keyOffset = MKReadBigEndianUInt32(record);
        uint32_t keyLength = MKReadBigEndianUInt32(record + 4);
        uint32_t valueOffset = MKReadBigEndianUInt32(record + 8);
        uint32_t valueLength = MKReadBigEndianUInt32(record + 12);

        if (!MKAssociationIndexRangeIsValid(keyOffset, keyLength, self.data.length) ||
            !MKAssociationIndexRangeIsValid(valueOffset, valueLength, self.data.length)) {
            break;
        }

        int comparison = MKCompareAssociationIndexBytes(bytes + keyOffset,
                                                       keyLength,
                                                       targetBytes,
                                                       targetData.length);
        if (comparison == 0) {
            NSArray<NSString *> *candidates = [self candidatesFromValueBytes:bytes + valueOffset length:valueLength];
            self.cache[key] = candidates;
            return candidates;
        }
        if (comparison < 0) {
            low = mid + 1;
        } else {
            high = mid;
        }
    }

    self.cache[key] = @[];
    return @[];
}

- (NSArray<NSString *> *)candidatesFromValueBytes:(const uint8_t *)bytes length:(NSUInteger)length {
    if (length == 0) {
        return @[];
    }

    NSString *joined = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    if (joined.length == 0) {
        return @[];
    }

    NSArray<NSString *> *parts = [joined componentsSeparatedByString:@"\t"];
    NSMutableArray<NSString *> *candidates = [NSMutableArray arrayWithCapacity:parts.count];
    for (NSString *part in parts) {
        if (part.length > 0) {
            [candidates addObject:part];
        }
    }
    return [candidates copy];
}

@end

@interface MKCandidateTableIndex : NSObject

@property(nonatomic, strong) NSData *data;
@property(nonatomic, copy) NSString *source;
@property(nonatomic, assign) uint32_t entryCount;
@property(nonatomic, assign) uint32_t candidateCount;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSArray<MKCandidate *> *> *cache;
@property(nonatomic, strong) NSArray<NSString *> *cachedCodes;

- (instancetype)initWithPath:(NSString *)path source:(NSString *)source;
- (NSArray<MKCandidate *> *)candidatesForCode:(NSString *)code engine:(PurrTypeEngine *)engine;
- (BOOL)hasCandidatesOrPrefixesForCode:(NSString *)code engine:(PurrTypeEngine *)engine;
- (BOOL)containsText:(NSString *)text code:(NSString *)code engine:(PurrTypeEngine *)engine;
- (NSArray<NSString *> *)allCodes;
- (instancetype)init NS_UNAVAILABLE;

@end

@implementation MKCandidateTableIndex

- (instancetype)initWithPath:(NSString *)path source:(NSString *)source {
    if (path.length == 0 || source.length == 0) {
        return nil;
    }

    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&error];
    if (data.length < MKCandidateTableIndexHeaderSize) {
        return nil;
    }

    const uint8_t *bytes = data.bytes;
    if (memcmp(bytes, MKCandidateTableIndexMagic, sizeof(MKCandidateTableIndexMagic)) != 0) {
        return nil;
    }

    uint32_t entryCount = MKReadBigEndianUInt32(bytes + sizeof(MKCandidateTableIndexMagic));
    uint32_t candidateCount = MKReadBigEndianUInt32(bytes + sizeof(MKCandidateTableIndexMagic) + 4);
    if ((NSUInteger)entryCount > (NSUIntegerMax - MKCandidateTableIndexHeaderSize) / MKCandidateTableIndexRecordSize) {
        return nil;
    }

    NSUInteger recordsEnd = MKCandidateTableIndexHeaderSize + ((NSUInteger)entryCount * MKCandidateTableIndexRecordSize);
    if (recordsEnd > data.length) {
        return nil;
    }

    self = [super init];
    if (self) {
        _data = data;
        _source = [source copy];
        _entryCount = entryCount;
        _candidateCount = candidateCount;
        _cache = [NSMutableDictionary dictionary];
        _cachedCodes = @[];
    }
    return self;
}

- (NSArray<MKCandidate *> *)candidatesForCode:(NSString *)code engine:(PurrTypeEngine *)engine {
    if (code.length == 0 || self.entryCount == 0) {
        return @[];
    }

    NSArray<MKCandidate *> *cached = self.cache[code];
    if (cached) {
        return cached;
    }

    NSUInteger recordIndex = [self recordIndexForCode:code];
    if (recordIndex == NSNotFound) {
        self.cache[code] = @[];
        return @[];
    }

    uint32_t valueOffset = 0;
    uint32_t valueLength = 0;
    if (![self valueOffset:&valueOffset length:&valueLength forRecordAtIndex:recordIndex]) {
        self.cache[code] = @[];
        return @[];
    }

    const uint8_t *bytes = self.data.bytes;
    NSString *joined = [[NSString alloc] initWithBytes:bytes + valueOffset
                                                length:valueLength
                                              encoding:NSUTF8StringEncoding];
    if (joined.length == 0) {
        self.cache[code] = @[];
        return @[];
    }

    NSMutableArray<MKCandidate *> *candidates = [NSMutableArray array];
    NSArray<NSString *> *lines = [joined componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if (line.length == 0) {
            continue;
        }

        NSArray<NSString *> *columns = [line componentsSeparatedByString:@"\t"];
        if (columns.count < 3) {
            continue;
        }

        NSString *text = columns[0];
        if (![engine shouldUseIndexedCandidateText:text source:self.source]) {
            continue;
        }

        NSInteger weight = [columns[1] integerValue] + [engine fixedRankingBoostForText:text source:self.source];
        NSUInteger sequence = (NSUInteger)[columns[2] longLongValue];
        [candidates addObject:[[MKCandidate alloc] initWithText:text
                                                           code:code
                                                         source:self.source
                                                         weight:weight
                                                       sequence:sequence]];
    }

    NSArray<MKCandidate *> *result = [candidates copy];
    self.cache[code] = result;
    return result;
}

- (BOOL)hasCandidatesOrPrefixesForCode:(NSString *)code engine:(PurrTypeEngine *)engine {
    if (code.length == 0 || self.entryCount == 0) {
        return NO;
    }

    if ([self candidatesForCode:code engine:engine].count > 0) {
        return YES;
    }

    NSData *targetData = [code dataUsingEncoding:NSUTF8StringEncoding];
    if (targetData.length == 0) {
        return NO;
    }

    NSUInteger index = [self lowerBoundForBytes:targetData.bytes length:targetData.length];
    while (index < self.entryCount) {
        NSString *indexedCode = [self codeAtRecordIndex:index];
        if (indexedCode.length < code.length || ![indexedCode hasPrefix:code]) {
            return NO;
        }
        if ([self candidatesForCode:indexedCode engine:engine].count > 0) {
            return YES;
        }
        index += 1;
    }

    return NO;
}

- (BOOL)containsText:(NSString *)text code:(NSString *)code engine:(PurrTypeEngine *)engine {
    if (text.length == 0 || code.length == 0) {
        return NO;
    }

    for (MKCandidate *candidate in [self candidatesForCode:code engine:engine]) {
        if ([candidate.text isEqualToString:text]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray<NSString *> *)allCodes {
    if (self.cachedCodes.count > 0 || self.entryCount == 0) {
        return self.cachedCodes;
    }

    NSMutableArray<NSString *> *codes = [NSMutableArray arrayWithCapacity:self.entryCount];
    for (NSUInteger index = 0; index < self.entryCount; index += 1) {
        NSString *code = [self codeAtRecordIndex:index];
        if (code.length > 0) {
            [codes addObject:code];
        }
    }

    self.cachedCodes = [codes copy];
    return self.cachedCodes;
}

- (NSUInteger)recordIndexForCode:(NSString *)code {
    NSData *targetData = [code dataUsingEncoding:NSUTF8StringEncoding];
    if (targetData.length == 0) {
        return NSNotFound;
    }

    NSUInteger index = [self lowerBoundForBytes:targetData.bytes length:targetData.length];
    if (index >= self.entryCount) {
        return NSNotFound;
    }

    uint32_t keyOffset = 0;
    uint32_t keyLength = 0;
    if (![self keyOffset:&keyOffset length:&keyLength forRecordAtIndex:index]) {
        return NSNotFound;
    }

    const uint8_t *bytes = self.data.bytes;
    int comparison = MKCompareAssociationIndexBytes(bytes + keyOffset,
                                                   keyLength,
                                                   targetData.bytes,
                                                   targetData.length);
    return comparison == 0 ? index : NSNotFound;
}

- (NSUInteger)lowerBoundForBytes:(const uint8_t *)targetBytes length:(NSUInteger)targetLength {
    NSUInteger low = 0;
    NSUInteger high = self.entryCount;
    const uint8_t *bytes = self.data.bytes;

    while (low < high) {
        NSUInteger mid = low + ((high - low) / 2);
        uint32_t keyOffset = 0;
        uint32_t keyLength = 0;
        if (![self keyOffset:&keyOffset length:&keyLength forRecordAtIndex:mid]) {
            return self.entryCount;
        }

        int comparison = MKCompareAssociationIndexBytes(bytes + keyOffset,
                                                       keyLength,
                                                       targetBytes,
                                                       targetLength);
        if (comparison < 0) {
            low = mid + 1;
        } else {
            high = mid;
        }
    }

    return low;
}

- (NSString *)codeAtRecordIndex:(NSUInteger)recordIndex {
    uint32_t keyOffset = 0;
    uint32_t keyLength = 0;
    if (![self keyOffset:&keyOffset length:&keyLength forRecordAtIndex:recordIndex]) {
        return @"";
    }

    const uint8_t *bytes = self.data.bytes;
    NSString *code = [[NSString alloc] initWithBytes:bytes + keyOffset
                                             length:keyLength
                                           encoding:NSUTF8StringEncoding];
    return code ?: @"";
}

- (BOOL)keyOffset:(uint32_t *)keyOffset
           length:(uint32_t *)keyLength
forRecordAtIndex:(NSUInteger)recordIndex {
    if (recordIndex >= self.entryCount) {
        return NO;
    }

    const uint8_t *bytes = self.data.bytes;
    NSUInteger recordOffset = MKCandidateTableIndexHeaderSize + (recordIndex * MKCandidateTableIndexRecordSize);
    uint32_t offset = MKReadBigEndianUInt32(bytes + recordOffset);
    uint32_t length = MKReadBigEndianUInt32(bytes + recordOffset + 4);
    if (!MKAssociationIndexRangeIsValid(offset, length, self.data.length)) {
        return NO;
    }

    if (keyOffset) {
        *keyOffset = offset;
    }
    if (keyLength) {
        *keyLength = length;
    }
    return YES;
}

- (BOOL)valueOffset:(uint32_t *)valueOffset
             length:(uint32_t *)valueLength
   forRecordAtIndex:(NSUInteger)recordIndex {
    if (recordIndex >= self.entryCount) {
        return NO;
    }

    const uint8_t *bytes = self.data.bytes;
    NSUInteger recordOffset = MKCandidateTableIndexHeaderSize + (recordIndex * MKCandidateTableIndexRecordSize);
    uint32_t offset = MKReadBigEndianUInt32(bytes + recordOffset + 8);
    uint32_t length = MKReadBigEndianUInt32(bytes + recordOffset + 12);
    if (!MKAssociationIndexRangeIsValid(offset, length, self.data.length)) {
        return NO;
    }

    if (valueOffset) {
        *valueOffset = offset;
    }
    if (valueLength) {
        *valueLength = length;
    }
    return YES;
}

@end

@interface MKSeedAssociationProvider : NSObject <MKAssociationProvider>

@property(nonatomic, weak) PurrTypeEngine *engine;

- (instancetype)initWithEngine:(PurrTypeEngine *)engine;
- (instancetype)init NS_UNAVAILABLE;

@end

@implementation MKSeedAssociationProvider

- (instancetype)initWithEngine:(PurrTypeEngine *)engine {
    self = [super init];
    if (self) {
        _engine = engine;
    }
    return self;
}

- (NSArray<MKCandidate *> *)associatedCandidatesForText:(NSString *)text
                                                  limit:(NSUInteger)limit
                                                   mode:(MKInputMode)mode {
    NSArray<NSString *> *keys = [self.engine associationLookupKeysForText:text];
    if (keys.count == 0) {
        return @[];
    }

    [self.engine ensureGeneratedAssociationDataLoaded];
    NSMutableArray<MKCandidate *> *candidates = [NSMutableArray arrayWithCapacity:limit];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSUInteger sequence = 0;

    for (NSString *key in keys) {
        BOOL applyingLearning = [self.engine shouldApplyLearningRankingForMode:mode];
        NSDictionary<NSString *, NSNumber *> *learnedScores = applyingLearning ? self.engine.learnedAssociationScores[key] ?: @{} : @{};
        NSArray<NSString *> *learnedTexts = [learnedScores.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
            NSInteger leftScore = [learnedScores[left] integerValue];
            NSInteger rightScore = [learnedScores[right] integerValue];
            if (leftScore != rightScore) {
                return leftScore > rightScore ? NSOrderedAscending : NSOrderedDescending;
            }
            return [left compare:right];
        }];

        for (NSString *candidateText in learnedTexts) {
            if (candidates.count >= limit) {
                return [candidates copy];
            }
            if ([seen containsObject:candidateText] ||
                ![self.engine isCandidateTextDisplayable:candidateText] ||
                ![self.engine isTraditionalCandidateText:candidateText]) {
                continue;
            }
            [seen addObject:candidateText];
            NSInteger learnedScore = [learnedScores[candidateText] integerValue];
            if (applyingLearning) {
                learnedScore += [self.engine persistedLearningScoreForCategory:MKLearningCategoryAssociation
                                                                           key:key
                                                                          text:candidateText
                                                                         table:self.engine.persistedAssociationScoresByHash];
            }
            [candidates addObject:[[MKCandidate alloc] initWithText:candidateText
                                                               code:key
                                                             source:@"association"
                                                             weight:(learnedScore > 0 ? 3000 + learnedScore : 2000) - (NSInteger)sequence
                                                           sequence:sequence]];
            sequence += 1;
        }

        NSMutableArray<MKCandidate *> *seedCandidates = [NSMutableArray array];
        NSMutableDictionary<NSValue *, NSNumber *> *seedPositions = [NSMutableDictionary dictionary];
        BOOL hasPersistedRank = NO;
        NSUInteger seedPosition = 0;
        for (NSString *candidateText in [self.engine fixedAssociationCandidatesForKey:key]) {
            if ([seen containsObject:candidateText]) {
                seedPosition += 1;
                continue;
            }
            [seen addObject:candidateText];
            NSInteger learnedScore = [learnedScores[candidateText] integerValue];
            if (applyingLearning) {
                learnedScore += [self.engine persistedLearningScoreForCategory:MKLearningCategoryAssociation
                                                                           key:key
                                                                          text:candidateText
                                                                         table:self.engine.persistedAssociationScoresByHash];
            }
            if (learnedScore > 0) {
                hasPersistedRank = YES;
            }
            MKCandidate *candidate = [[MKCandidate alloc] initWithText:candidateText
                                                                  code:key
                                                                source:@"association"
                                                                weight:(learnedScore > 0 ? 3000 + learnedScore : 2000) - (NSInteger)sequence
                                                              sequence:sequence];
            [seedCandidates addObject:candidate];
            seedPositions[[NSValue valueWithNonretainedObject:candidate]] = @(seedPosition);
            sequence += 1;
            seedPosition += 1;
        }

        if (hasPersistedRank) {
            [seedCandidates sortUsingComparator:^NSComparisonResult(MKCandidate *left, MKCandidate *right) {
                NSInteger leftScore = [learnedScores[left.text] integerValue];
                NSInteger rightScore = [learnedScores[right.text] integerValue];
                if (applyingLearning) {
                    leftScore += [self.engine persistedLearningScoreForCategory:MKLearningCategoryAssociation
                                                                            key:key
                                                                           text:left.text
                                                                          table:self.engine.persistedAssociationScoresByHash];
                    rightScore += [self.engine persistedLearningScoreForCategory:MKLearningCategoryAssociation
                                                                             key:key
                                                                            text:right.text
                                                                           table:self.engine.persistedAssociationScoresByHash];
                }
                if (leftScore != rightScore) {
                    return leftScore > rightScore ? NSOrderedAscending : NSOrderedDescending;
                }

                NSUInteger leftPosition = [seedPositions[[NSValue valueWithNonretainedObject:left]] unsignedIntegerValue];
                NSUInteger rightPosition = [seedPositions[[NSValue valueWithNonretainedObject:right]] unsignedIntegerValue];
                if (leftPosition != rightPosition) {
                    return leftPosition < rightPosition ? NSOrderedAscending : NSOrderedDescending;
                }
                return NSOrderedSame;
            }];
        }

        for (MKCandidate *candidate in seedCandidates) {
            if (candidates.count >= limit) {
                return [candidates copy];
            }
            [candidates addObject:candidate];
        }
    }
    return [candidates copy];
}

@end

@implementation PurrTypeEngine

+ (instancetype)sharedEngine {
    static PurrTypeEngine *engine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
        NSString *cangjieDirectory = [resourcePath stringByAppendingPathComponent:@"RimeCangjie"];
        NSString *pinyinPath = [resourcePath stringByAppendingPathComponent:@"pinyin_seed.tsv"];
        engine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                          pinyinPath:pinyinPath
                                                        learningPath:[PurrTypeEngine defaultLearningPath]];
    });
    return engine;
}

- (instancetype)initWithCangjieDirectory:(NSString *)cangjieDirectory
                              pinyinPath:(NSString *)pinyinPath {
    return [self initWithCangjieDirectory:cangjieDirectory pinyinPath:pinyinPath learningPath:nil];
}

- (instancetype)initWithCangjieDirectory:(NSString *)cangjieDirectory
                              pinyinPath:(NSString *)pinyinPath
                            learningPath:(NSString *)learningPath {
    self = [super init];
    if (self) {
        _index = [NSMutableDictionary dictionary];
        _indexBySource = [NSMutableDictionary dictionary];
        _seenTextsBySourceAndInput = [NSMutableDictionary dictionary];
        _textsBySource = [NSMutableDictionary dictionary];
        _prefixes = [NSMutableSet set];
        _prefixesBySource = [NSMutableDictionary dictionary];
        _associationIndex = [self buildAssociationIndex];
        _associationPhraseSeeds = [NSMutableArray array];
        _smartPhraseIndex = [NSMutableDictionary dictionary];
        _smartPhrasePrefixes = [NSMutableSet set];
        _learnedPhrasePrefixes = [NSMutableSet set];
        _preferredQuickCodeByText = [NSMutableDictionary dictionary];
        _dictionaryPronunciationCandidateTextsByKey = @{};
        _learnedCandidateScores = [NSMutableDictionary dictionary];
        _learnedAssociationScores = [NSMutableDictionary dictionary];
        _learnedPhraseScores = [NSMutableDictionary dictionary];
        _recentCommittedTextSegments = [NSMutableArray array];
        _recentCommittedCodeSegments = [NSMutableArray array];
        _persistedCandidateScoresByHash = [NSMutableDictionary dictionary];
        _persistedAssociationScoresByHash = [NSMutableDictionary dictionary];
        _traditionalCompatibilityTexts = [NSSet set];
        _hkscsCandidateTexts = [NSMutableSet set];
        _learningPath = [learningPath copy];
        _learningSalt = [NSUUID UUID].UUIDString;
        _learningEnabled = NO;
        _emptyCandidateProvider = [[MKEmptyCandidateProvider alloc] init];
        _mixedCandidateProvider = [[MKTableCandidateProvider alloc] initWithEngine:self source:nil];
        _candidateProvidersByMode = @{
            MKInputModeSucheng: [[MKTableCandidateProvider alloc] initWithEngine:self source:MKInputModeSucheng],
            MKInputModeSmartSucheng: [[MKTableCandidateProvider alloc] initWithEngine:self source:MKInputModeSucheng],
            MKInputModeCangjie: [[MKTableCandidateProvider alloc] initWithEngine:self source:MKInputModeCangjie],
            MKInputModePinyin: [[MKTableCandidateProvider alloc] initWithEngine:self source:MKInputModePinyin]
        };
        _associationProvider = [[MKSeedAssociationProvider alloc] initWithEngine:self];
        _cangjieDirectory = [cangjieDirectory copy];
        _pinyinPath = [pinyinPath copy];
        _resourceDirectory = [[pinyinPath stringByDeletingLastPathComponent] copy];
        NSString *associationPhrasesPath = [_resourceDirectory stringByAppendingPathComponent:@"association_phrases.tsv"];
        _associationGeneratedIndexPath = [[_resourceDirectory stringByAppendingPathComponent:@"association_generated.index"] copy];
        _smartPhrasesPath = [[_resourceDirectory stringByAppendingPathComponent:@"smart_phrases.tsv"] copy];
        NSString *suchengOrderGuardsPath = [_resourceDirectory stringByAppendingPathComponent:@"sucheng_order_guards.tsv"];
        _candidateOrderOverrides = [self loadCandidateOrderOverridesAtPath:suchengOrderGuardsPath];
        _preferredCangjieCodeByText = [NSMutableDictionary dictionary];
        _traditionalCompatibilityQuickCodeByText = [NSMutableDictionary dictionary];
        [self loadAssociationSeedAtPath:associationPhrasesPath];
        _hkscsDirectory = [[self hkscsDirectoryForResourceDirectory:_resourceDirectory
                                                  cangjieDirectory:_cangjieDirectory] copy];
        _candidateIndexDirectory = [[self candidateIndexDirectoryForResourceDirectory:_resourceDirectory
                                                                    cangjieDirectory:_cangjieDirectory] copy];
        [self ensureQuickDataLoaded];
        [self loadLearningState];
    }
    return self;
}

- (void)setLearningEnabled:(BOOL)learningEnabled {
    _learningEnabled = learningEnabled;
}

+ (NSString *)defaultLearningPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSURL *> *applicationSupportURLs = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                                                   inDomains:NSUserDomainMask];
    NSString *basePath = applicationSupportURLs.firstObject.path;
    if (basePath.length == 0) {
        basePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    }

    return [[basePath stringByAppendingPathComponent:@"PurrType"] stringByAppendingPathComponent:@"learning-rankings.json"];
}

+ (void)resetPersistedLearningStateAtDefaultPath {
    NSString *learningPath = [self defaultLearningPath];
    if (learningPath.length == 0) {
        return;
    }

    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:learningPath error:&error];
    if (error && error.code != NSFileNoSuchFileError) {
        NSLog(@"PurrType learning reset failed: %@", error.localizedDescription);
    }
}

- (void)ensureDataForMode:(MKInputMode)mode {
    if ([mode isEqualToString:MKInputModeEnglish]) {
        return;
    }

    if ([mode isEqualToString:MKInputModeCangjie]) {
        [self ensureCangjieDataLoaded];
        return;
    }

    if ([mode isEqualToString:MKInputModePinyin]) {
        [self ensurePinyinDataLoaded];
        return;
    }

    if ([mode isEqualToString:MKInputModeSucheng]) {
        [self ensureQuickDataLoaded];
        return;
    }

    if ([mode isEqualToString:MKInputModeSmartSucheng]) {
        [self ensureQuickDataLoaded];
        [self ensureGeneratedAssociationDataLoaded];
        [self ensureSmartPhraseDataLoaded];
        return;
    }

    [self ensureAllCandidateDataLoaded];
}

- (void)ensureAllCandidateDataLoaded {
    [self ensureQuickDataLoaded];
    [self ensureCangjieDataLoaded];
    [self ensurePinyinDataLoaded];
    [self ensureGeneratedAssociationDataLoaded];
    [self ensureSmartPhraseDataLoaded];
}

- (void)ensureDictionaryPronunciationCandidateIndexBuilt {
    if (self.dictionaryPronunciationCandidateIndexBuilt) {
        return;
    }

    [self ensureQuickDataLoaded];
    [self ensureCangjieDataLoaded];
    [self ensurePinyinDataLoaded];

    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *charactersByPronunciation = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *seenCharactersByPronunciation = [NSMutableDictionary dictionary];
    NSArray<NSString *> *sources = @[MKInputModeSucheng, MKInputModeCangjie, MKInputModePinyin];
    for (NSString *source in sources) {
        NSMutableSet<NSString *> *codeSet = [NSMutableSet setWithArray:[self candidateIndexCodesForSource:source]];
        NSArray<NSString *> *overlayCodes = [self.indexBySource[source] allKeys] ?: @[];
        [codeSet addObjectsFromArray:overlayCodes];

        for (NSString *code in codeSet) {
            NSArray<MKCandidate *> *bucket = [self candidateBucketForCode:code source:source];
            for (MKCandidate *candidate in bucket) {
                NSString *character = [self normalizedDictionaryFallbackCharacter:candidate.text];
                NSString *pronunciationKey = [self dictionaryPronunciationKeyForCharacter:character];
                if (character.length == 0 || pronunciationKey.length == 0) {
                    continue;
                }
                [self addDictionaryCandidateText:character
                                pronunciationKey:pronunciationKey
                       charactersByPronunciation:charactersByPronunciation
                    seenCharactersByPronunciation:seenCharactersByPronunciation];
            }
        }
    }

    NSMutableDictionary<NSString *, NSArray<NSString *> *> *index = [NSMutableDictionary dictionary];
    for (NSString *pronunciationKey in charactersByPronunciation) {
        NSArray<NSString *> *characters = charactersByPronunciation[pronunciationKey];
        if (characters.count >= 2) {
            index[pronunciationKey] = [characters copy];
        }
    }
    self.dictionaryPronunciationCandidateTextsByKey = [index copy];
    self.dictionaryPronunciationCandidateIndexBuilt = YES;
}

- (void)addDictionaryCandidateText:(NSString *)text
                   pronunciationKey:(NSString *)pronunciationKey
            charactersByPronunciation:(NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *)charactersByPronunciation
     seenCharactersByPronunciation:(NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *)seenCharactersByPronunciation {
    if (text.length == 0 || pronunciationKey.length == 0) {
        return;
    }

    NSMutableArray<NSString *> *characters = charactersByPronunciation[pronunciationKey];
    if (!characters) {
        characters = [NSMutableArray array];
        charactersByPronunciation[pronunciationKey] = characters;
    }

    NSMutableSet<NSString *> *seenCharacters = seenCharactersByPronunciation[pronunciationKey];
    if (!seenCharacters) {
        seenCharacters = [NSMutableSet set];
        seenCharactersByPronunciation[pronunciationKey] = seenCharacters;
    }

    if ([seenCharacters containsObject:text]) {
        return;
    }
    [seenCharacters addObject:text];
    [characters addObject:text];
}

- (NSString *)normalizedDictionaryFallbackCharacter:(NSString *)text {
    NSString *trimmed = [text ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0 || ![self isCandidateTextDisplayable:trimmed]) {
        return @"";
    }

    __block NSString *character = @"";
    __block NSUInteger characterCount = 0;
    [trimmed enumerateSubstringsInRange:NSMakeRange(0, trimmed.length)
                                options:NSStringEnumerationByComposedCharacterSequences
                             usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substringRange;
        (void)enclosingRange;
        character = substring ?: @"";
        characterCount += 1;
        if (characterCount > 1) {
            *stop = YES;
        }
    }];

    if (characterCount != 1 ||
        character.length == 0 ||
        ![character isEqualToString:trimmed] ||
        [character rangeOfString:@"^\\p{Han}$" options:NSRegularExpressionSearch].location == NSNotFound) {
        return @"";
    }
    return character;
}

- (NSString *)dictionaryPronunciationKeyForCharacter:(NSString *)character {
    NSString *normalizedCharacter = [self normalizedDictionaryFallbackCharacter:character ?: @""];
    if (normalizedCharacter.length == 0) {
        return @"";
    }

    NSString *pronunciation = [normalizedCharacter stringByApplyingTransform:NSStringTransformMandarinToLatin reverse:NO];
    if (pronunciation.length == 0) {
        return @"";
    }

    NSString *folded = [pronunciation stringByFoldingWithOptions:(NSDiacriticInsensitiveSearch | NSCaseInsensitiveSearch)
                                                         locale:nil];
    NSCharacterSet *separatorSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    NSArray<NSString *> *parts = [folded componentsSeparatedByCharactersInSet:separatorSet];
    return [[parts componentsJoinedByString:@""] lowercaseString];
}

- (void)appendDictionaryCandidateTextsFromArray:(NSArray<NSString *> *)candidateTexts
                                 recognizedText:(NSString *)recognizedText
                                       seenTexts:(NSMutableSet<NSString *> *)seenTexts
                                          result:(NSMutableArray<NSString *> *)result
                                           limit:(NSUInteger)limit {
    NSString *normalizedRecognizedText = [self normalizedDictionaryFallbackCharacter:recognizedText ?: @""];
    for (NSString *candidateText in candidateTexts ?: @[]) {
        if (result.count >= limit) {
            return;
        }
        NSString *candidate = [self normalizedDictionaryFallbackCharacter:candidateText ?: @""];
        if (candidate.length == 0 ||
            ([candidate isEqualToString:normalizedRecognizedText] && [seenTexts containsObject:candidate]) ||
            [seenTexts containsObject:candidate]) {
            continue;
        }
        [seenTexts addObject:candidate];
        [result addObject:candidate];
    }
}

- (void)appendDictionaryCandidateTextsForCode:(NSString *)code
                                         mode:(MKInputMode)mode
                               recognizedText:(NSString *)recognizedText
                                     seenTexts:(NSMutableSet<NSString *> *)seenTexts
                                        result:(NSMutableArray<NSString *> *)result
                                         limit:(NSUInteger)limit {
    if (code.length == 0 || result.count >= limit) {
        return;
    }

    NSUInteger fetchLimit = MAX(limit * 8, (NSUInteger)60);
    NSArray<MKCandidate *> *candidates = [self candidatesForInput:code limit:fetchLimit mode:mode];
    NSMutableArray<NSString *> *candidateTexts = [NSMutableArray arrayWithCapacity:candidates.count];
    for (MKCandidate *candidate in candidates) {
        [candidateTexts addObject:candidate.text ?: @""];
    }
    [self appendDictionaryCandidateTextsFromArray:candidateTexts
                                   recognizedText:recognizedText
                                         seenTexts:seenTexts
                                            result:result
                                             limit:limit];
}

- (void)ensureQuickDataLoaded {
    if (self.quickDataLoaded) {
        return;
    }

    self.quickDataLoaded = YES;
    self.quickCandidateIndex = [self openCandidateIndexNamed:@"quick-classic.index" source:MKInputModeSucheng];
    self.quickEntryCount += self.quickCandidateIndex.candidateCount;
    self.nextCandidateSequence = MAX(self.nextCandidateSequence, (NSUInteger)self.quickCandidateIndex.candidateCount);
    [self loadTraditionalCompatibilityCandidateSeedAtPath:
        [self.resourceDirectory stringByAppendingPathComponent:@"traditional_compatibility.tsv"]
                                      includingCangjie:NO
                                       includingSucheng:YES];
    [self loadHKSCSOverlayInDirectory:self.hkscsDirectory includingCangjie:NO includingSucheng:YES];
    self.preferredQuickCodeIndexBuilt = NO;
}

- (void)ensureCangjieDataLoaded {
    if (self.cangjieDataLoaded) {
        return;
    }

    self.cangjieDataLoaded = YES;
    self.cangjieCandidateIndex = [self openCandidateIndexNamed:@"cangjie5.index" source:MKInputModeCangjie];
    self.cangjieEntryCount += self.cangjieCandidateIndex.candidateCount;
    self.nextCandidateSequence = MAX(self.nextCandidateSequence, (NSUInteger)self.cangjieCandidateIndex.candidateCount);
    [self loadTraditionalCompatibilityCandidateSeedAtPath:
        [self.resourceDirectory stringByAppendingPathComponent:@"traditional_compatibility.tsv"]
                                      includingCangjie:YES
                                       includingSucheng:NO];
    [self loadHKSCSOverlayInDirectory:self.hkscsDirectory includingCangjie:YES includingSucheng:NO];
    self.preferredCangjieCodeIndexBuilt = NO;
}

- (void)ensurePinyinDataLoaded {
    if (self.pinyinDataLoaded) {
        return;
    }

    self.pinyinDataLoaded = YES;
    self.pinyinCandidateIndex = [self openCandidateIndexNamed:@"pinyin.index" source:MKInputModePinyin];
    self.pinyinEntryCount += self.pinyinCandidateIndex.candidateCount;
    self.nextCandidateSequence = MAX(self.nextCandidateSequence, (NSUInteger)self.pinyinCandidateIndex.candidateCount);
}

- (void)ensureGeneratedAssociationDataLoaded {
    if (self.generatedAssociationDataLoaded) {
        return;
    }

    self.generatedAssociationDataLoaded = YES;
    self.generatedAssociationIndex = [[MKGeneratedAssociationIndex alloc] initWithPath:self.associationGeneratedIndexPath];
}

- (void)ensureSmartPhraseDataLoaded {
    if (self.smartPhraseDataLoaded) {
        return;
    }

    self.smartPhraseDataLoaded = YES;
    [self ensureQuickDataLoaded];
    [self ensureGeneratedAssociationDataLoaded];
    [self loadSmartPhraseSeedAtPath:self.smartPhrasesPath];
    [self loadSmartPhraseSeedsFromAssociationPhrases];
    [self sortSmartPhraseBuckets];
}

- (NSArray<MKCandidate *> *)candidatesForInput:(NSString *)input limit:(NSUInteger)limit {
    return [self candidatesForInput:input limit:limit mode:MKInputModeMixed];
}

- (NSArray<MKCandidate *> *)candidatesForInput:(NSString *)input
                                         limit:(NSUInteger)limit
                                          mode:(MKInputMode)mode {
    NSString *normalized = [self normalizedInput:input];
    if (normalized.length == 0) {
        return @[];
    }

    [self ensureDataForMode:mode];
    NSArray<MKCandidate *> *candidates = [self candidatesByApplyingLearningRanking:[self candidateBucketForCode:normalized mode:mode]
                                                                              mode:mode];
    if ([mode isEqualToString:MKInputModeSmartSucheng]) {
        candidates = [self smartSuchengCandidatesForInput:normalized baseCandidates:candidates];
    } else if ([mode isEqualToString:MKInputModePinyin]) {
        candidates = [self pinyinCandidatesForInput:normalized baseCandidates:candidates];
    }

    NSArray<MKCandidate *> *result = candidates;
    if (candidates.count > limit) {
        result = [candidates subarrayWithRange:NSMakeRange(0, limit)];
    }
    return [result copy];
}

- (BOOL)hasCandidatesOrPrefixesForInput:(NSString *)input {
    return [self hasCandidatesOrPrefixesForInput:input mode:MKInputModeMixed];
}

- (NSArray<MKCandidate *> *)associatedCandidatesForText:(NSString *)text limit:(NSUInteger)limit {
    return [self associatedCandidatesForText:text limit:limit mode:MKInputModeSucheng];
}

- (NSArray<MKCandidate *> *)associatedCandidatesForText:(NSString *)text
                                                  limit:(NSUInteger)limit
                                                   mode:(MKInputMode)mode {
    return [self.associationProvider associatedCandidatesForText:text limit:limit mode:mode];
}

- (void)recordSelectionForCandidate:(MKCandidate *)candidate
                        previousText:(NSString *)previousText
                                mode:(MKInputMode)mode {
    if (candidate.text.length == 0 || candidate.code.length == 0 || candidate.source.length == 0) {
        return;
    }

    if (![self shouldApplyLearningRankingForMode:mode]) {
        return;
    }

        if ([candidate.source isEqualToString:@"association"]) {
            BOOL persistedChanged = NO;
            [self incrementLearningScoreForKey:candidate.code
                                          text:candidate.text
                                         table:self.learnedAssociationScores];
            persistedChanged = [self incrementPersistedLearningScoreForCategory:MKLearningCategoryAssociation
                                                                            key:candidate.code
                                                                           text:candidate.text
                                                                          table:self.persistedAssociationScoresByHash] || persistedChanged;
            if (persistedChanged) {
                [self saveLearningState];
            }
        } else if ([candidate.source isEqualToString:@"learned_phrase"]) {
            BOOL changed = [self incrementLearningScoreForKey:candidate.code
                                                         text:candidate.text
                                                        table:self.learnedPhraseScores];
            if (changed) {
                [self addLearnedPhrasePrefixesForCode:candidate.code];
            }
        } else {
            BOOL persistedChanged = NO;
            NSString *candidateKey = [self overrideKeyForSource:candidate.source code:candidate.code];
            [self incrementLearningScoreForKey:[self overrideKeyForSource:candidate.source code:candidate.code]
                                          text:candidate.text
                                         table:self.learnedCandidateScores];
            persistedChanged = [self incrementPersistedLearningScoreForCategory:MKLearningCategoryCandidate
                                                                            key:candidateKey
                                                                           text:candidate.text
                                                                          table:self.persistedCandidateScoresByHash] || persistedChanged;

            NSString *associationKey = [self lastDisplayableCharacterInText:previousText ?: @""];
            if (associationKey.length > 0) {
                [self incrementLearningScoreForKey:associationKey
                                              text:candidate.text
                                             table:self.learnedAssociationScores];
                persistedChanged = [self incrementPersistedLearningScoreForCategory:MKLearningCategoryAssociation
                                                                                key:associationKey
                                                                               text:candidate.text
                                                                              table:self.persistedAssociationScoresByHash] || persistedChanged;
            }

            if (persistedChanged) {
                [self saveLearningState];
            }
    }
}

- (void)recordCommittedCandidateText:(NSString *)text
                                 code:(NSString *)code
                                 mode:(MKInputMode)mode {
    if (![mode isEqualToString:MKInputModeSmartSucheng] ||
        text.length == 0 ||
        ![self shouldApplyLearningRankingForMode:mode]) {
        return;
    }

    NSString *normalizedCode = [self normalizedInput:code ?: @""];
    NSString *exactCode = [self isAlphabeticInputCode:normalizedCode] ? normalizedCode : @"";
    [self.recentCommittedTextSegments addObject:text];
    [self.recentCommittedCodeSegments addObject:exactCode];
    [self trimRecentCommittedSegments];
    [self recordRecentCommittedSuffixesForLearningWithMode:mode];

    NSString *recentText = [self.recentCommittedTextSegments componentsJoinedByString:@""];
    if (recentText.length > 0) {
        [self recordCommittedText:recentText mode:mode];
    }
}

- (void)recordCommittedText:(NSString *)text mode:(MKInputMode)mode {
    if (![self shouldApplyLearningRankingForMode:mode]) {
        return;
    }

    [self ensureDataForMode:mode];
    NSArray<NSString *> *characters = [self displayableCharactersInText:text ?: @""];
    if (characters.count < 2) {
        return;
    }

        NSUInteger maxLength = MIN(MKLearnedPhraseMaximumCharacterLength, characters.count);
        for (NSUInteger length = 2; length <= maxLength; length += 1) {
            NSRange range = NSMakeRange(characters.count - length, length);
            NSString *phrase = [[characters subarrayWithRange:range] componentsJoinedByString:@""];
            NSString *code = [self quickCodeForPhraseText:phrase];
            if (code.length == 0 || code.length > MKSmartPhraseMaximumInputLength) {
                continue;
            }

            if ([self incrementLearningScoreForKey:code text:phrase table:self.learnedPhraseScores]) {
                [self addLearnedPhrasePrefixesForCode:code];
            }
    }
}

- (void)recordCommittedText:(NSString *)text code:(NSString *)code mode:(MKInputMode)mode {
    [self learnCommittedText:text code:code mode:mode];
}

- (void)recordCommittedTexts:(NSArray<NSString *> *)texts
                        codes:(NSArray<NSString *> *)codes
                         mode:(MKInputMode)mode {
    if (texts.count == 0 || texts.count != codes.count) {
        return;
    }

    for (NSUInteger index = 0; index < texts.count; index += 1) {
        [self learnCommittedText:texts[index] code:codes[index] mode:mode];
    }
}

- (void)resetLearningState {
    [self.learnedCandidateScores removeAllObjects];
    [self.learnedAssociationScores removeAllObjects];
    [self.learnedPhraseScores removeAllObjects];
    [self.learnedPhrasePrefixes removeAllObjects];
    [self resetLearningContext];
    [self.persistedCandidateScoresByHash removeAllObjects];
    [self.persistedAssociationScoresByHash removeAllObjects];
    self.learningSalt = [NSUUID UUID].UUIDString;

    if (self.learningPath.length > 0) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:self.learningPath error:&error];
        if (error && error.code != NSFileNoSuchFileError) {
            NSLog(@"PurrType learning reset failed: %@", error.localizedDescription);
        }
    }
}

- (void)resetLearningContext {
    [self.recentCommittedTextSegments removeAllObjects];
    [self.recentCommittedCodeSegments removeAllObjects];
}

- (BOOL)learnCommittedText:(NSString *)text code:(NSString *)code mode:(MKInputMode)mode {
    if (![self shouldApplyLearningRankingForMode:mode]) {
        return NO;
    }

    [self ensureDataForMode:mode];
    NSString *normalizedCode = [self normalizedInput:code ?: @""];
    if (![self isAlphabeticInputCode:normalizedCode] ||
        normalizedCode.length > MKSmartPhraseMaximumInputLength) {
        return NO;
    }

    NSArray<NSString *> *characters = [self displayableCharactersInText:text ?: @""];
    if (characters.count < 2 || characters.count > MKLearnedPhraseMaximumCharacterLength) {
        return NO;
    }

    NSString *phrase = [characters componentsJoinedByString:@""];
    if (![self isLearningTextSafe:phrase]) {
        return NO;
    }

    if ([self incrementLearningScoreForKey:normalizedCode text:phrase table:self.learnedPhraseScores]) {
        [self addLearnedPhrasePrefixesForCode:normalizedCode];
        return YES;
    }
    return NO;
}

- (BOOL)hasCandidatesOrPrefixesForInput:(NSString *)input mode:(MKInputMode)mode {
    NSString *normalized = [self normalizedInput:input];
    if (normalized.length == 0) {
        return NO;
    }

    [self ensureDataForMode:mode];
    if ([mode isEqualToString:MKInputModeSmartSucheng] &&
        [self hasSmartSuchengPhraseCandidateOrPrefixForInput:normalized]) {
        return YES;
    }

    if ([[self candidateProviderForMode:mode] hasCandidatesOrPrefixesForInput:normalized]) {
        return YES;
    }

    if ([mode isEqualToString:MKInputModePinyin]) {
        return [self hasSegmentedPinyinCandidateOrPrefixForInput:normalized];
    }

    return NO;
}

- (BOOL)isLikelyRawToken:(NSString *)input {
    return [self isLikelyRawToken:input mode:MKInputModeMixed];
}

- (BOOL)prefersRawEnglishForInput:(NSString *)input mode:(MKInputMode)mode {
    NSString *normalized = [self normalizedInput:input];
    if (![self isAlphabeticInputCode:normalized]) {
        return [self isLikelyRawToken:normalized mode:mode];
    }

    if ([mode isEqualToString:MKInputModeEnglish]) {
        return YES;
    }

    [self ensureDataForMode:mode];
    if ([self isLikelyRawToken:normalized mode:mode]) {
        return YES;
    }

    if ([mode isEqualToString:MKInputModeSucheng]) {
        return normalized.length >= 3 && [self candidateBucketForCode:normalized mode:mode].count == 0;
    }

    if ([mode isEqualToString:MKInputModeCangjie]) {
        return normalized.length > 5 && [self candidateBucketForCode:normalized mode:mode].count == 0;
    }

    if ([mode isEqualToString:MKInputModeSmartSucheng]) {
        if ([self isProtectedSmartSuchengPhraseInput:normalized]) {
            return NO;
        }
        if ([self isCommonEnglishWordOrPrefix:normalized] &&
            [self candidateBucketForCode:normalized mode:mode].count == 0) {
            return YES;
        }
        return [self looksLikeEnglishWordInput:normalized] &&
               [self candidateBucketForCode:normalized mode:mode].count == 0;
    }

    if ([mode isEqualToString:MKInputModePinyin]) {
        return [self looksLikeEnglishWordInput:normalized] &&
               ![self hasCandidatesOrPrefixesForInput:normalized mode:mode];
    }

    return NO;
}

- (BOOL)looksLikeRawEnglishInput:(NSString *)input mode:(MKInputMode)mode {
    NSString *normalized = [self normalizedInput:input];
    if (![self isAlphabeticInputCode:normalized]) {
        return [self isLikelyRawToken:normalized mode:mode];
    }
    if ([self isLikelyRawToken:normalized mode:mode]) {
        return YES;
    }
    return [self looksLikeEnglishWordInput:normalized];
}

- (BOOL)isLikelyRawToken:(NSString *)input mode:(MKInputMode)mode {
    NSString *normalized = [self normalizedInput:input];
    if (normalized.length == 0) {
        return NO;
    }

    NSCharacterSet *rawTokenCharacters = [NSCharacterSet characterSetWithCharactersInString:@"@/:._-"];
    if ([normalized rangeOfCharacterFromSet:rawTokenCharacters].location != NSNotFound) {
        return YES;
    }

    if ([normalized hasPrefix:@"http"] || [normalized hasPrefix:@"www"]) {
        return YES;
    }

    [self ensureDataForMode:mode];
    if ([mode isEqualToString:MKInputModeSmartSucheng] &&
        [self hasSmartSuchengPhraseCandidateOrPrefixForInput:normalized]) {
        return NO;
    }

    if ([mode isEqualToString:MKInputModePinyin] &&
        [self hasSegmentedPinyinCandidateOrPrefixForInput:normalized]) {
        return NO;
    }

    return normalized.length > 8 && [self candidateBucketForCode:normalized mode:mode].count == 0;
}

- (NSString *)preferredSuchengCodeForText:(NSString *)text {
    [self ensureQuickDataLoaded];
    return [self preferredQuickCodeForText:text ?: @""] ?: @"";
}

- (NSString *)preferredCangjieCodeForText:(NSString *)text {
    [self ensureCangjieDataLoaded];
    if (text.length == 0) {
        return @"";
    }

    if (!self.preferredCangjieCodeIndexBuilt) {
        [self rebuildPreferredCangjieCodeIndex];
    }

    NSString *cachedCode = self.preferredCangjieCodeByText[text];
    return cachedCode.length > 0 ? cachedCode : @"";
}

- (NSArray<NSString *> *)dictionaryCandidateTextsForCharacter:(NSString *)character limit:(NSUInteger)limit {
    NSString *recognizedText = [self normalizedDictionaryFallbackCharacter:character ?: @""];
    if (recognizedText.length == 0 || limit == 0) {
        return @[];
    }

    NSMutableArray<NSString *> *result = [NSMutableArray arrayWithObject:recognizedText];
    NSMutableSet<NSString *> *seenTexts = [NSMutableSet setWithObject:recognizedText];
    NSString *pronunciationKey = [self dictionaryPronunciationKeyForCharacter:recognizedText];
    if (pronunciationKey.length > 0) {
        [self appendDictionaryCandidateTextsForCode:pronunciationKey
                                               mode:MKInputModePinyin
                                     recognizedText:recognizedText
                                           seenTexts:seenTexts
                                              result:result
                                               limit:limit];
    }

    if (result.count < limit) {
        NSString *quickCode = [self preferredSuchengCodeForText:recognizedText];
        [self appendDictionaryCandidateTextsForCode:quickCode
                                               mode:MKInputModeSucheng
                                     recognizedText:recognizedText
                                           seenTexts:seenTexts
                                              result:result
                                               limit:limit];
    }

    if (result.count < limit) {
        NSString *cangjieCode = [self preferredCangjieCodeForText:recognizedText];
        [self appendDictionaryCandidateTextsForCode:cangjieCode
                                               mode:MKInputModeCangjie
                                     recognizedText:recognizedText
                                           seenTexts:seenTexts
                                              result:result
                                               limit:limit];
    }

    if (result.count < limit && pronunciationKey.length > 0) {
        [self ensureDictionaryPronunciationCandidateIndexBuilt];
        NSArray<NSString *> *pronunciationCandidates = self.dictionaryPronunciationCandidateTextsByKey[pronunciationKey] ?: @[];
        [self appendDictionaryCandidateTextsFromArray:pronunciationCandidates
                                       recognizedText:recognizedText
                                             seenTexts:seenTexts
                                                result:result
                                                 limit:limit];
    }

    if (result.count < 2) {
        return @[];
    }
    if (result.count > limit) {
        return [result subarrayWithRange:NSMakeRange(0, limit)];
    }
    return [result copy];
}

- (BOOL)isProtectedSmartSuchengPhraseInput:(NSString *)input {
    if (input.length == 0) {
        return NO;
    }

    if ([self.smartPhrasePrefixes containsObject:input] ||
        [self.learnedPhrasePrefixes containsObject:input] ||
        [self exactSmartPhraseCandidatesForInput:input].count > 0 ||
        [self learnedPhraseCandidatesForInput:input].count > 0) {
        return YES;
    }

    return NO;
}

- (BOOL)shouldSuppressGeneratedSmartPhrasesForInput:(NSString *)input
                                     baseCandidates:(NSArray<MKCandidate *> *)baseCandidates {
    if (baseCandidates.count > 0 || [self isProtectedSmartSuchengPhraseInput:input]) {
        return NO;
    }

    return [self isCommonEnglishWordOrPrefix:input] ||
           (input.length <= 5 && [self looksLikeEnglishWordInput:input]);
}

- (BOOL)looksLikeEnglishWordInput:(NSString *)input {
    if (input.length < 3 || ![self containsEnglishVowelInInput:input]) {
        return NO;
    }

    if ([self isCommonEnglishWordOrPrefix:input]) {
        return YES;
    }

    return input.length >= 5;
}

- (BOOL)containsEnglishVowelInInput:(NSString *)input {
    return [input rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"aeiou"]].location != NSNotFound;
}

- (BOOL)isCommonEnglishWordOrPrefix:(NSString *)input {
    static NSArray<NSString *> *words = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        words = @[
            @"setting", @"settings", @"search", @"system", @"window", @"keyboard",
            @"english", @"classic", @"install", @"installer", @"package", @"build",
            @"github", @"terminal", @"folder", @"file", @"google", @"apple",
            @"safari", @"chrome", @"docker", @"python", @"swift", @"xcode",
            @"login", @"password", @"email", @"server", @"client", @"commit",
            @"branch", @"status", @"readme", @"license", @"version", @"test",
            @"new", @"next", @"now", @"old", @"use", @"user", @"users", @"using",
            @"app", @"apps", @"mac", @"ios", @"web", @"win", @"windows", @"code",
            @"type", @"typing", @"input", @"mode", @"menu", @"page", @"space",
            @"left", @"right", @"shift", @"option", @"control", @"return",
            @"yes", @"not", @"the", @"and", @"for", @"you", @"your", @"our",
            @"home", @"about", @"after", @"before", @"from", @"with", @"without",
            @"this", @"that", @"there", @"their", @"then", @"than", @"can",
            @"cant", @"cannot", @"will", @"would", @"should", @"could", @"make",
            @"made", @"more", @"less", @"open", @"close", @"copy", @"paste",
            @"delete", @"edit", @"save"
        ];
    });

    for (NSString *word in words) {
        if ([word hasPrefix:input] || [input hasPrefix:word]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isLearningTextSafe:(NSString *)text {
    if (text.length == 0 ||
        text.length > MKLearnedPhraseMaximumCharacterLength ||
        ![self isCandidateTextDisplayable:text] ||
        ![self isTraditionalCandidateText:text] ||
        [self containsSensitiveLearningKeyword:text]) {
        return NO;
    }

    __block BOOL safe = YES;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substringRange;
        (void)enclosingRange;
        uint32_t scalar = [self firstUnicodeScalarInString:substring];
        if (![self isCJKScalarForLearning:scalar]) {
            safe = NO;
            *stop = YES;
        }
    }];
    return safe;
}

- (BOOL)containsSensitiveLearningKeyword:(NSString *)text {
    static NSArray<NSString *> *keywords = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keywords = @[
            @"密碼", @"密码", @"口令", @"通行碼", @"驗證", @"验证", @"驗證碼", @"验证码",
            @"登入", @"登錄", @"登录", @"帳號", @"账号", @"賬號", @"戶口", @"户口",
            @"銀行", @"银行", @"信用卡", @"提款卡", @"借記卡", @"金融卡",
            @"身份證", @"身分證", @"證件", @"证件", @"護照", @"护照",
            @"電話", @"手机", @"手機", @"地址", @"住址", @"生日", @"出生",
            @"保安", @"安全碼", @"安全码", @"私鑰", @"私钥", @"助記詞", @"助记词",
            @"金鑰", @"金钥", @"錢包", @"钱包", @"轉帳", @"转账"
        ];
    });

    for (NSString *keyword in keywords) {
        if ([text rangeOfString:keyword].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isCJKScalarForLearning:(uint32_t)scalar {
    return [self isHanScalar:scalar];
}

- (NSString *)normalizedInput:(NSString *)input {
    return [[input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
}

- (BOOL)isAlphabeticInputCode:(NSString *)input {
    if (input.length == 0) {
        return NO;
    }

    for (NSUInteger index = 0; index < input.length; index += 1) {
        unichar character = [input characterAtIndex:index];
        if (character < 'a' || character > 'z') {
            return NO;
        }
    }
    return YES;
}

- (NSString *)hkscsDirectoryForResourceDirectory:(NSString *)resourceDirectory
                               cangjieDirectory:(NSString *)cangjieDirectory {
    NSArray<NSString *> *candidates = @[
        [resourceDirectory stringByAppendingPathComponent:@"HKSCS"],
        [resourceDirectory stringByAppendingPathComponent:@"hkscs"],
        [[cangjieDirectory stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"hkscs"],
        [[cangjieDirectory stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"HKSCS"]
    ];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *directory in candidates) {
        NSString *jsonPath = [directory stringByAppendingPathComponent:@"HKSCS2016.json"];
        if ([fileManager fileExistsAtPath:jsonPath]) {
            return directory;
        }
    }

    return [resourceDirectory stringByAppendingPathComponent:@"HKSCS"];
}

- (NSString *)candidateIndexDirectoryForResourceDirectory:(NSString *)resourceDirectory
                                        cangjieDirectory:(NSString *)cangjieDirectory {
    NSArray<NSString *> *candidates = @[
        [resourceDirectory stringByAppendingPathComponent:@"CandidateTables"],
        [[cangjieDirectory stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"CandidateTables"]
    ];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *directory in candidates) {
        NSString *quickIndexPath = [directory stringByAppendingPathComponent:@"quick-classic.index"];
        NSString *cangjieIndexPath = [directory stringByAppendingPathComponent:@"cangjie5.index"];
        NSString *pinyinIndexPath = [directory stringByAppendingPathComponent:@"pinyin.index"];
        if ([fileManager fileExistsAtPath:quickIndexPath] &&
            [fileManager fileExistsAtPath:cangjieIndexPath] &&
            [fileManager fileExistsAtPath:pinyinIndexPath]) {
            return directory;
        }
    }

    return [resourceDirectory stringByAppendingPathComponent:@"CandidateTables"];
}

- (MKCandidateTableIndex *)openCandidateIndexNamed:(NSString *)fileName source:(NSString *)source {
    NSString *path = [self.candidateIndexDirectory stringByAppendingPathComponent:fileName];
    MKCandidateTableIndex *index = [[MKCandidateTableIndex alloc] initWithPath:path source:source];
    if (!index) {
        NSLog(@"PurrType candidate index unavailable: %@", path);
    }
    return index;
}

- (NSArray<NSString *> *)normalizedHKSCSCangjieCodesFromRawValue:(NSString *)rawValue {
    if (rawValue.length == 0) {
        return @[];
    }

    NSMutableArray<NSString *> *codes = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSArray<NSString *> *rawCodes = [rawValue componentsSeparatedByString:@","];
    for (NSString *rawCode in rawCodes) {
        NSString *code = [self normalizedHKSCSCangjieCode:rawCode];
        if (code.length == 0 || [seen containsObject:code]) {
            continue;
        }
        [seen addObject:code];
        [codes addObject:code];
    }
    return codes;
}

- (NSString *)normalizedHKSCSCangjieCode:(NSString *)rawCode {
    NSString *trimmed = [rawCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return @"";
    }

    static NSDictionary<NSString *, NSString *> *radicalCodeByText = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        radicalCodeByText = @{
            @"日": @"a", @"月": @"b", @"金": @"c", @"木": @"d", @"水": @"e",
            @"火": @"f", @"土": @"g", @"竹": @"h", @"戈": @"i", @"十": @"j",
            @"大": @"k", @"中": @"l", @"一": @"m", @"弓": @"n", @"人": @"o",
            @"心": @"p", @"手": @"q", @"口": @"r", @"尸": @"s", @"廿": @"t",
            @"山": @"u", @"女": @"v", @"田": @"w", @"難": @"x", @"卜": @"y",
            @"重": @"z"
        };
    });

    NSMutableString *normalized = [NSMutableString stringWithCapacity:trimmed.length];
    for (NSUInteger index = 0; index < trimmed.length; index += 1) {
        unichar character = [trimmed characterAtIndex:index];
        if (character >= 'A' && character <= 'Z') {
            [normalized appendFormat:@"%c", (char)(character + ('a' - 'A'))];
            continue;
        }
        if (character >= 'a' && character <= 'z') {
            [normalized appendFormat:@"%C", character];
            continue;
        }

        NSString *component = [trimmed substringWithRange:NSMakeRange(index, 1)];
        NSString *mapped = radicalCodeByText[component];
        if (mapped.length == 0) {
            return @"";
        }
        [normalized appendString:mapped];
    }

    if (normalized.length == 0 || normalized.length > 5 || ![self isAlphabeticInputCode:normalized]) {
        return @"";
    }
    return normalized;
}

- (NSString *)quickCodeFromCangjieCode:(NSString *)cangjieCode {
    NSString *normalized = [self normalizedInput:cangjieCode ?: @""];
    if (![self isAlphabeticInputCode:normalized]) {
        return @"";
    }
    if (normalized.length <= 1) {
        return normalized;
    }

    NSString *first = [normalized substringToIndex:1];
    NSString *last = [normalized substringFromIndex:normalized.length - 1];
    return [first stringByAppendingString:last];
}

- (void)loadTraditionalCompatibilityCandidateSeedAtPath:(NSString *)path
                                      includingCangjie:(BOOL)includingCangjie
                                       includingSucheng:(BOOL)includingSucheng {
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (contents.length == 0) {
        return;
    }

    NSMutableArray<NSDictionary<NSString *, NSString *> *> *fixtures = [NSMutableArray array];
    NSMutableSet<NSString *> *compatibilityTexts = [NSMutableSet set];
    NSArray<NSString *> *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if (line.length == 0 || [line hasPrefix:@"#"]) {
            continue;
        }

        NSArray<NSString *> *columns = [line componentsSeparatedByString:@"\t"];
        if (columns.count < 3) {
            continue;
        }

        NSString *text = columns[0];
        NSString *quickCode = [self normalizedInput:columns[1]];
        NSString *cangjieCode = [self normalizedInput:columns[2]];
        if (text.length == 0 || quickCode.length == 0 || cangjieCode.length == 0) {
            continue;
        }

        [compatibilityTexts addObject:text];
        self.traditionalCompatibilityQuickCodeByText[text] = quickCode;
        [fixtures addObject:@{@"text": text, @"quick": quickCode, @"cangjie": cangjieCode}];
    }

    self.traditionalCompatibilityTexts = [compatibilityTexts copy];
    for (NSDictionary<NSString *, NSString *> *fixture in fixtures) {
        NSString *text = fixture[@"text"];
        if (includingSucheng) {
            [self addCandidateText:text
                              code:fixture[@"quick"]
                            source:@"quick"
                            weight:80
           allowingTraditionalCompatibility:YES];
            self.quickEntryCount += 1;
        }

        if (includingCangjie) {
            [self addCandidateText:text
                              code:fixture[@"cangjie"]
                            source:@"cangjie"
                            weight:80
           allowingTraditionalCompatibility:YES];
            self.cangjieEntryCount += 1;
        }
    }
}

- (void)loadHKSCSOverlayInDirectory:(NSString *)directory
                  includingCangjie:(BOOL)includingCangjie
                   includingSucheng:(BOOL)includingSucheng {
    NSString *path = [directory stringByAppendingPathComponent:@"HKSCS2016.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) {
        return;
    }
    if (data.length >= 3) {
        const unsigned char *bytes = data.bytes;
        if (bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
            data = [data subdataWithRange:NSMakeRange(3, data.length - 3)];
        }
    }

    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![json isKindOfClass:[NSArray class]]) {
        return;
    }

    for (id row in (NSArray *)json) {
        if (![row isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSDictionary *record = (NSDictionary *)row;
        NSString *text = [record[@"char"] isKindOfClass:[NSString class]] ? record[@"char"] : @"";
        NSString *rawCangjie = [record[@"cangjie"] isKindOfClass:[NSString class]] ? record[@"cangjie"] : @"";
        if (text.length == 0 ||
            rawCangjie.length == 0 ||
            ![self isHKSCSCandidateTextDisplayable:text] ||
            ![self isHKSCSChineseCandidateText:text]) {
            continue;
        }

        NSArray<NSString *> *cangjieCodes = [self normalizedHKSCSCangjieCodesFromRawValue:rawCangjie];
        if (cangjieCodes.count == 0) {
            continue;
        }

        [self.hkscsCandidateTexts addObject:text];

        if (includingCangjie) {
            for (NSString *code in cangjieCodes) {
                if (![self candidateText:text existsInSource:@"cangjie" code:code]) {
                    [self addCandidateText:text
                                      code:code
                                    source:@"cangjie"
                                    weight:MKHKSCSOverlayCangjieWeight
                   allowingTraditionalCompatibility:YES];
                    self.cangjieEntryCount += 1;
                }
            }
        }

        if (includingSucheng) {
            NSMutableSet<NSString *> *quickCodes = [NSMutableSet set];
            for (NSString *cangjieCode in cangjieCodes) {
                NSString *quickCode = [self quickCodeFromCangjieCode:cangjieCode];
                if (quickCode.length > 0 && ![quickCodes containsObject:quickCode]) {
                    [quickCodes addObject:quickCode];
                    if (![self candidateText:text existsInSource:@"quick" code:quickCode]) {
                        [self addCandidateText:text
                                          code:quickCode
                                        source:@"quick"
                                        weight:MKHKSCSOverlayQuickWeight
                       allowingTraditionalCompatibility:YES];
                        self.quickEntryCount += 1;
                    }
                }
            }
        }
    }
}

- (void)loadSmartPhraseSeedAtPath:(NSString *)path {
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (contents.length == 0) {
        return;
    }

    NSArray<NSString *> *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if (line.length == 0 || [line hasPrefix:@"#"]) {
            continue;
        }

        NSArray<NSString *> *columns = [line componentsSeparatedByString:@"\t"];
        if (columns.count < 2) {
            continue;
        }

        NSString *code = [self normalizedInput:columns[0]];
        NSString *text = columns[1];
        NSInteger weight = 5000;
        if (columns.count >= 3) {
            weight += [columns[2] integerValue];
        }

        if (code.length == 0 ||
            text.length == 0 ||
            ![self isCandidateTextDisplayable:text] ||
            ![self isTraditionalCandidateText:text]) {
            continue;
        }

        [self addSmartPhraseText:text code:code weight:weight];
        [self addAssociationPhraseText:text];
    }
}

- (void)loadSmartPhraseSeedsFromAssociationPhrases {
    for (NSString *phrase in self.associationPhraseSeeds) {
        NSString *code = [self quickCodeForPhraseText:phrase];
        if (code.length == 0 || code.length > MKSmartPhraseMaximumInputLength) {
            continue;
        }

        NSInteger weight = 4550 + (NSInteger)MIN((NSUInteger)900, phrase.length * 80);
        [self addSmartPhraseText:phrase code:code weight:weight];
    }
}

- (void)addSmartPhraseText:(NSString *)text code:(NSString *)code weight:(NSInteger)weight {
    if (code.length == 0 ||
        text.length == 0 ||
        ![self isCandidateTextDisplayable:text] ||
        ![self isTraditionalCandidateText:text]) {
        return;
    }

    NSMutableArray<MKCandidate *> *bucket = self.smartPhraseIndex[code];
    if (!bucket) {
        bucket = [NSMutableArray array];
        self.smartPhraseIndex[code] = bucket;
    }

    for (MKCandidate *candidate in bucket) {
        if ([candidate.text isEqualToString:text]) {
            return;
        }
    }

    [bucket addObject:[[MKCandidate alloc] initWithText:text
                                                   code:code
                                                 source:@"smart_phrase"
                                                 weight:weight
                                               sequence:self.nextSmartPhraseSequence]];
    self.nextSmartPhraseSequence += 1;

    for (NSUInteger length = 1; length <= code.length; length += 1) {
        [self.smartPhrasePrefixes addObject:[code substringToIndex:length]];
    }
}

- (void)addLearnedPhrasePrefixesForCode:(NSString *)code {
    if (code.length == 0) {
        return;
    }

    for (NSUInteger length = 1; length <= code.length; length += 1) {
        [self.learnedPhrasePrefixes addObject:[code substringToIndex:length]];
    }
}

- (void)rebuildLearnedPhrasePrefixes {
    [self.learnedPhrasePrefixes removeAllObjects];
    for (NSString *code in self.learnedPhraseScores) {
        [self addLearnedPhrasePrefixesForCode:code];
    }
}

- (void)sortSmartPhraseBuckets {
    for (NSString *code in self.smartPhraseIndex) {
        [self sortCandidateBucket:self.smartPhraseIndex[code]];
    }
}

- (void)loadAssociationSeedAtPath:(NSString *)path {
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (contents.length == 0) {
        return;
    }

    NSArray<NSString *> *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *rawLine in lines) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (line.length == 0 || [line hasPrefix:@"#"]) {
            continue;
        }

        NSArray<NSString *> *columns = [line componentsSeparatedByString:@"\t"];
        if (columns.count == 1) {
            [self addAssociationPhraseText:columns.firstObject];
            [self addAssociationPhraseSeedText:columns.firstObject];
            continue;
        }

        NSString *key = columns.firstObject;
        for (NSUInteger index = 1; index < columns.count; index += 1) {
            [self addAssociationFromText:key toText:columns[index]];
        }
    }
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)loadCandidateOrderOverridesAtPath:(NSString *)path {
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (contents.length == 0) {
        return @{};
    }

    NSMutableDictionary<NSString *, NSArray<NSString *> *> *overrides = [NSMutableDictionary dictionary];
    NSArray<NSString *> *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if (line.length == 0 || [line hasPrefix:@"#"]) {
            continue;
        }

        NSArray<NSString *> *columns = [line componentsSeparatedByString:@"\t"];
        if (columns.count < 3) {
            continue;
        }

        NSString *source = [self normalizedInput:columns[0]];
        NSString *code = [self normalizedInput:columns[1]];
        if (source.length == 0 || code.length == 0) {
            continue;
        }

        NSMutableArray<NSString *> *orderedTexts = [NSMutableArray array];
        NSMutableSet<NSString *> *seen = [NSMutableSet set];
        for (NSUInteger index = 2; index < columns.count; index += 1) {
            NSString *text = columns[index];
            if (text.length == 0 || [seen containsObject:text]) {
                continue;
            }
            [seen addObject:text];
            [orderedTexts addObject:text];
        }

        if (orderedTexts.count > 0) {
            overrides[[self overrideKeyForSource:source code:code]] = [orderedTexts copy];
        }
    }

    return [overrides copy];
}

- (void)loadLearningState {
    if (self.learningPath.length == 0) {
        return;
    }

    NSData *data = [NSData dataWithContentsOfFile:self.learningPath];
    if (data.length == 0) {
        return;
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![object isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSDictionary *root = object;
    NSNumber *version = [root[MKLearningVersionKey] isKindOfClass:[NSNumber class]] ? root[MKLearningVersionKey] : nil;
    NSString *salt = [root[MKLearningSaltKey] isKindOfClass:[NSString class]] ? root[MKLearningSaltKey] : nil;
    if (version.integerValue != MKLearningVersion || salt.length == 0) {
        return;
    }

    self.learningSalt = salt;
    self.persistedCandidateScoresByHash = [self sanitizedPersistentLearningTableFromObject:root[MKLearningCandidatesKey]];
    self.persistedAssociationScoresByHash = [self sanitizedPersistentLearningTableFromObject:root[MKLearningAssociationsKey]];
}

- (NSMutableDictionary<NSString *, NSNumber *> *)sanitizedPersistentLearningTableFromObject:(id)object {
    NSMutableDictionary<NSString *, NSNumber *> *table = [NSMutableDictionary dictionary];
    if (![object isKindOfClass:[NSDictionary class]]) {
        return table;
    }

    NSCharacterSet *hexCharacters = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    NSDictionary *rawTable = object;
    for (id rawHash in rawTable) {
        if (![rawHash isKindOfClass:[NSString class]]) {
            continue;
        }

        NSString *hash = rawHash;
        if (hash.length != CC_SHA256_DIGEST_LENGTH * 2 ||
            [[hash stringByTrimmingCharactersInSet:hexCharacters] length] > 0) {
            continue;
        }

        id rawScore = rawTable[rawHash];
        if (![rawScore respondsToSelector:@selector(integerValue)]) {
            continue;
        }

        NSInteger score = [rawScore integerValue];
        if (score <= 0) {
            continue;
        }
        table[hash] = @(MIN(score, MKMaximumLearningScore));
    }
    return table;
}

- (void)saveLearningState {
    if (self.learningPath.length == 0) {
        return;
    }

    if (self.persistedCandidateScoresByHash.count == 0 &&
        self.persistedAssociationScoresByHash.count == 0) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:self.learningPath error:&error];
        if (error && error.code != NSFileNoSuchFileError) {
            NSLog(@"PurrType learning cleanup failed: %@", error.localizedDescription);
        }
        return;
    }

    NSString *directory = [self.learningPath stringByDeletingLastPathComponent];
    NSDictionary<NSFileAttributeKey, id> *directoryAttributes = @{
        NSFilePosixPermissions: @(MKLearningDirectoryPermissions)
    };
    NSError *directoryError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
                                   withIntermediateDirectories:YES
                                                    attributes:directoryAttributes
                                                         error:&directoryError]) {
        NSLog(@"PurrType learning directory create failed: %@", directoryError.localizedDescription);
        return;
    }
    [self hardenLearningDirectoryIfNeeded:directory];

    NSDictionary *root = @{
        MKLearningVersionKey: @(MKLearningVersion),
        MKLearningSaltKey: self.learningSalt ?: @"",
        MKLearningCandidatesKey: self.persistedCandidateScoresByHash ?: @{},
        MKLearningAssociationsKey: self.persistedAssociationScoresByHash ?: @{}
    };

    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    if (data.length == 0) {
        return;
    }

    NSError *writeError = nil;
    if (![data writeToFile:self.learningPath options:NSDataWritingAtomic error:&writeError]) {
        NSLog(@"PurrType learning save failed: %@", writeError.localizedDescription);
        return;
    }
    [self hardenLearningFileIfNeeded];
}

- (void)hardenLearningDirectoryIfNeeded:(NSString *)directory {
    if (!MKLearningDirectoryShouldBePrivate(directory)) {
        return;
    }

    NSDictionary<NSFileAttributeKey, id> *attributes = @{
        NSFilePosixPermissions: @(MKLearningDirectoryPermissions)
    };
    NSError *error = nil;
    if (![[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:directory error:&error]) {
        NSLog(@"PurrType learning directory permission hardening failed: %@", error.localizedDescription);
    }
}

- (void)hardenLearningFileIfNeeded {
    if (self.learningPath.length == 0) {
        return;
    }

    NSDictionary<NSFileAttributeKey, id> *attributes = @{
        NSFilePosixPermissions: @(MKLearningFilePermissions)
    };
    NSError *error = nil;
    if (![[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:self.learningPath error:&error]) {
        NSLog(@"PurrType learning file permission hardening failed: %@", error.localizedDescription);
    }
}

- (BOOL)incrementPersistedLearningScoreForCategory:(NSString *)category
                                               key:(NSString *)key
                                              text:(NSString *)text
                                             table:(NSMutableDictionary<NSString *, NSNumber *> *)table {
    if (![self isLearningTextSafe:text]) {
        return NO;
    }

    NSString *hash = [self learningHashForCategory:category key:key text:text];
    if (hash.length == 0) {
        return NO;
    }

    NSInteger currentScore = [table[hash] integerValue];
    NSInteger nextScore = MIN(currentScore + 1, MKMaximumLearningScore);
    if (nextScore == currentScore) {
        return NO;
    }

    table[hash] = @(nextScore);
    return YES;
}

- (NSInteger)persistedLearningScoreForCategory:(NSString *)category
                                           key:(NSString *)key
                                          text:(NSString *)text
                                         table:(NSDictionary<NSString *, NSNumber *> *)table {
    NSString *hash = [self learningHashForCategory:category key:key text:text];
    if (hash.length == 0) {
        return 0;
    }
    return [table[hash] integerValue];
}

- (NSString *)learningHashForCategory:(NSString *)category key:(NSString *)key text:(NSString *)text {
    if (self.learningSalt.length == 0 ||
        category.length == 0 ||
        key.length == 0 ||
        text.length == 0) {
        return @"";
    }

    NSString *payload = [@[self.learningSalt, category, key, text] componentsJoinedByString:@"\n"];
    NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length == 0) {
        return @"";
    }

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index += 1) {
        [hex appendFormat:@"%02x", digest[index]];
    }
    return hex;
}

- (BOOL)incrementLearningScoreForKey:(NSString *)key
                                text:(NSString *)text
                               table:(NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *)table {
    if (key.length == 0 ||
        text.length == 0 ||
        ![self isLearningTextSafe:text]) {
        return NO;
    }

    NSMutableDictionary<NSString *, NSNumber *> *bucket = table[key];
    if (!bucket) {
        bucket = [NSMutableDictionary dictionary];
        table[key] = bucket;
    }

    NSInteger currentScore = [bucket[text] integerValue];
    NSInteger nextScore = MIN(currentScore + 1, MKMaximumLearningScore);
    if (nextScore == currentScore) {
        return NO;
    }

    bucket[text] = @(nextScore);
    return YES;
}

- (BOOL)shouldApplyLearningRankingForMode:(MKInputMode)mode {
    return self.learningEnabled && [mode isEqualToString:MKInputModeSmartSucheng];
}

- (void)trimRecentCommittedSegments {
    while (self.recentCommittedTextSegments.count > 0 &&
           ([self recentCommittedTextLength] > MKRecentCommittedTextLimit ||
            [self recentCommittedCodeLength] > MKRecentCommittedCodeLimit)) {
        [self.recentCommittedTextSegments removeObjectAtIndex:0];
        [self.recentCommittedCodeSegments removeObjectAtIndex:0];
    }
}

- (void)recordRecentCommittedSuffixesForLearningWithMode:(MKInputMode)mode {
    if (self.recentCommittedTextSegments.count != self.recentCommittedCodeSegments.count) {
        [self resetLearningContext];
        return;
    }

    NSMutableString *suffixText = [NSMutableString string];
    NSMutableString *suffixCode = [NSMutableString string];
    NSMutableArray<NSString *> *suffixTexts = [NSMutableArray array];
    NSMutableArray<NSString *> *suffixCodes = [NSMutableArray array];
    BOOL suffixHasExactCode = YES;
    for (NSInteger index = (NSInteger)self.recentCommittedTextSegments.count - 1; index >= 0; index -= 1) {
        NSString *codeSegment = self.recentCommittedCodeSegments[(NSUInteger)index];
        if (codeSegment.length == 0) {
            suffixHasExactCode = NO;
        }

        [suffixText insertString:self.recentCommittedTextSegments[(NSUInteger)index] atIndex:0];
        [suffixCode insertString:codeSegment atIndex:0];

        if (suffixText.length > MKLearnedPhraseMaximumCharacterLength ||
            suffixCode.length > MKRecentCommittedCodeLimit) {
            break;
        }

        if (suffixHasExactCode && suffixText.length >= 2) {
            [suffixTexts addObject:[suffixText copy]];
            [suffixCodes addObject:[suffixCode copy]];
        }
    }

    [self recordCommittedTexts:suffixTexts codes:suffixCodes mode:mode];
}

- (NSUInteger)recentCommittedTextLength {
    NSUInteger length = 0;
    for (NSString *segment in self.recentCommittedTextSegments) {
        length += segment.length;
    }
    return length;
}

- (NSUInteger)recentCommittedCodeLength {
    NSUInteger length = 0;
    for (NSString *segment in self.recentCommittedCodeSegments) {
        length += segment.length;
    }
    return length;
}

- (NSArray<MKCandidate *> *)candidatesByApplyingLearningRanking:(NSArray<MKCandidate *> *)candidates mode:(MKInputMode)mode {
    if (![self shouldApplyLearningRankingForMode:mode] ||
        candidates.count <= 1 ||
        (self.learnedCandidateScores.count == 0 &&
         self.persistedCandidateScoresByHash.count == 0)) {
        return candidates;
    }

    BOOL hasLearnedScore = NO;
    NSMutableDictionary<NSValue *, NSNumber *> *positions = [NSMutableDictionary dictionaryWithCapacity:candidates.count];
    for (NSUInteger index = 0; index < candidates.count; index += 1) {
        MKCandidate *candidate = candidates[index];
        positions[[NSValue valueWithNonretainedObject:candidate]] = @(index);
        if ([self learningRankingScoreForCandidate:candidate] > 0) {
            hasLearnedScore = YES;
        }
    }

    if (!hasLearnedScore) {
        return candidates;
    }

    NSMutableArray<MKCandidate *> *ranked = [candidates mutableCopy];
    [ranked sortUsingComparator:^NSComparisonResult(MKCandidate *left, MKCandidate *right) {
        NSInteger leftScore = [self learningRankingScoreForCandidate:left];
        NSInteger rightScore = [self learningRankingScoreForCandidate:right];
        if (leftScore != rightScore) {
            return leftScore > rightScore ? NSOrderedAscending : NSOrderedDescending;
        }

        NSUInteger leftPosition = [positions[[NSValue valueWithNonretainedObject:left]] unsignedIntegerValue];
        NSUInteger rightPosition = [positions[[NSValue valueWithNonretainedObject:right]] unsignedIntegerValue];
        if (leftPosition != rightPosition) {
            return leftPosition < rightPosition ? NSOrderedAscending : NSOrderedDescending;
        }

        return NSOrderedSame;
    }];
    return ranked;
}

- (NSInteger)learningRankingScoreForCandidate:(MKCandidate *)candidate {
    NSString *key = [self overrideKeyForSource:candidate.source code:candidate.code];
    return [self.learnedCandidateScores[key][candidate.text] integerValue] +
           [self persistedLearningScoreForCategory:MKLearningCategoryCandidate
                                               key:key
                                              text:candidate.text
                                             table:self.persistedCandidateScoresByHash];
}

- (NSArray<MKCandidate *> *)smartSuchengCandidatesForInput:(NSString *)input
                                            baseCandidates:(NSArray<MKCandidate *> *)baseCandidates {
    NSMutableArray<MKCandidate *> *combined = [NSMutableArray array];
    NSMutableSet<NSString *> *seenTexts = [NSMutableSet set];

    for (MKCandidate *candidate in [self learnedPhraseCandidatesForInput:input]) {
        if ([seenTexts containsObject:candidate.text]) {
            continue;
        }
        [seenTexts addObject:candidate.text];
        [combined addObject:candidate];
    }

    for (MKCandidate *candidate in [self exactSmartPhraseCandidatesForInput:input]) {
        if ([seenTexts containsObject:candidate.text]) {
            continue;
        }
        [seenTexts addObject:candidate.text];
        [combined addObject:candidate];
    }

    if (![self shouldSuppressGeneratedSmartPhrasesForInput:input baseCandidates:baseCandidates]) {
        for (MKCandidate *candidate in [self generatedSmartPhraseCandidatesForInput:input]) {
            if ([seenTexts containsObject:candidate.text]) {
                continue;
            }
            [seenTexts addObject:candidate.text];
            [combined addObject:candidate];
        }
    }

    for (MKCandidate *candidate in baseCandidates) {
        if ([seenTexts containsObject:candidate.text]) {
            continue;
        }
        [seenTexts addObject:candidate.text];
        [combined addObject:candidate];
    }

    return combined;
}

- (NSArray<MKCandidate *> *)learnedPhraseCandidatesForInput:(NSString *)input {
    if (![self shouldApplyLearningRankingForMode:MKInputModeSmartSucheng]) {
        return @[];
    }

    NSDictionary<NSString *, NSNumber *> *bucket = self.learnedPhraseScores[input] ?: @{};
    if (bucket.count == 0) {
        return @[];
    }

    NSArray<NSString *> *texts = [bucket.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
        NSInteger leftScore = [bucket[left] integerValue];
        NSInteger rightScore = [bucket[right] integerValue];
        if (leftScore != rightScore) {
            return leftScore > rightScore ? NSOrderedAscending : NSOrderedDescending;
        }
        return [left compare:right];
    }];

    NSMutableArray<MKCandidate *> *candidates = [NSMutableArray arrayWithCapacity:texts.count];
    NSUInteger sequence = 0;
    for (NSString *text in texts) {
        if (![self isCandidateTextDisplayable:text] || ![self isTraditionalCandidateText:text]) {
            continue;
        }

        NSInteger score = [bucket[text] integerValue];
        [candidates addObject:[[MKCandidate alloc] initWithText:text
                                                           code:input
                                                         source:@"learned_phrase"
                                                         weight:7000 + score
                                                       sequence:sequence]];
        sequence += 1;
    }
    return candidates;
}

- (NSArray<MKCandidate *> *)exactSmartPhraseCandidatesForInput:(NSString *)input {
    NSArray<MKCandidate *> *seeded = self.smartPhraseIndex[input] ?: @[];
    if (seeded.count == 0) {
        return @[];
    }
    return [self candidatesByApplyingLearningRanking:seeded mode:MKInputModeSmartSucheng];
}

- (NSArray<MKCandidate *> *)generatedSmartPhraseCandidatesForInput:(NSString *)input {
    if (input.length < 3 || input.length > MKSmartPhraseMaximumInputLength) {
        return @[];
    }

    NSArray<NSDictionary *> *states = [self generatedSmartPhraseStatesForInput:input];
    if (states.count == 0) {
        return @[];
    }

    NSMutableArray<MKCandidate *> *phrases = [NSMutableArray arrayWithCapacity:states.count];
    NSMutableSet<NSString *> *seenTexts = [NSMutableSet set];
    NSUInteger sequence = 0;
    for (NSDictionary *state in states) {
        NSArray<MKCandidate *> *path = state[MKSmartPhraseStatePathKey];
        if (path.count < 2) {
            continue;
        }

        NSMutableString *text = [NSMutableString string];
        for (MKCandidate *candidate in path) {
            [text appendString:candidate.text];
        }

        if (text.length == 0 ||
            [seenTexts containsObject:text] ||
            ![self isCandidateTextDisplayable:text] ||
            ![self isTraditionalCandidateText:text]) {
            continue;
        }

        [seenTexts addObject:text];
        NSInteger weight = 4200 + [state[MKSmartPhraseStateScoreKey] integerValue];
        [phrases addObject:[[MKCandidate alloc] initWithText:text
                                                       code:input
                                                     source:@"smart_phrase_generated"
                                                     weight:weight - (NSInteger)sequence
                                                   sequence:sequence]];
        sequence += 1;
    }

    return [self candidatesByApplyingLearningRanking:phrases mode:MKInputModeSmartSucheng];
}

- (NSArray<NSDictionary *> *)generatedSmartPhraseStatesForInput:(NSString *)input {
    NSMutableDictionary<NSNumber *, NSMutableArray<NSDictionary *> *> *beams = [NSMutableDictionary dictionary];
    beams[@0] = [@[@{
        MKSmartPhraseStatePathKey: @[],
        MKSmartPhraseStateScoreKey: @0
    }] mutableCopy];

    for (NSUInteger position = 0; position < input.length; position += 1) {
        NSNumber *positionKey = @(position);
        NSMutableArray<NSDictionary *> *states = beams[positionKey];
        if (states.count == 0) {
            continue;
        }

        [self pruneSmartPhraseStateBeam:states limit:MKSmartPhraseBeamWidth];
        NSArray<NSDictionary *> *currentStates = [states copy];
        for (NSDictionary *state in currentStates) {
            NSArray<MKCandidate *> *path = state[MKSmartPhraseStatePathKey];
            MKCandidate *previousCandidate = path.lastObject;
            NSString *previousText = previousCandidate.text ?: @"";
            NSInteger currentScore = [state[MKSmartPhraseStateScoreKey] integerValue];

            NSArray<NSNumber *> *segmentLengths = @[@2, @1];
            for (NSNumber *lengthNumber in segmentLengths) {
                NSUInteger length = [lengthNumber unsignedIntegerValue];
                if (position + length > input.length) {
                    continue;
                }

                NSString *code = [input substringWithRange:NSMakeRange(position, length)];
                NSArray<MKCandidate *> *segmentCandidates = [self smartPhraseSegmentCandidatesForCode:code
                                                                                          previousText:previousText];
                if (segmentCandidates.count == 0) {
                    continue;
                }

                NSNumber *nextPositionKey = @(position + length);
                NSMutableArray<NSDictionary *> *nextStates = beams[nextPositionKey];
                if (!nextStates) {
                    nextStates = [NSMutableArray array];
                    beams[nextPositionKey] = nextStates;
                }

                for (MKCandidate *candidate in segmentCandidates) {
                    NSMutableArray<MKCandidate *> *nextPath = [path mutableCopy];
                    [nextPath addObject:candidate];
                    NSInteger nextScore = currentScore + [self smartPhraseSegmentScoreForCandidate:candidate
                                                                                       previousText:previousText];
                    [nextStates addObject:@{
                        MKSmartPhraseStatePathKey: [nextPath copy],
                        MKSmartPhraseStateScoreKey: @(nextScore)
                    }];
                }
            }
        }
    }

    NSMutableArray<NSDictionary *> *completedStates = [beams[@(input.length)] mutableCopy] ?: [NSMutableArray array];
    [self pruneSmartPhraseStateBeam:completedStates limit:MKSmartPhraseMaximumGeneratedPaths];
    NSMutableArray<NSDictionary *> *validStates = [NSMutableArray arrayWithCapacity:completedStates.count];
    for (NSDictionary *state in completedStates) {
        NSArray<MKCandidate *> *path = state[MKSmartPhraseStatePathKey];
        if (path.count >= 2) {
            [validStates addObject:state];
        }
    }
    return validStates;
}

- (NSArray<MKCandidate *> *)smartPhraseSegmentCandidatesForCode:(NSString *)code previousText:(NSString *)previousText {
    NSArray<MKCandidate *> *bucket = [self candidatesByApplyingLearningRanking:[self candidateBucketForCode:code
                                                                                                      mode:MKInputModeSucheng]
                                                                          mode:MKInputModeSmartSucheng];
    if (bucket.count == 0) {
        return @[];
    }

    NSMutableDictionary<NSValue *, NSNumber *> *positions = [NSMutableDictionary dictionaryWithCapacity:bucket.count];
    for (NSUInteger index = 0; index < bucket.count; index += 1) {
        positions[[NSValue valueWithNonretainedObject:bucket[index]]] = @(index);
    }

    NSMutableArray<MKCandidate *> *ranked = [bucket mutableCopy];
    [ranked sortUsingComparator:^NSComparisonResult(MKCandidate *left, MKCandidate *right) {
        NSInteger leftScore = [self smartPhraseSegmentScoreForCandidate:left previousText:previousText];
        NSInteger rightScore = [self smartPhraseSegmentScoreForCandidate:right previousText:previousText];
        if (leftScore != rightScore) {
            return leftScore > rightScore ? NSOrderedAscending : NSOrderedDescending;
        }

        NSUInteger leftPosition = [positions[[NSValue valueWithNonretainedObject:left]] unsignedIntegerValue];
        NSUInteger rightPosition = [positions[[NSValue valueWithNonretainedObject:right]] unsignedIntegerValue];
        if (leftPosition != rightPosition) {
            return leftPosition < rightPosition ? NSOrderedAscending : NSOrderedDescending;
        }

        return NSOrderedSame;
    }];

    if (ranked.count <= MKSmartPhraseSegmentCandidateLimit) {
        return ranked;
    }
    return [ranked subarrayWithRange:NSMakeRange(0, MKSmartPhraseSegmentCandidateLimit)];
}

- (NSInteger)smartPhraseSegmentScoreForCandidate:(MKCandidate *)candidate previousText:(NSString *)previousText {
    NSInteger score = candidate.weight;
    score += [self commonTextBoostForText:candidate.text];
    if ([self shouldApplyLearningRankingForMode:MKInputModeSmartSucheng]) {
        score += [self learningRankingScoreForCandidate:candidate] * 1000;
    }
    if (candidate.code.length == 1) {
        score -= MKSmartPhraseSingleCodePenalty;
    }

    NSString *associationKey = [self lastDisplayableCharacterInText:previousText ?: @""];
    NSArray<NSString *> *associations = [self fixedAssociationCandidatesForKey:associationKey];
    NSUInteger associationIndex = [associations indexOfObject:candidate.text];
    if (associationIndex != NSNotFound) {
        score += MKSmartPhraseAssociationBoost - (NSInteger)associationIndex * 100;
    }
    return score;
}

- (void)pruneSmartPhraseStateBeam:(NSMutableArray<NSDictionary *> *)states limit:(NSUInteger)limit {
    [states sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSInteger leftScore = [left[MKSmartPhraseStateScoreKey] integerValue];
        NSInteger rightScore = [right[MKSmartPhraseStateScoreKey] integerValue];
        if (leftScore != rightScore) {
            return leftScore > rightScore ? NSOrderedAscending : NSOrderedDescending;
        }

        NSArray<MKCandidate *> *leftPath = left[MKSmartPhraseStatePathKey];
        NSArray<MKCandidate *> *rightPath = right[MKSmartPhraseStatePathKey];
        if (leftPath.count != rightPath.count) {
            return leftPath.count > rightPath.count ? NSOrderedAscending : NSOrderedDescending;
        }

        return NSOrderedSame;
    }];

    if (states.count > limit) {
        [states removeObjectsInRange:NSMakeRange(limit, states.count - limit)];
    }
}

- (BOOL)hasSmartSuchengPhraseCandidateOrPrefixForInput:(NSString *)input {
    if (input.length == 0 || input.length > MKSmartPhraseMaximumInputLength) {
        return NO;
    }

    if ([self.smartPhrasePrefixes containsObject:input]) {
        return YES;
    }

    if ([self shouldApplyLearningRankingForMode:MKInputModeSmartSucheng] &&
        ([self.learnedPhrasePrefixes containsObject:input] ||
         [self learnedPhraseCandidatesForInput:input].count > 0)) {
        return YES;
    }

    if ([self exactSmartPhraseCandidatesForInput:input].count > 0) {
        return YES;
    }

    if ([self canSegmentSmartSuchengPhrasePrefix:input position:0 segmentCount:0]) {
        return YES;
    }

    return [self generatedSmartPhraseCandidatesForInput:input].count > 0;
}

- (BOOL)canSegmentSmartSuchengPhrasePrefix:(NSString *)input position:(NSUInteger)position segmentCount:(NSUInteger)segmentCount {
    if (position == input.length) {
        return segmentCount >= 2;
    }

    id<MKCandidateProvider> suchengProvider = [self candidateProviderForMode:MKInputModeSucheng];
    for (NSUInteger length = 2; length >= 1; length -= 1) {
        if (position + length > input.length) {
            continue;
        }

        NSString *code = [input substringWithRange:NSMakeRange(position, length)];
        BOOL isAtEnd = position + length == input.length;
        BOOL hasExactCandidates = [suchengProvider candidatesForInput:code].count > 0;
        if (hasExactCandidates &&
            [self canSegmentSmartSuchengPhrasePrefix:input
                                            position:position + length
                                        segmentCount:segmentCount + 1]) {
            return YES;
        }

        if (isAtEnd &&
            segmentCount > 0 &&
            [[suchengProvider prefixes] containsObject:code]) {
            return YES;
        }

        if (length == 1) {
            break;
        }
    }

    return NO;
}

- (NSArray<MKCandidate *> *)pinyinCandidatesForInput:(NSString *)input
                                      baseCandidates:(NSArray<MKCandidate *> *)baseCandidates {
    NSArray<MKCandidate *> *safeBaseCandidates = baseCandidates ?: @[];
    NSArray<MKCandidate *> *generatedCandidates =
        [self generatedPinyinPhraseCandidatesForInput:input excludingCandidates:safeBaseCandidates];
    if (generatedCandidates.count == 0) {
        return safeBaseCandidates;
    }

    NSMutableArray<MKCandidate *> *candidates =
        [NSMutableArray arrayWithCapacity:safeBaseCandidates.count + generatedCandidates.count];
    [candidates addObjectsFromArray:safeBaseCandidates];
    [candidates addObjectsFromArray:generatedCandidates];
    return [candidates copy];
}

- (NSArray<MKCandidate *> *)generatedPinyinPhraseCandidatesForInput:(NSString *)input
                                                excludingCandidates:(NSArray<MKCandidate *> *)existingCandidates {
    if (input.length == 0 || input.length > MKPinyinMaximumGeneratedInputLength) {
        return @[];
    }

    NSMutableSet<NSString *> *seenTexts = [NSMutableSet set];
    for (MKCandidate *candidate in existingCandidates ?: @[]) {
        if (candidate.text.length > 0) {
            [seenTexts addObject:candidate.text];
        }
    }

    NSMutableArray<MKCandidate *> *phrases = [NSMutableArray array];
    NSUInteger sequence = 0;
    for (NSDictionary *state in [self generatedPinyinPhraseStatesForInput:input]) {
        NSArray<MKCandidate *> *path = state[MKSmartPhraseStatePathKey];
        if (path.count < 2) {
            continue;
        }

        NSMutableString *text = [NSMutableString string];
        for (MKCandidate *candidate in path) {
            [text appendString:candidate.text ?: @""];
        }

        if (text.length == 0 || [seenTexts containsObject:text]) {
            continue;
        }

        NSArray<NSString *> *characters = [self displayableCharactersInText:text];
        if (characters.count != path.count) {
            continue;
        }

        [seenTexts addObject:text];
        NSInteger weight = [state[MKSmartPhraseStateScoreKey] integerValue];
        [phrases addObject:[[MKCandidate alloc] initWithText:text
                                                       code:input
                                                     source:MKPinyinGeneratedPhraseSource
                                                     weight:weight
                                                   sequence:sequence]];
        sequence += 1;
    }

    [self sortCandidateBucket:phrases];
    return [phrases copy];
}

- (NSArray<NSDictionary *> *)generatedPinyinPhraseStatesForInput:(NSString *)input {
    NSMutableDictionary<NSNumber *, NSMutableArray<NSDictionary *> *> *beams = [NSMutableDictionary dictionary];
    beams[@0] = [@[@{
        MKSmartPhraseStatePathKey: @[],
        MKSmartPhraseStateScoreKey: @0
    }] mutableCopy];

    for (NSUInteger position = 0; position < input.length; position += 1) {
        NSMutableArray<NSDictionary *> *states = beams[@(position)];
        if (states.count == 0) {
            continue;
        }

        [self prunePinyinStateBeam:states limit:MKPinyinBeamWidth];
        NSArray<NSDictionary *> *currentStates = [states copy];
        for (NSDictionary *state in currentStates) {
            NSArray<MKCandidate *> *path = state[MKSmartPhraseStatePathKey];
            if (path.count >= MKPinyinMaximumGeneratedSyllables) {
                continue;
            }

            NSMutableString *previousText = [NSMutableString string];
            for (MKCandidate *candidate in path) {
                [previousText appendString:candidate.text ?: @""];
            }

            NSInteger currentScore = [state[MKSmartPhraseStateScoreKey] integerValue];
            NSUInteger remainingLength = input.length - position;
            NSUInteger maximumLength = MIN(MKPinyinMaximumSyllableCodeLength, remainingLength);
            for (NSUInteger length = 1; length <= maximumLength; length += 1) {
                NSString *code = [input substringWithRange:NSMakeRange(position, length)];
                NSArray<MKCandidate *> *segmentCandidates = [self pinyinSegmentCandidatesForCode:code
                                                                                    previousText:previousText];
                if (segmentCandidates.count == 0) {
                    continue;
                }

                NSNumber *nextPositionKey = @(position + length);
                NSMutableArray<NSDictionary *> *nextStates = beams[nextPositionKey];
                if (!nextStates) {
                    nextStates = [NSMutableArray array];
                    beams[nextPositionKey] = nextStates;
                }

                for (MKCandidate *candidate in segmentCandidates) {
                    NSMutableArray<MKCandidate *> *nextPath = [path mutableCopy];
                    [nextPath addObject:candidate];
                    NSInteger nextScore = currentScore + [self pinyinSegmentScoreForCandidate:candidate
                                                                                  previousText:previousText];
                    nextScore -= MKPinyinSegmentPenalty;
                    [nextStates addObject:@{
                        MKSmartPhraseStatePathKey: [nextPath copy],
                        MKSmartPhraseStateScoreKey: @(nextScore)
                    }];
                }
            }
        }
    }

    NSMutableArray<NSDictionary *> *completedStates = [beams[@(input.length)] mutableCopy] ?: [NSMutableArray array];
    [self prunePinyinStateBeam:completedStates limit:MKPinyinMaximumGeneratedPaths];

    NSMutableArray<NSDictionary *> *validStates = [NSMutableArray arrayWithCapacity:completedStates.count];
    for (NSDictionary *state in completedStates) {
        NSArray<MKCandidate *> *path = state[MKSmartPhraseStatePathKey];
        if (path.count >= 2) {
            [validStates addObject:state];
        }
    }
    return validStates;
}

- (NSArray<MKCandidate *> *)pinyinSegmentCandidatesForCode:(NSString *)code previousText:(NSString *)previousText {
    NSArray<MKCandidate *> *bucket = [self pinyinSingleCharacterCandidatesForCode:code];
    if (bucket.count == 0) {
        return @[];
    }

    NSMutableDictionary<NSValue *, NSNumber *> *positions = [NSMutableDictionary dictionaryWithCapacity:bucket.count];
    for (NSUInteger index = 0; index < bucket.count; index += 1) {
        positions[[NSValue valueWithNonretainedObject:bucket[index]]] = @(index);
    }

    NSMutableArray<MKCandidate *> *ranked = [bucket mutableCopy];
    [ranked sortUsingComparator:^NSComparisonResult(MKCandidate *left, MKCandidate *right) {
        NSInteger leftScore = [self pinyinSegmentScoreForCandidate:left previousText:previousText];
        NSInteger rightScore = [self pinyinSegmentScoreForCandidate:right previousText:previousText];
        if (leftScore != rightScore) {
            return leftScore > rightScore ? NSOrderedAscending : NSOrderedDescending;
        }

        NSUInteger leftPosition = [positions[[NSValue valueWithNonretainedObject:left]] unsignedIntegerValue];
        NSUInteger rightPosition = [positions[[NSValue valueWithNonretainedObject:right]] unsignedIntegerValue];
        if (leftPosition != rightPosition) {
            return leftPosition < rightPosition ? NSOrderedAscending : NSOrderedDescending;
        }

        return NSOrderedSame;
    }];

    if (ranked.count <= MKPinyinSegmentCandidateLimit) {
        return ranked;
    }
    return [ranked subarrayWithRange:NSMakeRange(0, MKPinyinSegmentCandidateLimit)];
}

- (NSArray<MKCandidate *> *)pinyinSingleCharacterCandidatesForCode:(NSString *)code {
    if (code.length == 0 || code.length > MKPinyinMaximumSyllableCodeLength) {
        return @[];
    }

    NSArray<MKCandidate *> *bucket = [self candidateBucketForCode:code source:MKInputModePinyin];
    if (bucket.count == 0) {
        return @[];
    }

    NSMutableArray<MKCandidate *> *singleCharacterCandidates = [NSMutableArray array];
    for (MKCandidate *candidate in bucket) {
        if ([self displayableCharactersInText:candidate.text].count == 1) {
            [singleCharacterCandidates addObject:candidate];
        }
    }
    return [singleCharacterCandidates copy];
}

- (NSInteger)pinyinSegmentScoreForCandidate:(MKCandidate *)candidate previousText:(NSString *)previousText {
    NSInteger score = candidate.weight;
    score += [self commonTextBoostForText:candidate.text];

    NSString *associationKey = [self lastDisplayableCharacterInText:previousText ?: @""];
    NSArray<NSString *> *associations = [self fixedAssociationCandidatesForKey:associationKey];
    NSUInteger associationIndex = [associations indexOfObject:candidate.text];
    if (associationIndex != NSNotFound) {
        score += MKSmartPhraseAssociationBoost - (NSInteger)associationIndex * 100;
    }
    return score;
}

- (void)prunePinyinStateBeam:(NSMutableArray<NSDictionary *> *)states limit:(NSUInteger)limit {
    [states sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSInteger leftScore = [left[MKSmartPhraseStateScoreKey] integerValue];
        NSInteger rightScore = [right[MKSmartPhraseStateScoreKey] integerValue];
        if (leftScore != rightScore) {
            return leftScore > rightScore ? NSOrderedAscending : NSOrderedDescending;
        }

        NSArray<MKCandidate *> *leftPath = left[MKSmartPhraseStatePathKey];
        NSArray<MKCandidate *> *rightPath = right[MKSmartPhraseStatePathKey];
        if (leftPath.count != rightPath.count) {
            return leftPath.count > rightPath.count ? NSOrderedAscending : NSOrderedDescending;
        }

        return NSOrderedSame;
    }];

    if (states.count > limit) {
        [states removeObjectsInRange:NSMakeRange(limit, states.count - limit)];
    }
}

- (BOOL)hasSegmentedPinyinCandidateOrPrefixForInput:(NSString *)input {
    if (input.length == 0 || input.length > MKPinyinMaximumContinuousInputLength) {
        return NO;
    }

    return [self canSegmentPinyinInputPrefix:input
                                    position:0
                                syllableCount:0
                                  failedMemo:[NSMutableSet set]];
}

- (BOOL)canSegmentPinyinInputPrefix:(NSString *)input
                           position:(NSUInteger)position
                       syllableCount:(NSUInteger)syllableCount
                         failedMemo:(NSMutableSet<NSString *> *)failedMemo {
    if (syllableCount > MKPinyinMaximumContinuousSyllables) {
        return NO;
    }

    if (position == input.length) {
        return syllableCount >= 2;
    }

    NSString *memoKey = [NSString stringWithFormat:@"%lu:%lu",
                         (unsigned long)position,
                         (unsigned long)syllableCount];
    if ([failedMemo containsObject:memoKey]) {
        return NO;
    }

    if (syllableCount > 0) {
        NSString *remaining = [input substringFromIndex:position];
        if ([self hasCandidatesOrPrefixesForCode:remaining source:MKInputModePinyin]) {
            return YES;
        }
    }

    NSUInteger remainingLength = input.length - position;
    NSUInteger maximumLength = MIN(MKPinyinMaximumSyllableCodeLength, remainingLength);
    for (NSUInteger length = 1; length <= maximumLength; length += 1) {
        NSString *code = [input substringWithRange:NSMakeRange(position, length)];
        if ([self pinyinSingleCharacterCandidatesForCode:code].count == 0) {
            continue;
        }

        if ([self canSegmentPinyinInputPrefix:input
                                     position:position + length
                                 syllableCount:syllableCount + 1
                                   failedMemo:failedMemo]) {
            return YES;
        }
    }

    [failedMemo addObject:memoKey];
    return NO;
}

- (NSString *)quickCodeForCangjieCode:(NSString *)code {
    if (code.length <= 1) {
        return code;
    }

    unichar first = [code characterAtIndex:0];
    unichar last = [code characterAtIndex:code.length - 1];
    return [NSString stringWithFormat:@"%C%C", first, last];
}

- (NSString *)quickCodeForPhraseText:(NSString *)text {
    NSArray<NSString *> *characters = [self displayableCharactersInText:text];
    if (characters.count < 2) {
        return @"";
    }

    NSMutableString *code = [NSMutableString string];
    for (NSString *character in characters) {
        NSString *characterCode = [self preferredQuickCodeForText:character];
        if (characterCode.length == 0) {
            return @"";
        }
        [code appendString:characterCode];
    }
    return code;
}

- (NSString *)preferredQuickCodeForText:(NSString *)text {
    if (text.length == 0) {
        return @"";
    }

    if (!self.preferredQuickCodeIndexBuilt) {
        [self rebuildPreferredQuickCodeIndex];
    }

    NSString *cachedCode = self.preferredQuickCodeByText[text];
    if (cachedCode.length > 0) {
        return cachedCode;
    }

    return @"";
}

- (void)rebuildPreferredQuickCodeIndex {
    [self.preferredQuickCodeByText removeAllObjects];
    NSMutableDictionary<NSString *, NSNumber *> *bestScores = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *codeSet = [NSMutableSet setWithArray:[self candidateIndexCodesForSource:MKInputModeSucheng]];
    NSArray<NSString *> *overlayQuickCodes = [self.indexBySource[MKInputModeSucheng] allKeys] ?: @[];
    [codeSet addObjectsFromArray:overlayQuickCodes];

    NSArray<NSString *> *codes = [[codeSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *code in codes) {
        NSArray<MKCandidate *> *bucket = [self candidateBucketForCode:code source:MKInputModeSucheng];
        for (NSUInteger index = 0; index < bucket.count; index += 1) {
            MKCandidate *candidate = bucket[index];

            NSInteger score = candidate.weight + [self commonTextBoostForText:candidate.text];
            score -= (NSInteger)index * 20;
            score -= (NSInteger)code.length * 10;
            if (code.length == 1) {
                score += 140;
            }

            NSString *bestCode = self.preferredQuickCodeByText[candidate.text];
            NSInteger bestScore = [bestScores[candidate.text] integerValue];
            if (bestCode.length == 0 ||
                score > bestScore ||
                (score == bestScore &&
                 (code.length < bestCode.length ||
                  (code.length == bestCode.length && [code compare:bestCode] == NSOrderedAscending)))) {
                bestScores[candidate.text] = @(score);
                self.preferredQuickCodeByText[candidate.text] = code;
            }
        }
    }

    for (NSString *text in self.traditionalCompatibilityQuickCodeByText) {
        NSString *code = self.traditionalCompatibilityQuickCodeByText[text];
        if (code.length > 0) {
            self.preferredQuickCodeByText[text] = code;
        }
    }

    self.preferredQuickCodeIndexBuilt = YES;
}

- (void)rebuildPreferredCangjieCodeIndex {
    [self.preferredCangjieCodeByText removeAllObjects];
    NSMutableDictionary<NSString *, NSNumber *> *bestScores = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *codeSet = [NSMutableSet setWithArray:[self candidateIndexCodesForSource:MKInputModeCangjie]];
    NSArray<NSString *> *overlayCangjieCodes = [self.indexBySource[MKInputModeCangjie] allKeys] ?: @[];
    [codeSet addObjectsFromArray:overlayCangjieCodes];

    NSArray<NSString *> *codes = [[codeSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *code in codes) {
        NSArray<MKCandidate *> *bucket = [self candidateBucketForCode:code source:MKInputModeCangjie];
        for (NSUInteger index = 0; index < bucket.count; index += 1) {
            MKCandidate *candidate = bucket[index];

            NSInteger score = candidate.weight + [self commonTextBoostForText:candidate.text];
            score -= (NSInteger)index * 20;
            score -= (NSInteger)code.length * 10;

            NSString *bestCode = self.preferredCangjieCodeByText[candidate.text];
            NSInteger bestScore = [bestScores[candidate.text] integerValue];
            if (bestCode.length == 0 ||
                score > bestScore ||
                (score == bestScore &&
                 (code.length < bestCode.length ||
                  (code.length == bestCode.length && [code compare:bestCode] == NSOrderedAscending)))) {
                bestScores[candidate.text] = @(score);
                self.preferredCangjieCodeByText[candidate.text] = code;
            }
        }
    }

    self.preferredCangjieCodeIndexBuilt = YES;
}

- (void)addCandidateText:(NSString *)text code:(NSString *)code source:(NSString *)source weight:(NSInteger)weight {
    [self addCandidateText:text
                      code:code
                    source:source
                    weight:weight
   allowingTraditionalCompatibility:NO
       includingInUnifiedIndex:YES];
}

- (void)addCandidateText:(NSString *)text
                    code:(NSString *)code
                  source:(NSString *)source
                  weight:(NSInteger)weight
 allowingTraditionalCompatibility:(BOOL)allowingTraditionalCompatibility {
    [self addCandidateText:text
                      code:code
                    source:source
                    weight:weight
 allowingTraditionalCompatibility:allowingTraditionalCompatibility
       includingInUnifiedIndex:YES];
}

- (void)addCandidateText:(NSString *)text
                    code:(NSString *)code
                  source:(NSString *)source
                  weight:(NSInteger)weight
 allowingTraditionalCompatibility:(BOOL)allowingTraditionalCompatibility
  includingInUnifiedIndex:(BOOL)includingInUnifiedIndex {
    if (text.length == 0 || code.length == 0) {
        return;
    }

    BOOL shouldRequireTraditionalText = ![source isEqualToString:@"quick"];
    BOOL isHKSCSOverlayText = [self.hkscsCandidateTexts containsObject:text];
    BOOL isDisplayableText = [self isCandidateTextDisplayable:text] ||
        (isHKSCSOverlayText && [self isHKSCSCandidateTextDisplayable:text]);
    BOOL isAllowedOverlayText = allowingTraditionalCompatibility &&
        ([self isTraditionalCompatibilityCandidateText:text] || isHKSCSOverlayText);
    if (!isDisplayableText ||
        (shouldRequireTraditionalText &&
         ![self isTraditionalCandidateText:text] &&
         !isAllowedOverlayText)) {
        return;
    }

    NSString *seenKey = [NSString stringWithFormat:@"%@:%@", source, code];
    NSMutableSet<NSString *> *seenTexts = self.seenTextsBySourceAndInput[seenKey];
    if (!seenTexts) {
        seenTexts = [NSMutableSet set];
        self.seenTextsBySourceAndInput[seenKey] = seenTexts;
    }

    if ([seenTexts containsObject:text]) {
        return;
    }

    if ([[self candidateIndexForSource:source] containsText:text code:code engine:self]) {
        return;
    }

    [seenTexts addObject:text];
    NSMutableSet<NSString *> *sourceTexts = self.textsBySource[source];
    if (!sourceTexts) {
        sourceTexts = [NSMutableSet set];
        self.textsBySource[source] = sourceTexts;
    }
    [sourceTexts addObject:text];

    NSMutableDictionary<NSString *, NSMutableArray<MKCandidate *> *> *sourceIndex = self.indexBySource[source];
    if (!sourceIndex) {
        sourceIndex = [NSMutableDictionary dictionary];
        self.indexBySource[source] = sourceIndex;
    }

    NSMutableArray<MKCandidate *> *sourceBucket = sourceIndex[code];
    if (!sourceBucket) {
        sourceBucket = [NSMutableArray array];
        sourceIndex[code] = sourceBucket;
    }

    MKCandidate *candidate = [[MKCandidate alloc] initWithText:text
                                                          code:code
                                                        source:source
                                                        weight:weight + [self fixedRankingBoostForText:text source:source]
                                                      sequence:self.nextCandidateSequence];
    self.nextCandidateSequence += 1;
    if (includingInUnifiedIndex) {
        NSMutableArray<MKCandidate *> *bucket = self.index[code];
        if (!bucket) {
            bucket = [NSMutableArray array];
            self.index[code] = bucket;
        }
        [bucket addObject:candidate];
    }
    [sourceBucket addObject:candidate];
    [self addPrefixesForCode:code source:source includingInUnifiedIndex:includingInUnifiedIndex];
    if ([source isEqualToString:MKInputModeSucheng]) {
        self.preferredQuickCodeIndexBuilt = NO;
    } else if ([source isEqualToString:MKInputModeCangjie]) {
        self.preferredCangjieCodeIndexBuilt = NO;
    }
}

- (BOOL)candidateText:(NSString *)text existsInSource:(NSString *)source {
    if (text.length == 0 || source.length == 0) {
        return NO;
    }
    return [self.textsBySource[source] containsObject:text];
}

- (BOOL)candidateText:(NSString *)text existsInSource:(NSString *)source code:(NSString *)code {
    if (text.length == 0 || source.length == 0 || code.length == 0) {
        return NO;
    }

    NSString *seenKey = [NSString stringWithFormat:@"%@:%@", source, code];
    if ([self.seenTextsBySourceAndInput[seenKey] containsObject:text]) {
        return YES;
    }

    return [[self candidateIndexForSource:source] containsText:text code:code engine:self];
}

- (BOOL)shouldUseIndexedCandidateText:(NSString *)text source:(NSString *)source {
    if (text.length == 0 || source.length == 0) {
        return NO;
    }

    if (![self isCandidateTextDisplayable:text]) {
        return NO;
    }

    if ([source isEqualToString:MKInputModeSucheng]) {
        return YES;
    }

    return [self isTraditionalCandidateText:text];
}

- (void)sortCandidateBuckets {
    for (NSString *code in self.index) {
        [self sortCandidateBucket:self.index[code]];
    }

    for (NSString *source in self.indexBySource) {
        NSDictionary<NSString *, NSMutableArray<MKCandidate *> *> *sourceIndex = self.indexBySource[source];
        for (NSString *code in sourceIndex) {
            [self sortCandidateBucket:sourceIndex[code]];
        }
    }
}

- (void)sortCandidateBucketsForSource:(NSString *)source {
    NSDictionary<NSString *, NSMutableArray<MKCandidate *> *> *sourceIndex = self.indexBySource[source];
    for (NSString *code in sourceIndex) {
        [self sortCandidateBucket:sourceIndex[code]];
    }
}

- (void)sortUnifiedCandidateBuckets {
    for (NSString *code in self.index) {
        [self sortCandidateBucket:self.index[code]];
    }
}

- (void)sortCandidateBucket:(NSMutableArray<MKCandidate *> *)bucket {
    [bucket sortUsingComparator:^NSComparisonResult(MKCandidate *left, MKCandidate *right) {
        if (left.weight != right.weight) {
            return left.weight > right.weight ? NSOrderedAscending : NSOrderedDescending;
        }

        NSInteger leftPriority = [self fixedRankingSourcePriority:left.source];
        NSInteger rightPriority = [self fixedRankingSourcePriority:right.source];
        if (leftPriority != rightPriority) {
            return leftPriority > rightPriority ? NSOrderedAscending : NSOrderedDescending;
        }

        if (left.code.length != right.code.length) {
            return left.code.length < right.code.length ? NSOrderedAscending : NSOrderedDescending;
        }

        if (left.sequence != right.sequence) {
            return left.sequence < right.sequence ? NSOrderedAscending : NSOrderedDescending;
        }

        return [left.text compare:right.text];
    }];
}

- (void)applyCandidateOrderOverrides {
    for (NSString *key in self.candidateOrderOverrides) {
        NSRange separator = [key rangeOfString:@":"];
        if (separator.location == NSNotFound || separator.location == 0 || separator.location == key.length - 1) {
            continue;
        }

        NSString *source = [key substringToIndex:separator.location];
        NSString *code = [key substringFromIndex:separator.location + separator.length];
        NSMutableArray<MKCandidate *> *bucket = self.indexBySource[source][code];
        if (bucket.count == 0) {
            continue;
        }

        [self applyCandidateOrderOverride:self.candidateOrderOverrides[key] toBucket:bucket];
    }
}

- (void)applyCandidateOrderOverridesForSource:(NSString *)source {
    if (source.length == 0) {
        return;
    }

    for (NSString *key in self.candidateOrderOverrides) {
        NSString *prefix = [source stringByAppendingString:@":"];
        if (![key hasPrefix:prefix]) {
            continue;
        }

        NSString *code = [key substringFromIndex:prefix.length];
        NSMutableArray<MKCandidate *> *bucket = self.indexBySource[source][code];
        if (bucket.count == 0) {
            continue;
        }

        [self applyCandidateOrderOverride:self.candidateOrderOverrides[key] toBucket:bucket];
    }
}

- (void)applyCandidateOrderOverride:(NSArray<NSString *> *)orderedTexts
                            toBucket:(NSMutableArray<MKCandidate *> *)bucket {
    NSMutableArray<MKCandidate *> *reordered = [NSMutableArray arrayWithCapacity:bucket.count];
    NSMutableSet<MKCandidate *> *added = [NSMutableSet set];

    for (NSString *text in orderedTexts) {
        for (MKCandidate *candidate in bucket) {
            if (![candidate.text isEqualToString:text] || [added containsObject:candidate]) {
                continue;
            }
            [reordered addObject:candidate];
            [added addObject:candidate];
            break;
        }
    }

    for (MKCandidate *candidate in bucket) {
        if ([added containsObject:candidate]) {
            continue;
        }
        [reordered addObject:candidate];
    }

    [bucket setArray:reordered];
}

- (NSArray<MKCandidate *> *)candidatesByApplyingOrderOverride:(NSArray<NSString *> *)orderedTexts
                                                   candidates:(NSArray<MKCandidate *> *)candidates {
    if (orderedTexts.count == 0 || candidates.count <= 1) {
        return candidates;
    }

    NSMutableArray<MKCandidate *> *reordered = [NSMutableArray arrayWithCapacity:candidates.count];
    NSMutableSet<MKCandidate *> *added = [NSMutableSet set];
    for (NSString *text in orderedTexts) {
        for (MKCandidate *candidate in candidates) {
            if (![candidate.text isEqualToString:text] || [added containsObject:candidate]) {
                continue;
            }
            [reordered addObject:candidate];
            [added addObject:candidate];
            break;
        }
    }

    if (reordered.count == 0) {
        return candidates;
    }

    for (MKCandidate *candidate in candidates) {
        if ([added containsObject:candidate]) {
            continue;
        }
        [reordered addObject:candidate];
    }

    return [reordered copy];
}

- (NSString *)overrideKeyForSource:(NSString *)source code:(NSString *)code {
    return [NSString stringWithFormat:@"%@:%@", source, code];
}

- (NSInteger)fixedRankingSourcePriority:(NSString *)source {
    if ([source isEqualToString:@"cangjie"]) {
        return 3;
    }
    if ([source isEqualToString:@"pinyin"]) {
        return 2;
    }
    if ([source isEqualToString:@"quick"]) {
        return 1;
    }
    return 0;
}

- (NSInteger)fixedRankingBoostForText:(NSString *)text source:(NSString *)source {
    if ([source isEqualToString:@"pinyin"]) {
        return [self commonTextBoostForText:text];
    }
    return 0;
}

- (NSInteger)commonTextBoostForText:(NSString *)text {
    static NSDictionary<NSString *, NSNumber *> *boosts = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        boosts = @{
            @"的": @2000, @"一": @1990, @"是": @1980, @"不": @1970, @"了": @1960,
            @"在": @1950, @"人": @1940, @"有": @1930, @"我": @1920, @"他": @1910,
            @"這": @1900, @"中": @1890, @"大": @1880, @"來": @1870, @"上": @1860,
            @"國": @1850, @"個": @1840, @"到": @1830, @"說": @1820, @"們": @1810,
            @"為": @1800, @"子": @1790, @"和": @1780, @"你": @1770, @"地": @1760,
            @"出": @1750, @"道": @1740, @"也": @1730, @"時": @1720, @"年": @1710,
            @"得": @1700, @"就": @1690, @"那": @1680, @"要": @1670, @"下": @1660,
            @"以": @1650, @"生": @1640, @"會": @1630, @"自": @1620, @"著": @1610,
            @"去": @1600, @"之": @1590, @"過": @1580, @"家": @1570, @"學": @1560,
            @"對": @1550, @"可": @1540, @"她": @1530, @"裡": @1520, @"後": @1510,
            @"小": @1500, @"麼": @1490, @"心": @1480, @"多": @1470, @"天": @1460,
            @"而": @1450, @"能": @1440, @"好": @1430, @"都": @1420, @"然": @1410,
            @"沒": @1400, @"日": @1390, @"於": @1380, @"起": @1370, @"還": @1360,
            @"發": @1350, @"成": @1340, @"事": @1330, @"只": @1320, @"作": @1310,
            @"當": @1300, @"想": @1290, @"看": @1280, @"龍": @1275, @"文": @1270,
            @"秋": @1265, @"無": @1260, @"開": @1250, @"手": @1240, @"十": @1230,
            @"用": @1220, @"主": @1210,
            @"行": @1200, @"方": @1190, @"又": @1180, @"如": @1170, @"前": @1160,
            @"所": @1150, @"本": @1140, @"見": @1130, @"經": @1120, @"頭": @1110,
            @"面": @1100, @"公": @1090, @"同": @1080, @"三": @1070, @"已": @1060,
            @"老": @1050, @"從": @1040, @"動": @1030, @"兩": @1020, @"長": @1010,
            @"知": @1000, @"民": @990, @"樣": @980, @"現": @970, @"分": @960,
            @"將": @950, @"外": @940, @"但": @930, @"身": @920, @"些": @910,
            @"與": @900, @"高": @890, @"意": @880, @"進": @870, @"把": @860,
            @"法": @850, @"此": @840, @"實": @830, @"回": @820, @"二": @810,
            @"理": @800, @"美": @790, @"點": @780, @"月": @770, @"明": @760,
            @"啲": @1755, @"唔": @1754, @"係": @1753, @"佢": @1752, @"咁": @1751,
            @"哋": @1750, @"嘢": @1749, @"功": @1305, @"勁": @1295, @"巧": @1285
        };
    });
    return [boosts[text] integerValue];
}

- (BOOL)isCandidateTextDisplayable:(NSString *)text {
    if (text.length == 0) {
        return NO;
    }

    for (NSUInteger index = 0; index < text.length; index += 1) {
        unichar character = [text characterAtIndex:index];
        if (CFStringIsSurrogateHighCharacter(character) || CFStringIsSurrogateLowCharacter(character)) {
            return NO;
        }
        if (character == 0xFFFD || (character >= 0xE000 && character <= 0xF8FF)) {
            return NO;
        }
        if ([[NSCharacterSet controlCharacterSet] characterIsMember:character]) {
            return NO;
        }
    }

    return YES;
}

- (BOOL)isHKSCSCandidateTextDisplayable:(NSString *)text {
    if (text.length == 0) {
        return NO;
    }

    for (NSUInteger index = 0; index < text.length; index += 1) {
        unichar character = [text characterAtIndex:index];
        uint32_t scalar = 0;
        if (CFStringIsSurrogateHighCharacter(character)) {
            if (index + 1 >= text.length) {
                return NO;
            }
            unichar low = [text characterAtIndex:index + 1];
            if (!CFStringIsSurrogateLowCharacter(low)) {
                return NO;
            }
            scalar = ((uint32_t)(character - 0xD800) << 10) + (uint32_t)(low - 0xDC00) + 0x10000;
            index += 1;
        } else if (CFStringIsSurrogateLowCharacter(character)) {
            return NO;
        } else {
            scalar = character;
        }

        if (scalar == 0xFFFD ||
            [self isPrivateUseScalar:scalar] ||
            scalar <= 0x1F ||
            (scalar >= 0x7F && scalar <= 0x9F)) {
            return NO;
        }
    }

    return YES;
}

- (BOOL)isPrivateUseScalar:(uint32_t)scalar {
    return (scalar >= 0xE000 && scalar <= 0xF8FF) ||
           (scalar >= 0xF0000 && scalar <= 0xFFFFD) ||
           (scalar >= 0x100000 && scalar <= 0x10FFFD);
}

- (BOOL)isTraditionalCandidateText:(NSString *)text {
    NSMutableString *converted = [text mutableCopy];
    if (!CFStringTransform((__bridge CFMutableStringRef)converted, NULL, CFSTR("Hans-Hant"), false)) {
        return YES;
    }
    return [converted isEqualToString:text];
}

- (BOOL)isTraditionalCompatibilityCandidateText:(NSString *)text {
    return [self.traditionalCompatibilityTexts containsObject:text];
}

- (BOOL)isHKSCSChineseCandidateText:(NSString *)text {
    if (text.length == 0) {
        return NO;
    }

    for (NSUInteger index = 0; index < text.length; index += 1) {
        unichar character = [text characterAtIndex:index];
        uint32_t scalar = 0;
        if (CFStringIsSurrogateHighCharacter(character)) {
            if (index + 1 >= text.length) {
                return NO;
            }
            unichar low = [text characterAtIndex:index + 1];
            if (!CFStringIsSurrogateLowCharacter(low)) {
                return NO;
            }
            scalar = ((uint32_t)(character - 0xD800) << 10) + (uint32_t)(low - 0xDC00) + 0x10000;
            index += 1;
        } else if (CFStringIsSurrogateLowCharacter(character)) {
            return NO;
        } else {
            scalar = character;
        }

        if ([self isHanScalar:scalar]) {
            return YES;
        }
    }
    return NO;
}

- (uint32_t)firstUnicodeScalarInString:(NSString *)text {
    if (text.length == 0) {
        return 0;
    }

    unichar first = [text characterAtIndex:0];
    if (CFStringIsSurrogateHighCharacter(first) && text.length >= 2) {
        unichar low = [text characterAtIndex:1];
        if (CFStringIsSurrogateLowCharacter(low)) {
            return ((uint32_t)(first - 0xD800) << 10) + (uint32_t)(low - 0xDC00) + 0x10000;
        }
    }
    if (CFStringIsSurrogateLowCharacter(first)) {
        return 0;
    }
    return first;
}

- (BOOL)isHanScalar:(uint32_t)scalar {
    return (scalar >= 0x3400 && scalar <= 0x4DBF) ||
           (scalar >= 0x4E00 && scalar <= 0x9FFF) ||
           (scalar >= 0xF900 && scalar <= 0xFAFF) ||
           (scalar >= 0x20000 && scalar <= 0x3FFFD);
}

- (NSString *)lastDisplayableCharacterInText:(NSString *)text {
    __block NSString *last = @"";
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences | NSStringEnumerationReverse
                          usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substringRange;
        (void)enclosingRange;
        if ([self isCandidateTextDisplayable:substring] && [self isTraditionalCandidateText:substring]) {
            last = substring;
            *stop = YES;
        }
    }];
    return last;
}

- (NSArray<NSString *> *)displayableCharactersInText:(NSString *)text {
    if (text.length == 0) {
        return @[];
    }

    NSMutableArray<NSString *> *characters = [NSMutableArray array];
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substringRange;
        (void)enclosingRange;
        (void)stop;
        if ([self isCandidateTextDisplayable:substring] && [self isTraditionalCandidateText:substring]) {
            [characters addObject:substring];
        }
    }];
    return characters;
}

- (NSArray<NSString *> *)associationLookupKeysForText:(NSString *)text {
    NSArray<NSString *> *characters = [self displayableCharactersInText:text ?: @""];
    if (characters.count == 0) {
        return @[];
    }

    NSMutableArray<NSString *> *keys = [NSMutableArray arrayWithCapacity:2];
    NSString *fullText = [characters componentsJoinedByString:@""];
    if (fullText.length > 0) {
        [keys addObject:fullText];
    }

    NSString *lastCharacter = characters.lastObject;
    if (lastCharacter.length > 0 && ![lastCharacter isEqualToString:fullText]) {
        [keys addObject:lastCharacter];
    }
    return keys;
}

- (NSArray<NSString *> *)fixedAssociationCandidatesForKey:(NSString *)key {
    if (key.length == 0) {
        return @[];
    }

    NSArray<NSString *> *manualCandidates = self.associationIndex[key] ?: @[];
    NSArray<NSString *> *generatedCandidates = [self generatedAssociationCandidatesForKey:key];
    if (manualCandidates.count == 0) {
        return generatedCandidates;
    }
    if (generatedCandidates.count == 0) {
        return manualCandidates;
    }

    NSMutableArray<NSString *> *combined = [manualCandidates mutableCopy];
    NSMutableSet<NSString *> *seen = [NSMutableSet setWithArray:manualCandidates];
    for (NSString *candidate in generatedCandidates) {
        if ([seen containsObject:candidate]) {
            continue;
        }
        [seen addObject:candidate];
        [combined addObject:candidate];
    }
    return [combined copy];
}

- (NSArray<NSString *> *)generatedAssociationCandidatesForKey:(NSString *)key {
    if (key.length == 0) {
        return @[];
    }

    [self ensureGeneratedAssociationDataLoaded];
    return [self.generatedAssociationIndex candidatesForKey:key] ?: @[];
}

- (void)addAssociationPhraseText:(NSString *)text {
    NSArray<NSString *> *characters = [self displayableCharactersInText:text];
    if (characters.count < 2) {
        return;
    }

    for (NSUInteger index = 0; index + 1 < characters.count; index += 1) {
        [self addAssociationFromText:characters[index] toText:characters[index + 1]];
    }
}

- (void)addAssociationPhraseSeedText:(NSString *)text {
    NSArray<NSString *> *characters = [self displayableCharactersInText:text];
    if (characters.count < 2) {
        return;
    }

    NSString *phrase = [characters componentsJoinedByString:@""];
    if (![self.associationPhraseSeeds containsObject:phrase]) {
        [self.associationPhraseSeeds addObject:phrase];
    }
}

- (void)addAssociationFromText:(NSString *)key toText:(NSString *)candidate {
    NSString *continuation = [self associationContinuationFromKey:key candidate:candidate];
    if (key.length == 0 ||
        continuation.length == 0 ||
        ![self isCandidateTextDisplayable:key] ||
        ![self isTraditionalCandidateText:key] ||
        ![self isCandidateTextDisplayable:continuation] ||
        ![self isTraditionalCandidateText:continuation]) {
        return;
    }

    NSMutableArray<NSString *> *bucket = self.associationIndex[key];
    if (!bucket) {
        bucket = [NSMutableArray array];
        self.associationIndex[key] = bucket;
    }

    if (![bucket containsObject:continuation]) {
        [bucket addObject:continuation];
    }
}

- (NSString *)associationContinuationFromKey:(NSString *)key candidate:(NSString *)candidate {
    NSArray<NSString *> *keyCharacters = [self displayableCharactersInText:key ?: @""];
    NSArray<NSString *> *candidateCharacters = [self displayableCharactersInText:candidate ?: @""];
    if (keyCharacters.count == 0 || candidateCharacters.count == 0) {
        return @"";
    }

    NSUInteger maxOverlap = MIN(keyCharacters.count, candidateCharacters.count - 1);
    for (NSUInteger overlap = maxOverlap; overlap > 0; overlap -= 1) {
        BOOL matches = YES;
        for (NSUInteger index = 0; index < overlap; index += 1) {
            NSString *keyCharacter = keyCharacters[keyCharacters.count - overlap + index];
            NSString *candidateCharacter = candidateCharacters[index];
            if (![keyCharacter isEqualToString:candidateCharacter]) {
                matches = NO;
                break;
            }
        }

        if (matches) {
            NSRange continuationRange = NSMakeRange(overlap, candidateCharacters.count - overlap);
            NSArray<NSString *> *continuation = [candidateCharacters subarrayWithRange:continuationRange];
            return [continuation componentsJoinedByString:@""];
        }
    }

    return [candidateCharacters componentsJoinedByString:@""];
}

- (NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *)buildAssociationIndex {
    NSDictionary<NSString *, NSArray<NSString *> *> *seed = @{
        @"我": @[@"們", @"的", @"都", @"是", @"會", @"想", @"要", @"有", @"在", @"唔"],
        @"們": @[@"是", @"都", @"會", @"的", @"要", @"有", @"唔"],
        @"你": @[@"好", @"們", @"的", @"是", @"會", @"要", @"有", @"想", @"在", @"唔"],
        @"佢": @[@"哋", @"的", @"係", @"都", @"會", @"要", @"有", @"想"],
        @"他": @[@"們", @"的", @"是", @"會", @"要", @"有", @"在"],
        @"她": @[@"們", @"的", @"是", @"會", @"要", @"有", @"在"],
        @"的": @[@"人", @"事", @"時", @"話", @"地", @"一", @"個", @"是", @"了", @"問題"],
        @"是": @[@"一", @"我", @"你", @"佢", @"的", @"唔", @"因為"],
        @"一": @[@"個", @"啲", @"家", @"樣", @"定", @"直"],
        @"家": @[@"人", @"庭", @"用", @"中"],
        @"人": @[@"都", @"哋", @"係", @"有", @"會"],
        @"係": @[@"咪", @"度", @"咁", @"我", @"你", @"佢", @"唔", @"一", @"個"],
        @"唔": @[@"係", @"好", @"知", @"使", @"要", @"會", @"得", @"該", @"想"],
        @"好": @[@"多", @"似", @"快", @"耐", @"大", @"少", @"想", @"用", @"睇"],
        @"有": @[@"冇", @"人", @"啲", @"個", @"時", @"機", @"關", @"用", @"問題"],
        @"無": @[@"論", @"法", @"人", @"事", @"線", @"效"],
        @"冇": @[@"事", @"人", @"用", @"問題", @"辦法", @"可能"],
        @"想": @[@"問", @"講", @"知", @"要", @"做", @"睇", @"試"],
        @"要": @[@"用", @"做", @"試", @"睇", @"先", @"求", @"有"],
        @"會": @[@"唔", @"有", @"係", @"用", @"做", @"出", @"再"],
        @"可以": @[@"用", @"試", @"做", @"睇", @"再"],
        @"中": @[@"文", @"國", @"間", @"心", @"午"],
        @"香": @[@"港"],
        @"港": @[@"人", @"島", @"幣", @"式"],
        @"電": @[@"話", @"腦", @"郵", @"視"],
        @"輸": @[@"入", @"出"],
        @"入": @[@"法", @"面", @"去"],
        @"字": @[@"庫", @"形", @"元", @"詞"],
        @"關": @[@"聯", @"係", @"於", @"鍵"],
        @"聯": @[@"字", @"絡", @"繫"],
        @"速": @[@"成", @"度"],
        @"倉": @[@"頡"],
        @"拼": @[@"音"],
        @"筆": @[@"劃", @"畫"],
        @"今": @[@"日", @"天", @"晚"],
        @"明": @[@"日", @"天", @"白"],
        @"日": @[@"期", @"本", @"常", @"子"],
        @"時": @[@"間", @"候", @"代"],
        @"間": @[@"中", @"唔", @"房"],
        @"問": @[@"題", @"下", @"你"],
        @"題": @[@"目", @"材"],
        @"用": @[@"家", @"戶", @"法", @"完", @"唔"],
        @"打": @[@"字", @"開", @"算", @"機"],
        @"開": @[@"始", @"機", @"發", @"心"],
        @"發": @[@"現", @"生", @"展", @"出"],
        @"現": @[@"在", @"時", @"場"],
        @"再": @[@"試", @"講", @"做", @"睇"],
        @"試": @[@"下", @"用", @"過"],
        @"做": @[@"到", @"法", @"完", @"嘢"],
        @"睇": @[@"到", @"下", @"吓", @"返"],
        @"先": @[@"至", @"生", @"後"],
        @"返": @[@"去", @"來", @"工"],
        @"工": @[@"作", @"具", @"程"],
        @"作": @[@"業", @"用", @"者"],
        @"程": @[@"式", @"度"],
        @"式": @[@"樣", @"子"],
        @"樣": @[@"本", @"式", @"嘢"],
        @"嘢": @[@"都", @"係", @"唔"],
        @"啲": @[@"人", @"字", @"嘢", @"資料"]
    };

    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *index = [NSMutableDictionary dictionaryWithCapacity:seed.count];
    for (NSString *key in seed) {
        NSMutableArray<NSString *> *filtered = [NSMutableArray array];
        NSMutableSet<NSString *> *seen = [NSMutableSet set];
        for (NSString *candidate in seed[key]) {
            if ([seen containsObject:candidate] ||
                ![self isCandidateTextDisplayable:candidate] ||
                ![self isTraditionalCandidateText:candidate]) {
                continue;
            }
            [seen addObject:candidate];
            [filtered addObject:candidate];
        }
        if (filtered.count > 0) {
            index[key] = filtered;
        }
    }
    return index;
}

- (NSArray<MKCandidate *> *)candidateBucketForCode:(NSString *)code mode:(MKInputMode)mode {
    return [[self candidateProviderForMode:mode] candidatesForInput:code];
}

- (NSSet<NSString *> *)prefixesForMode:(MKInputMode)mode {
    return [[self candidateProviderForMode:mode] prefixes];
}

- (id<MKCandidateProvider>)candidateProviderForMode:(MKInputMode)mode {
    if ([mode isEqualToString:MKInputModeEnglish]) {
        return self.emptyCandidateProvider;
    }

    id<MKCandidateProvider> provider = nil;
    if (mode.length > 0) {
        provider = self.candidateProvidersByMode[mode];
    }
    return provider ?: self.mixedCandidateProvider;
}

- (MKCandidateTableIndex *)candidateIndexForSource:(NSString *)source {
    if ([source isEqualToString:MKInputModeSucheng]) {
        return self.quickCandidateIndex;
    }
    if ([source isEqualToString:MKInputModeCangjie]) {
        return self.cangjieCandidateIndex;
    }
    if ([source isEqualToString:MKInputModePinyin]) {
        return self.pinyinCandidateIndex;
    }
    return nil;
}

- (NSArray<NSString *> *)candidateIndexCodesForSource:(NSString *)source {
    return [[self candidateIndexForSource:source] allCodes] ?: @[];
}

- (NSArray<MKCandidate *> *)candidateBucketForCode:(NSString *)code source:(NSString *)source {
    if (code.length == 0 || source.length == 0) {
        return @[];
    }

    NSMutableArray<MKCandidate *> *bucket = [NSMutableArray array];
    NSArray<MKCandidate *> *indexedCandidates = [[self candidateIndexForSource:source] candidatesForCode:code engine:self] ?: @[];
    [bucket addObjectsFromArray:indexedCandidates];

    NSArray<MKCandidate *> *overlayCandidates = self.indexBySource[source][code] ?: @[];
    [bucket addObjectsFromArray:overlayCandidates];
    if (bucket.count == 0) {
        return @[];
    }

    [self sortCandidateBucket:bucket];
    NSArray<NSString *> *override = self.candidateOrderOverrides[[self overrideKeyForSource:source code:code]];
    if (override.count > 0) {
        [self applyCandidateOrderOverride:override toBucket:bucket];
    }
    return [bucket copy];
}

- (NSArray<MKCandidate *> *)unifiedCandidateBucketForCode:(NSString *)code {
    if (code.length == 0) {
        return @[];
    }

    NSMutableArray<MKCandidate *> *bucket = [NSMutableArray array];
    for (NSString *source in @[MKInputModeSucheng, MKInputModeCangjie, MKInputModePinyin]) {
        [bucket addObjectsFromArray:[self candidateBucketForCode:code source:source]];
    }
    if (bucket.count == 0) {
        return @[];
    }

    [self sortCandidateBucket:bucket];
    return [bucket copy];
}

- (BOOL)hasCandidatesOrPrefixesForCode:(NSString *)code source:(NSString *)source {
    if (code.length == 0 || source.length == 0) {
        return NO;
    }

    if ([[self candidateIndexForSource:source] hasCandidatesOrPrefixesForCode:code engine:self]) {
        return YES;
    }

    return (self.indexBySource[source][code].count > 0 ||
            [self.prefixesBySource[source] containsObject:code]);
}

- (BOOL)unifiedHasCandidatesOrPrefixesForCode:(NSString *)code {
    if (code.length == 0) {
        return NO;
    }

    for (NSString *source in @[MKInputModeSucheng, MKInputModeCangjie, MKInputModePinyin]) {
        if ([self hasCandidatesOrPrefixesForCode:code source:source]) {
            return YES;
        }
    }
    return NO;
}

- (NSSet<NSString *> *)prefixesForSource:(NSString *)source {
    if (source.length == 0) {
        return [NSSet set];
    }
    return self.prefixesBySource[source] ?: [NSSet set];
}

- (NSSet<NSString *> *)unifiedPrefixes {
    return self.prefixes ?: [NSSet set];
}

- (void)addPrefixesForCode:(NSString *)code source:(NSString *)source includingInUnifiedIndex:(BOOL)includingInUnifiedIndex {
    if (code.length == 0) {
        return;
    }

    NSMutableSet<NSString *> *sourcePrefixes = self.prefixesBySource[source];
    if (!sourcePrefixes) {
        sourcePrefixes = [NSMutableSet set];
        self.prefixesBySource[source] = sourcePrefixes;
    }

    for (NSUInteger length = 1; length <= code.length; length++) {
        NSString *prefix = [code substringToIndex:length];
        if (includingInUnifiedIndex) {
            [self.prefixes addObject:prefix];
        }
        [sourcePrefixes addObject:prefix];
    }
}

@end
