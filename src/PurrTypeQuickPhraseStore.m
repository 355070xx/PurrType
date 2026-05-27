#import "PurrTypeQuickPhraseStore.h"

NSString *const MKQuickPhraseStoreErrorDomain = @"org.purrtype.QuickPhraseStore";

static NSString *const MKQuickPhraseFileName = @"quick-phrases.json";
static NSUInteger const MKQuickPhraseMaxTriggerLength = 32;
static NSUInteger const MKQuickPhraseMaxReplacementLength = 512;
static NSUInteger const MKQuickPhraseMaxLabelLength = 80;
static NSUInteger const MKQuickPhraseMaxEntries = 1000;

typedef NS_ENUM(NSInteger, MKQuickPhraseStoreErrorCode) {
    MKQuickPhraseStoreErrorInvalidTrigger = 1,
    MKQuickPhraseStoreErrorInvalidReplacement = 2,
    MKQuickPhraseStoreErrorInvalidJSON = 3,
    MKQuickPhraseStoreErrorTooManyEntries = 4
};

static NSError *MKQuickPhraseStoreError(MKQuickPhraseStoreErrorCode code, NSString *message) {
    return [NSError errorWithDomain:MKQuickPhraseStoreErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message ?: @"Quick phrase store error" }];
}

static NSDateFormatter *MKQuickPhraseDateFormatter(void) {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    });
    return formatter;
}

static NSString *MKQuickPhraseStringFromDate(NSDate *date) {
    return [MKQuickPhraseDateFormatter() stringFromDate:date ?: [NSDate date]];
}

static NSDate *MKQuickPhraseDateFromString(NSString *dateString) {
    if (![dateString isKindOfClass:[NSString class]] || dateString.length == 0) {
        return [NSDate date];
    }
    return [MKQuickPhraseDateFormatter() dateFromString:dateString] ?: [NSDate date];
}

@interface PurrTypeQuickPhraseEntry ()

@property(nonatomic, copy, readwrite) NSString *trigger;
@property(nonatomic, copy, readwrite) NSString *normalizedTrigger;
@property(nonatomic, copy, readwrite) NSString *replacement;
@property(nonatomic, copy, readwrite) NSString *label;
@property(nonatomic, assign, readwrite, getter=isEnabled) BOOL enabled;
@property(nonatomic, strong, readwrite) NSDate *createdAt;
@property(nonatomic, strong, readwrite) NSDate *updatedAt;

+ (nullable instancetype)entryWithDictionary:(NSDictionary<NSString *, id> *)dictionary;

@end

@implementation PurrTypeQuickPhraseEntry

