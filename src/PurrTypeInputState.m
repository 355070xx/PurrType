#import "PurrTypeInputState.h"

@interface PurrTypeInputState ()

@property(nonatomic, strong, readwrite) NSMutableString *buffer;

@end

@implementation PurrTypeInputState

- (instancetype)init {
    self = [super init];
    if (self) {
        _buffer = [NSMutableString string];
    }
    return self;
}

+ (BOOL)isRawEnglishContinuationString:(NSString *)string {
    if (string.length != 1) {
        return NO;
    }

    unichar character = [string characterAtIndex:0];
    if ((character >= 'a' && character <= 'z') ||
        (character >= 'A' && character <= 'Z') ||
        (character >= '0' && character <= '9')) {
        return YES;
    }

    return character >= 33 && character <= 126;
}

- (void)appendCodeText:(NSString *)text {
    if (text.length == 0) {
        return;
    }

    self.associationModeActive = NO;
    [self.buffer appendString:text];
}

- (void)appendRawEnglishText:(NSString *)text {
    if (text.length == 0) {
        return;
    }

    self.rawEnglishModeActive = YES;
    self.associationModeActive = NO;
    [self.buffer appendString:text];
}

- (void)deleteBackward {
    if (self.buffer.length == 0) {
        return;
    }

    [self.buffer deleteCharactersInRange:NSMakeRange(self.buffer.length - 1, 1)];
    if (self.buffer.length == 0) {
        self.rawEnglishModeActive = NO;
        self.associationModeActive = NO;
    }
}

- (void)resetComposition {
    [self.buffer setString:@""];
    self.associationModeActive = NO;
    self.rawEnglishModeActive = NO;
}

- (void)clearAssociations {
    self.associationModeActive = NO;
    self.rawEnglishModeActive = NO;
}

@end
