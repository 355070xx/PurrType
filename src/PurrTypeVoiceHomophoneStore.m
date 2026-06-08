#import "PurrTypeVoiceHomophoneStore.h"

NSString *const PurrTypeVoiceHomophoneResourceName = @"cantonese_voice_homophones";
NSString *const PurrTypeVoiceHomophoneResourceExtension = @"tsv";

@interface PurrTypeVoiceHomophoneStore ()

@property(nonatomic, copy) NSDictionary<NSString *, NSArray<NSString *> *> *homophonesByCharacter;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *learnedCandidateScoresByCharacter;

@end

@implementation PurrTypeVoiceHomophoneStore

+ (instancetype)storeWithBundle:(NSBundle *)bundle {
    NSURL *resourceURL = [bundle URLForResource:PurrTypeVoiceHomophoneResourceName
                                  withExtension:PurrTypeVoiceHomophoneResourceExtension];
    return [[self alloc] initWithResourceURL:resourceURL];
}

- (instancetype)initWithResourceURL:(NSURL *)resourceURL {
    self = [super init];
    if (self) {
        _homophonesByCharacter = [self loadHomophonesAtURL:resourceURL];
        _learnedCandidateScoresByCharacter = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSArray<NSString *> *)homophonesForCharacter:(NSString *)character limit:(NSUInteger)limit {
    NSString *normalizedCharacter = [self normalizedSingleCharacter:character];
    if (normalizedCharacter.length == 0 || limit == 0) {
        return @[];
    }

    NSArray<NSString *> *group = [self candidateGroupForCharacter:normalizedCharacter];
    if (group.count < 2) {
        return @[];
    }

    NSMutableArray<NSString *> *baseGroup = [NSMutableArray arrayWithObject:normalizedCharacter];
    for (NSString *candidate in group) {
        if (![candidate isEqualToString:normalizedCharacter]) {
            [baseGroup addObject:candidate];
        }
    }
    NSArray<NSString *> *rankedGroup = [self candidatesByApplyingLearningToGroup:baseGroup
                                                                       character:normalizedCharacter];
    NSMutableArray<NSString *> *result = [NSMutableArray arrayWithCapacity:MIN(rankedGroup.count, limit)];
    for (NSString *candidate in rankedGroup) {
        [result addObject:candidate];
        if (result.count >= limit) {
            break;
        }
    }
    return [result copy];
}

- (void)recordSelectionForCharacter:(NSString *)character candidate:(NSString *)candidate {
    if (!self.learningEnabled) {
        return;
    }
    NSString *normalizedCharacter = [self normalizedSingleCharacter:character];
    NSString *normalizedCandidate = [self normalizedSingleCharacter:candidate];
    if (normalizedCharacter.length == 0 || normalizedCandidate.length == 0) {
        return;
    }
    NSArray<NSString *> *group = [self candidateGroupForCharacter:normalizedCharacter];
    if (group.count < 2 || ![group containsObject:normalizedCandidate]) {
        return;
    }

    NSMutableDictionary<NSString *, NSNumber *> *scores = self.learnedCandidateScoresByCharacter[normalizedCharacter];
    if (!scores) {
        scores = [NSMutableDictionary dictionary];
        self.learnedCandidateScoresByCharacter[normalizedCharacter] = scores;
    }
    NSInteger nextScore = MIN([scores[normalizedCandidate] integerValue] + 1, NSIntegerMax - 1);
    scores[normalizedCandidate] = @(nextScore);
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)loadHomophonesAtURL:(NSURL *)resourceURL {
    if (!resourceURL) {
        return @{};
    }

    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfURL:resourceURL encoding:NSUTF8StringEncoding error:&error];
    if (text.length == 0) {
        return @{};
    }

    NSMutableDictionary<NSString *, NSArray<NSString *> *> *homophonesByCharacter = [NSMutableDictionary dictionary];
    NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedLine.length == 0 || [trimmedLine hasPrefix:@"#"]) {
            continue;
        }

        NSArray<NSString *> *columns = [trimmedLine componentsSeparatedByString:@"\t"];
        if (columns.count < 2) {
            continue;
        }

        NSArray<NSString *> *characters = [self candidateCharactersFromColumn:columns[1]];
        if (characters.count < 2) {
            continue;
        }

        for (NSString *character in characters) {
            homophonesByCharacter[character] = characters;
        }
    }
    return [homophonesByCharacter copy];
}

- (NSArray<NSString *> *)candidateGroupForCharacter:(NSString *)normalizedCharacter {
    return self.homophonesByCharacter[normalizedCharacter] ?: @[];
}

- (NSArray<NSString *> *)candidateCharactersFromColumn:(NSString *)column {
    NSMutableArray<NSString *> *characters = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSCharacterSet *ignoredCharacters = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    [column enumerateSubstringsInRange:NSMakeRange(0, column.length)
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substringRange;
        (void)enclosingRange;
        (void)stop;
        NSString *candidate = [self normalizedSingleCharacter:substring];
        if (candidate.length == 0 ||
            [candidate rangeOfCharacterFromSet:ignoredCharacters].location != NSNotFound ||
            [seen containsObject:candidate]) {
            return;
        }
        [seen addObject:candidate];
        [characters addObject:candidate];
    }];
    return [characters copy];
}

- (NSArray<NSString *> *)candidatesByApplyingLearningToGroup:(NSArray<NSString *> *)group
                                                   character:(NSString *)character {
    if (!self.learningEnabled || group.count < 2) {
        return group ?: @[];
    }
    NSDictionary<NSString *, NSNumber *> *scores = self.learnedCandidateScoresByCharacter[character] ?: @{};
    if (scores.count == 0) {
        return group ?: @[];
    }

    NSMutableDictionary<NSString *, NSNumber *> *indexByCandidate = [NSMutableDictionary dictionary];
    [group enumerateObjectsUsingBlock:^(NSString *candidate, NSUInteger index, BOOL *stop) {
        (void)stop;
        indexByCandidate[candidate] = @(index);
    }];

    return [group sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
        if ([left isEqualToString:character] && ![right isEqualToString:character]) {
            return NSOrderedAscending;
        }
        if ([right isEqualToString:character] && ![left isEqualToString:character]) {
            return NSOrderedDescending;
        }
        NSInteger leftScore = [scores[left] integerValue];
        NSInteger rightScore = [scores[right] integerValue];
        if (leftScore != rightScore) {
            return leftScore > rightScore ? NSOrderedAscending : NSOrderedDescending;
        }
        NSUInteger leftIndex = [indexByCandidate[left] unsignedIntegerValue];
        NSUInteger rightIndex = [indexByCandidate[right] unsignedIntegerValue];
        if (leftIndex == rightIndex) {
            return NSOrderedSame;
        }
        return leftIndex < rightIndex ? NSOrderedAscending : NSOrderedDescending;
    }];
}

- (NSString *)normalizedSingleCharacter:(NSString *)value {
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    if (trimmed.length == 0) {
        return @"";
    }
    NSRange range = [trimmed rangeOfComposedCharacterSequenceAtIndex:0];
    if (range.location != 0 || NSMaxRange(range) != trimmed.length) {
        return @"";
    }
    return [trimmed copy];
}

@end