- (instancetype)initWithTrigger:(NSString *)trigger
                    replacement:(NSString *)replacement
                          label:(NSString *)label
                        enabled:(BOOL)enabled
                      createdAt:(NSDate *)createdAt
                      updatedAt:(NSDate *)updatedAt {
    self = [super init];
    if (self) {
        NSString *trimmedTrigger = [trigger stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
        NSString *trimmedReplacement = [replacement stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
        _trigger = [trimmedTrigger copy];
        _normalizedTrigger = [PurrTypeQuickPhraseStore normalizedTriggerForTrigger:trimmedTrigger];
        _replacement = [trimmedReplacement copy];
        _label = [label copy] ?: @"";
        _enabled = enabled;
        _createdAt = createdAt ?: [NSDate date];
        _updatedAt = updatedAt ?: _createdAt;
    }
    return self;
}

+ (instancetype)entryWithDictionary:(NSDictionary<NSString *, id> *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSString *trigger = [dictionary[@"trigger"] isKindOfClass:[NSString class]] ? (NSString *)dictionary[@"trigger"] : @"";
    NSString *replacement = [dictionary[@"replacement"] isKindOfClass:[NSString class]] ? (NSString *)dictionary[@"replacement"] : @"";
    NSString *label = [dictionary[@"label"] isKindOfClass:[NSString class]] ? (NSString *)dictionary[@"label"] : @"";
    NSNumber *enabled = [dictionary[@"enabled"] isKindOfClass:[NSNumber class]] ? (NSNumber *)dictionary[@"enabled"] : @YES;
    if (![PurrTypeQuickPhraseStore isValidTrigger:trigger] ||
        ![PurrTypeQuickPhraseStore isValidReplacement:replacement] ||
        label.length > MKQuickPhraseMaxLabelLength) {
        return nil;
    }

    NSDate *createdAt = MKQuickPhraseDateFromString([dictionary[@"createdAt"] isKindOfClass:[NSString class]] ? (NSString *)dictionary[@"createdAt"] : nil);
    NSDate *updatedAt = MKQuickPhraseDateFromString([dictionary[@"updatedAt"] isKindOfClass:[NSString class]] ? (NSString *)dictionary[@"updatedAt"] : nil);
    return [[self alloc] initWithTrigger:trigger
                              replacement:replacement
                                    label:label
                                  enabled:enabled.boolValue
                                createdAt:createdAt
                                updatedAt:updatedAt];
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    return @{
        @"trigger": self.trigger,
        @"normalizedTrigger": self.normalizedTrigger,
        @"replacement": self.replacement,
        @"label": self.label,
        @"enabled": @(self.enabled),
        @"createdAt": MKQuickPhraseStringFromDate(self.createdAt),
        @"updatedAt": MKQuickPhraseStringFromDate(self.updatedAt)
    };
}

@end

@implementation PurrTypeQuickPhraseImportSummary

- (instancetype)initWithImportedCount:(NSUInteger)importedCount
                         updatedCount:(NSUInteger)updatedCount
                         skippedCount:(NSUInteger)skippedCount
                         invalidCount:(NSUInteger)invalidCount {
    self = [super init];
    if (self) {
        _importedCount = importedCount;
        _updatedCount = updatedCount;
        _skippedCount = skippedCount;
        _invalidCount = invalidCount;
    }
    return self;
}

@end

@interface PurrTypeQuickPhraseStore ()

@property(nonatomic, copy, readwrite) NSString *directoryPath;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<PurrTypeQuickPhraseEntry *> *> *entriesByTrigger;
@property(nonatomic, strong, nullable) NSDate *lastLoadedModificationDate;

@end

@implementation PurrTypeQuickPhraseStore

+ (instancetype)defaultStore {
    static PurrTypeQuickPhraseStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[PurrTypeQuickPhraseStore alloc] initWithDirectoryPath:[self defaultDirectoryPath]];
    });
    return store;
}

+ (NSString *)defaultDirectoryPath {
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    if (basePath.length == 0) {
        basePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    }
    return [[basePath stringByAppendingPathComponent:@"PurrType"] copy];
}

