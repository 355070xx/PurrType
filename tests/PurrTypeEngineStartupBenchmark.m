#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <sys/resource.h>
#import "../src/PurrTypeEngine.h"

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static double CurrentTimeMilliseconds(void) {
    return [NSDate timeIntervalSinceReferenceDate] * 1000.0;
}

static uint64_t ResidentMemoryBytes(void) {
    mach_task_basic_info_data_t info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(),
                                     MACH_TASK_BASIC_INFO,
                                     (task_info_t)&info,
                                     &count);
    if (result != KERN_SUCCESS) {
        return 0;
    }
    return (uint64_t)info.resident_size;
}

static double MeasureMilliseconds(void (^block)(void)) {
    double start = CurrentTimeMilliseconds();
    block();
    return CurrentTimeMilliseconds() - start;
}

static NSString *MegabytesString(uint64_t bytes) {
    return [NSString stringWithFormat:@"%.1f MB", (double)bytes / (1024.0 * 1024.0)];
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *buildDirectory = [root stringByAppendingPathComponent:@"build"];
        [[NSFileManager defaultManager] createDirectoryAtPath:buildDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        NSString *cangjieDirectory = [root stringByAppendingPathComponent:@"third_party/rime-cangjie"];
        NSString *pinyinPath = [root stringByAppendingPathComponent:@"resources/pinyin_seed.tsv"];

        __block PurrTypeEngine *engine = nil;
        uint64_t baselineRSS = ResidentMemoryBytes();
        double initMS = MeasureMilliseconds(^{
            engine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                           pinyinPath:pinyinPath
                                                         learningPath:nil];
        });
        uint64_t initRSS = ResidentMemoryBytes();

        AssertTrue(engine.quickEntryCount > 10000, @"cold init loads Classic Sucheng");
        AssertTrue(engine.cangjieEntryCount == 0, @"cold init defers Cangjie dictionaries");
        AssertTrue(engine.pinyinEntryCount == 0, @"cold init defers Pinyin dictionaries");

        double suchengMS = MeasureMilliseconds(^{
            NSArray<MKCandidate *> *candidates = [engine candidatesForInput:@"hi"
                                                                      limit:9
                                                                       mode:MKInputModeSucheng];
            AssertTrue(candidates.count == 9, @"Classic Sucheng lookup works before other modes load");
        });
        uint64_t suchengRSS = ResidentMemoryBytes();
        AssertTrue(engine.cangjieEntryCount == 0, @"Classic Sucheng lookup keeps Cangjie deferred");
        AssertTrue(engine.pinyinEntryCount == 0, @"Classic Sucheng lookup keeps Pinyin deferred");

        double cangjieMS = MeasureMilliseconds(^{
            NSArray<MKCandidate *> *candidates = [engine candidatesForInput:@"hqi"
                                                                      limit:9
                                                                       mode:MKInputModeCangjie];
            AssertTrue(candidates.count > 0, @"Cangjie lookup loads Cangjie dictionaries");
        });
        uint64_t cangjieRSS = ResidentMemoryBytes();
        AssertTrue(engine.cangjieEntryCount > 70000, @"Cangjie dictionaries load on first Cangjie lookup");
        AssertTrue(engine.pinyinEntryCount == 0, @"Cangjie lookup keeps Pinyin deferred");

        double pinyinMS = MeasureMilliseconds(^{
            NSArray<MKCandidate *> *candidates = [engine candidatesForInput:@"ni"
                                                                      limit:9
                                                                       mode:MKInputModePinyin];
            AssertTrue(candidates.count > 0, @"Pinyin lookup loads Pinyin dictionaries");
        });
        uint64_t pinyinRSS = ResidentMemoryBytes();
        AssertTrue(engine.pinyinEntryCount > 10000, @"Pinyin dictionaries load on first Pinyin lookup");

        double classicAssociationMS = MeasureMilliseconds(^{
            NSArray<MKCandidate *> *candidates = [engine associatedCandidatesForText:@"你"
                                                                               limit:20
                                                                                mode:MKInputModeSucheng];
            AssertTrue(candidates.count > 0 &&
                       [candidates.firstObject.text isEqualToString:@"好"],
                       @"Classic Sucheng fixed associations load on first association lookup");
        });
        uint64_t classicAssociationRSS = ResidentMemoryBytes();
        AssertTrue(classicAssociationMS < 250.0, @"Classic association first lookup uses the generated index instead of parsing the TSV");

        double smartSuchengMS = MeasureMilliseconds(^{
            NSArray<MKCandidate *> *candidates = [engine candidatesForInput:@"hionaomjoo"
                                                                      limit:9
                                                                       mode:MKInputModeSmartSucheng];
            AssertTrue(candidates.count > 0, @"New Sucheng phrase lookup works after lazy load");
        });
        uint64_t smartSuchengRSS = ResidentMemoryBytes();

        NSString *report = [NSString stringWithFormat:
            @"# PurrType Candidate Index Performance Baseline\n\n"
             "Generated by `PurrTypeEngineStartupBenchmark` from the current runtime tree.\n\n"
             "Benchmark sequence: cold init, Classic Sucheng, Cangjie, Pinyin, Classic association, New Sucheng phrase.\n\n"
             "| Phase | Time | RSS |\n"
             "| --- | ---: | ---: |\n"
             "| Baseline process | n/a | %@ |\n"
             "| Cold init | %.2f ms | %@ |\n"
             "| Classic Sucheng first lookup | %.2f ms | %@ |\n"
             "| Cangjie first lookup | %.2f ms | %@ |\n"
             "| Pinyin first lookup | %.2f ms | %@ |\n"
             "| Classic association first lookup | %.2f ms | %@ |\n"
             "| New Sucheng phrase first lookup | %.2f ms | %@ |\n\n"
             "Loaded entry counts after all phases:\n\n"
             "- Quick: %lu\n"
             "- Cangjie: %lu\n"
             "- Pinyin: %lu\n",
             MegabytesString(baselineRSS),
             initMS, MegabytesString(initRSS),
             suchengMS, MegabytesString(suchengRSS),
             cangjieMS, MegabytesString(cangjieRSS),
             pinyinMS, MegabytesString(pinyinRSS),
             classicAssociationMS, MegabytesString(classicAssociationRSS),
             smartSuchengMS, MegabytesString(smartSuchengRSS),
             (unsigned long)engine.quickEntryCount,
             (unsigned long)engine.cangjieEntryCount,
             (unsigned long)engine.pinyinEntryCount];
        NSString *reportPath = [buildDirectory stringByAppendingPathComponent:@"engine-startup-report.md"];
        [report writeToFile:reportPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

        NSLog(@"PASS: PurrTypeEngineStartupBenchmark %.2f ms init, report %@", initMS, reportPath);
    }

    return 0;
}