+ (NSString *)normalizedTriggerForTrigger:(NSString *)trigger {
    if (![trigger isKindOfClass:[NSString class]]) {
        return @"";
    }
    NSString *trimmed = [trigger stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [trimmed lowercaseString];
}

+ (BOOL)isTriggerContinuationString:(NSString *)string {
    if (![string isKindOfClass:[NSString class]] || string.length != 1) {
        return NO;
    }
    NSString *normalized = [string lowercaseString];
    unichar character = [normalized characterAtIndex:0];
    return (character >= 'a' && character <= 'z') ||
           (character >= '0' && character <= '9') ||
           character == '_' ||
           character == '-';
}

+ (BOOL)isValidTrigger:(NSString *)trigger {
    NSString *normalized = [self normalizedTriggerForTrigger:trigger];
    if (normalized.length < 2 || normalized.length > MKQuickPhraseMaxTriggerLength || ![normalized hasPrefix:@";"]) {
        return NO;
    }
    NSString *suffix = [normalized substringFromIndex:1];
    for (NSUInteger index = 0; index < suffix.length; index += 1) {
        NSString *character = [suffix substringWithRange:NSMakeRange(index, 1)];
        if (![self isTriggerContinuationString:character]) {
            return NO;
        }
    }
    return YES;
}

+ (BOOL)isValidReplacement:(NSString *)replacement {
    if (![replacement isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *trimmed = [replacement stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0 || trimmed.length > MKQuickPhraseMaxReplacementLength) {
        return NO;
    }
    NSMutableCharacterSet *disallowed = [[NSCharacterSet controlCharacterSet] mutableCopy];
    [disallowed formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
    return [trimmed rangeOfCharacterFromSet:disallowed].location == NSNotFound;
}

- (instancetype)initWithDirectoryPath:(NSString *)directoryPath {
    self = [super init];
    if (self) {
        _directoryPath = [directoryPath copy] ?: @"";
        _entriesByTrigger = [NSMutableDictionary dictionary];
        [self loadWithError:nil];
    }
    return self;
}

- (NSUInteger)entryCount {
    NSUInteger count = 0;
    for (NSArray<PurrTypeQuickPhraseEntry *> *entries in self.entriesByTrigger.allValues) {
        count += entries.count;
    }
    return count;
}

- (NSMutableArray<PurrTypeQuickPhraseEntry *> *)entriesForNormalizedTrigger:(NSString *)normalized create:(BOOL)create {
    if (normalized.length == 0) {
        return nil;
    }
    NSMutableArray<PurrTypeQuickPhraseEntry *> *entries = self.entriesByTrigger[normalized];
    if (!entries && create) {
        entries = [NSMutableArray array];
        self.entriesByTrigger[normalized] = entries;
    }
    return entries;
}

- (NSUInteger)indexOfReplacement:(NSString *)replacement inEntries:(NSArray<PurrTypeQuickPhraseEntry *> *)entries {
    NSString *trimmedReplacement = [replacement stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    for (NSUInteger index = 0; index < entries.count; index += 1) {
        if ([entries[index].replacement isEqualToString:trimmedReplacement]) {
            return index;
        }
    }
    return NSNotFound;
}

- (BOOL)addOrReplaceEntry:(PurrTypeQuickPhraseEntry *)entry
               toBuckets:(NSMutableDictionary<NSString *, NSMutableArray<PurrTypeQuickPhraseEntry *> *> *)buckets
             currentCount:(NSUInteger *)currentCount
                   error:(NSError **)error {
    if (entry.normalizedTrigger.length == 0) {
        return NO;
    }

    NSMutableArray<PurrTypeQuickPhraseEntry *> *entries = buckets[entry.normalizedTrigger];
    if (!entries) {
        entries = [NSMutableArray array];
        buckets[entry.normalizedTrigger] = entries;
    }

    NSUInteger existingIndex = [self indexOfReplacement:entry.replacement inEntries:entries];
    if (existingIndex != NSNotFound) {
        entries[existingIndex] = entry;
        return YES;
    }

    if (currentCount && *currentCount >= MKQuickPhraseMaxEntries) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorTooManyEntries, @"Quick phrase store contains too many entries.");
        }
        return NO;
    }

    [entries addObject:entry];
    if (currentCount) {
        *currentCount += 1;
    }
    return YES;
}

- (BOOL)loadWithError:(NSError **)error {
    NSString *path = [self pathForQuickPhraseFile];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        self.entriesByTrigger = [NSMutableDictionary dictionary];
        self.lastLoadedModificationDate = nil;
        return YES;
    }

    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) {
        return NO;
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (!object) {
        return NO;
    }

    NSArray *rawEntries = nil;
    if ([object isKindOfClass:[NSDictionary class]]) {
        id entries = ((NSDictionary *)object)[@"entries"];
        rawEntries = [entries isKindOfClass:[NSArray class]] ? entries : @[];
    } else if ([object isKindOfClass:[NSArray class]]) {
        rawEntries = object;
    } else {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorInvalidJSON, @"Quick phrase JSON must be an object or array.");
        }
        return NO;
    }

    if (rawEntries.count > MKQuickPhraseMaxEntries) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorTooManyEntries, @"Quick phrase JSON contains too many entries.");
        }
        return NO;
    }

    NSMutableDictionary<NSString *, NSMutableArray<PurrTypeQuickPhraseEntry *> *> *loadedEntries = [NSMutableDictionary dictionary];
    NSUInteger loadedCount = 0;
    for (id value in rawEntries) {
        PurrTypeQuickPhraseEntry *entry = [PurrTypeQuickPhraseEntry entryWithDictionary:value];
        if (entry) {
            if (![self addOrReplaceEntry:entry toBuckets:loadedEntries currentCount:&loadedCount error:error]) {
                return NO;
            }
        }
    }
    self.entriesByTrigger = loadedEntries;
    NSDictionary<NSFileAttributeKey, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    self.lastLoadedModificationDate = [attributes[NSFileModificationDate] isKindOfClass:[NSDate class]] ? attributes[NSFileModificationDate] : nil;
    return YES;
}

- (BOOL)saveWithError:(NSError **)error {
    if (self.directoryPath.length == 0) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorInvalidJSON, @"Quick phrase directory is unavailable.");
        }
        return NO;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createDirectoryAtPath:self.directoryPath
                withIntermediateDirectories:YES
                                 attributes:@{ NSFilePosixPermissions: @0700 }
                                      error:error]) {
        return NO;
    }
    [fileManager setAttributes:@{ NSFilePosixPermissions: @0700 } ofItemAtPath:self.directoryPath error:nil];

    NSData *data = [self exportJSONDataWithError:error];
    if (!data) {
        return NO;
    }
    NSString *path = [self pathForQuickPhraseFile];
    if (![data writeToFile:path options:NSDataWritingAtomic error:error]) {
        return NO;
    }
    [fileManager setAttributes:@{ NSFilePosixPermissions: @0600 } ofItemAtPath:path error:nil];
    NSDictionary<NSFileAttributeKey, id> *attributes = [fileManager attributesOfItemAtPath:path error:nil];
    self.lastLoadedModificationDate = [attributes[NSFileModificationDate] isKindOfClass:[NSDate class]] ? attributes[NSFileModificationDate] : nil;
    return YES;
}

- (NSArray<PurrTypeQuickPhraseEntry *> *)entries {
    NSMutableArray<PurrTypeQuickPhraseEntry *> *values = [NSMutableArray arrayWithCapacity:[self entryCount]];
    for (NSArray<PurrTypeQuickPhraseEntry *> *entries in self.entriesByTrigger.allValues) {
        [values addObjectsFromArray:entries];
    }
    return [values sortedArrayUsingComparator:^NSComparisonResult(PurrTypeQuickPhraseEntry *left, PurrTypeQuickPhraseEntry *right) {
        NSComparisonResult triggerResult = [left.normalizedTrigger compare:right.normalizedTrigger];
        if (triggerResult != NSOrderedSame) {
            return triggerResult;
        }
        NSComparisonResult dateResult = [left.createdAt compare:right.createdAt];
        if (dateResult != NSOrderedSame) {
            return dateResult;
        }
        return [left.replacement compare:right.replacement];
    }];
}

- (PurrTypeQuickPhraseEntry *)entryForTrigger:(NSString *)trigger {
    return [self entriesForTrigger:trigger].firstObject;
}

- (NSArray<PurrTypeQuickPhraseEntry *> *)entriesForTrigger:(NSString *)trigger {
    NSString *normalized = [PurrTypeQuickPhraseStore normalizedTriggerForTrigger:trigger];
    if (normalized.length == 0) {
        return @[];
    }
    NSArray<PurrTypeQuickPhraseEntry *> *entries = [self.entriesByTrigger[normalized] copy] ?: @[];
    return [entries sortedArrayUsingComparator:^NSComparisonResult(PurrTypeQuickPhraseEntry *left, PurrTypeQuickPhraseEntry *right) {
        NSComparisonResult dateResult = [left.createdAt compare:right.createdAt];
        if (dateResult != NSOrderedSame) {
            return dateResult;
        }
        return [left.replacement compare:right.replacement];
    }];
}

- (PurrTypeQuickPhraseEntry *)enabledEntryForTrigger:(NSString *)trigger {
    return [self enabledEntriesForTrigger:trigger].firstObject;
}

- (NSArray<PurrTypeQuickPhraseEntry *> *)enabledEntriesForTrigger:(NSString *)trigger {
    NSMutableArray<PurrTypeQuickPhraseEntry *> *enabledEntries = [NSMutableArray array];
    for (PurrTypeQuickPhraseEntry *entry in [self entriesForTrigger:trigger]) {
        if (entry.enabled) {
            [enabledEntries addObject:entry];
        }
    }
    return enabledEntries;
}

- (PurrTypeQuickPhraseEntry *)upsertTrigger:(NSString *)trigger
                                replacement:(NSString *)replacement
                                      label:(NSString *)label
                                    enabled:(BOOL)enabled
                                      error:(NSError **)error {
    if (![PurrTypeQuickPhraseStore isValidTrigger:trigger]) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorInvalidTrigger, @"Quick phrase trigger must start with ; and use letters, numbers, _ or -.");
        }
        return nil;
    }
    if (![PurrTypeQuickPhraseStore isValidReplacement:replacement]) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorInvalidReplacement, @"Quick phrase replacement must be one line of text.");
        }
        return nil;
    }
    if (label.length > MKQuickPhraseMaxLabelLength) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorInvalidJSON, @"Quick phrase label is too long.");
        }
        return nil;
    }

    NSString *normalized = [PurrTypeQuickPhraseStore normalizedTriggerForTrigger:trigger];
    NSMutableArray<PurrTypeQuickPhraseEntry *> *entries = [self entriesForNormalizedTrigger:normalized create:YES];
    NSString *trimmedReplacement = [replacement stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    NSUInteger existingIndex = [self indexOfReplacement:trimmedReplacement inEntries:entries];
    PurrTypeQuickPhraseEntry *existing = existingIndex == NSNotFound ? nil : entries[existingIndex];
    if (!existing && [self entryCount] >= MKQuickPhraseMaxEntries) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorTooManyEntries, @"Quick phrase store contains too many entries.");
        }
        return nil;
    }

    NSDate *now = [NSDate date];
    PurrTypeQuickPhraseEntry *entry =
        [[PurrTypeQuickPhraseEntry alloc] initWithTrigger:trigger
                                              replacement:replacement
                                                    label:label ?: @""
                                                  enabled:enabled
                                                createdAt:existing.createdAt ?: now
                                                updatedAt:now];
    if (existingIndex == NSNotFound) {
        [entries addObject:entry];
    } else {
        entries[existingIndex] = entry;
    }
    return entry;
}

- (BOOL)removeTrigger:(NSString *)trigger error:(NSError **)error {
    [self removeEntriesForTrigger:trigger replacement:nil error:error];
    return !error || !*error;
}

- (NSUInteger)removeEntriesForTrigger:(NSString *)trigger replacement:(NSString *)replacement error:(NSError **)error {
    if (![PurrTypeQuickPhraseStore isValidTrigger:trigger]) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorInvalidTrigger, @"Quick phrase trigger is invalid.");
        }
        return 0;
    }

    NSString *normalized = [PurrTypeQuickPhraseStore normalizedTriggerForTrigger:trigger];
    NSMutableArray<PurrTypeQuickPhraseEntry *> *entries = [self entriesForNormalizedTrigger:normalized create:NO];
    if (entries.count == 0) {
        return 0;
    }

    NSString *trimmedReplacement = [replacement stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    if (trimmedReplacement.length == 0) {
        NSUInteger removedCount = entries.count;
        [self.entriesByTrigger removeObjectForKey:normalized];
        return removedCount;
    }

    NSUInteger removedCount = 0;
    NSIndexSet *matchingIndexes = [entries indexesOfObjectsPassingTest:^BOOL(PurrTypeQuickPhraseEntry *entry, NSUInteger index, BOOL *stop) {
        (void)index;
        (void)stop;
        return [entry.replacement isEqualToString:trimmedReplacement];
    }];
    removedCount = matchingIndexes.count;
    if (removedCount > 0) {
        [entries removeObjectsAtIndexes:matchingIndexes];
        if (entries.count == 0) {
            [self.entriesByTrigger removeObjectForKey:normalized];
        }
    }
    return removedCount;
}

- (NSData *)exportJSONDataWithError:(NSError **)error {
    NSMutableArray<NSDictionary<NSString *, id> *> *entries = [NSMutableArray arrayWithCapacity:self.entries.count];
    for (PurrTypeQuickPhraseEntry *entry in self.entries) {
        [entries addObject:[entry dictionaryRepresentation]];
    }
    NSDictionary<NSString *, id> *root = @{ @"version": @1, @"entries": entries };
    NSData *data = [NSJSONSerialization dataWithJSONObject:root
                                                   options:(NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys)
                                                     error:error];
    if (!data && error && !*error) {
        *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorInvalidJSON, @"Unable to export quick phrases.");
    }
    return data;
}

- (PurrTypeQuickPhraseImportSummary *)importEntriesFromJSONData:(NSData *)data error:(NSError **)error {
    if (![data isKindOfClass:[NSData class]] || data.length == 0) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorInvalidJSON, @"Quick phrase JSON is empty.");
        }
        return nil;
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (!object) {
        return nil;
    }
    NSArray *rawEntries = nil;
    if ([object isKindOfClass:[NSDictionary class]]) {
        id entries = ((NSDictionary *)object)[@"entries"];
        rawEntries = [entries isKindOfClass:[NSArray class]] ? entries : @[];
    } else if ([object isKindOfClass:[NSArray class]]) {
        rawEntries = object;
    } else {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorInvalidJSON, @"Quick phrase JSON must be an object or array.");
        }
        return nil;
    }

    if (rawEntries.count > MKQuickPhraseMaxEntries) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorTooManyEntries, @"Quick phrase JSON contains too many entries.");
        }
        return nil;
    }

    NSUInteger importedCount = 0;
    NSUInteger updatedCount = 0;
    NSUInteger skippedCount = 0;
    NSUInteger invalidCount = 0;
    for (id value in rawEntries) {
        PurrTypeQuickPhraseEntry *entry = [PurrTypeQuickPhraseEntry entryWithDictionary:value];
        if (!entry) {
            invalidCount += 1;
            continue;
        }
        if (entry.normalizedTrigger.length == 0) {
            skippedCount += 1;
            continue;
        }
        NSMutableArray<PurrTypeQuickPhraseEntry *> *entries = [self entriesForNormalizedTrigger:entry.normalizedTrigger create:YES];
        NSUInteger existingIndex = [self indexOfReplacement:entry.replacement inEntries:entries];
        if (existingIndex != NSNotFound) {
            updatedCount += 1;
            entries[existingIndex] = entry;
        } else {
            if ([self entryCount] >= MKQuickPhraseMaxEntries) {
                invalidCount += 1;
                continue;
            }
            importedCount += 1;
            [entries addObject:entry];
        }
    }
    return [[PurrTypeQuickPhraseImportSummary alloc] initWithImportedCount:importedCount
                                                              updatedCount:updatedCount
                                                              skippedCount:skippedCount
                                                              invalidCount:invalidCount];
}

- (NSString *)exportText {
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithCapacity:self.entries.count + 2];
    [lines addObject:@"# PurrType quick phrases"];
    [lines addObject:@"# Format: ;trigger<TAB>replacement"];
    for (PurrTypeQuickPhraseEntry *entry in self.entries) {
        [lines addObject:[NSString stringWithFormat:@"%@\t%@", entry.trigger, entry.replacement]];
    }
    return [[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
}

- (PurrTypeQuickPhraseImportSummary *)importEntriesFromText:(NSString *)text error:(NSError **)error {
    if (![text isKindOfClass:[NSString class]] || text.length == 0) {
        if (error) {
            *error = MKQuickPhraseStoreError(MKQuickPhraseStoreErrorInvalidJSON, @"Quick phrase TXT is empty.");
        }
        return nil;
    }

    NSUInteger importedCount = 0;
    NSUInteger updatedCount = 0;
    NSUInteger skippedCount = 0;
    NSUInteger invalidCount = 0;
    NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedLine.length == 0 || [trimmedLine hasPrefix:@"#"]) {
            skippedCount += 1;
            continue;
        }

        NSRange tabRange = [line rangeOfString:@"\t"];
        if (tabRange.location == NSNotFound) {
            invalidCount += 1;
            continue;
        }

        NSString *trigger = [[line substringToIndex:tabRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *replacement = [[line substringFromIndex:NSMaxRange(tabRange)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (![PurrTypeQuickPhraseStore isValidTrigger:trigger] ||
            ![PurrTypeQuickPhraseStore isValidReplacement:replacement]) {
            invalidCount += 1;
            continue;
        }

        BOOL existed = NO;
        for (PurrTypeQuickPhraseEntry *existingEntry in [self entriesForTrigger:trigger]) {
            if ([existingEntry.replacement isEqualToString:replacement]) {
                existed = YES;
                break;
            }
        }
        NSError *upsertError = nil;
        PurrTypeQuickPhraseEntry *entry = [self upsertTrigger:trigger
                                                  replacement:replacement
                                                        label:@""
                                                      enabled:YES
                                                        error:&upsertError];
        if (!entry) {
            invalidCount += 1;
            continue;
        }
        if (existed) {
            updatedCount += 1;
        } else {
            importedCount += 1;
        }
    }
    return [[PurrTypeQuickPhraseImportSummary alloc] initWithImportedCount:importedCount
                                                              updatedCount:updatedCount
                                                              skippedCount:skippedCount
                                                              invalidCount:invalidCount];
}

- (BOOL)reloadIfChangedWithError:(NSError **)error {
    NSString *path = [self pathForQuickPhraseFile];
    NSError *attributesError = nil;
    NSDictionary<NSFileAttributeKey, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&attributesError];
    if (!attributes) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            if (error) {
                *error = attributesError;
            }
            return NO;
        }
        if (self.lastLoadedModificationDate) {
            self.entriesByTrigger = [NSMutableDictionary dictionary];
            self.lastLoadedModificationDate = nil;
        }
        return YES;
    }

    NSDate *modificationDate = [attributes[NSFileModificationDate] isKindOfClass:[NSDate class]] ? attributes[NSFileModificationDate] : nil;
    if (!self.lastLoadedModificationDate ||
        !modificationDate ||
        [modificationDate compare:self.lastLoadedModificationDate] != NSOrderedSame) {
        return [self loadWithError:error];
    }
    return YES;
}

- (NSString *)pathForQuickPhraseFile {
    return [self.directoryPath stringByAppendingPathComponent:MKQuickPhraseFileName];
}

@end
