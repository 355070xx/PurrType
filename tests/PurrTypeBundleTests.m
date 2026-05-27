#import <Foundation/Foundation.h>

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSDictionary *PlistAtPath(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    AssertTrue(data != nil, [NSString stringWithFormat:@"plist exists: %@", path]);
    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:nil
                                                           error:&error];
    AssertTrue([plist isKindOfClass:[NSDictionary class]],
               [NSString stringWithFormat:@"plist is dictionary: %@ %@", path, error.localizedDescription ?: @""]);
    return (NSDictionary *)plist;
}

static NSString *FileTextAtPath(NSString *path) {
    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    AssertTrue(text.length > 0, [NSString stringWithFormat:@"file is readable: %@ %@", path, error.localizedDescription ?: @""]);
    return text;
}

static NSString *SubstringBetween(NSString *text, NSString *start, NSString *end) {
    NSRange startRange = [text rangeOfString:start];
    AssertTrue(startRange.location != NSNotFound, [NSString stringWithFormat:@"section start exists: %@", start]);
    NSRange searchRange = NSMakeRange(NSMaxRange(startRange), text.length - NSMaxRange(startRange));
    NSRange endRange = [text rangeOfString:end options:0 range:searchRange];
    AssertTrue(endRange.location != NSNotFound, [NSString stringWithFormat:@"section end exists: %@", end]);
    return [text substringWithRange:NSMakeRange(startRange.location, endRange.location - startRange.location)];
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *root = [fileManager currentDirectoryPath];
        NSDictionary *inputPlist = PlistAtPath([root stringByAppendingPathComponent:@"resources/Info.plist"]);
        NSDictionary *preferencesPlist = PlistAtPath([root stringByAppendingPathComponent:@"resources/PurrTypePreferencesInfo.plist"]);

        NSString *inputVersion = inputPlist[@"CFBundleShortVersionString"];
        NSString *preferencesVersion = preferencesPlist[@"CFBundleShortVersionString"];
        AssertTrue([inputVersion isEqualToString:preferencesVersion], @"input method and preferences versions match");
        AssertTrue([inputPlist[@"CFBundleDisplayName"] isEqualToString:@"PurrType"], @"public input source uses the release display name");
        AssertTrue([preferencesPlist[@"CFBundleDisplayName"] isEqualToString:@"PurrType Preferences"], @"preferences helper uses the release display name");
        AssertTrue([inputPlist[@"CFBundleExecutable"] isEqualToString:@"PurrType"], @"public input method uses the release executable name");
        AssertTrue([preferencesPlist[@"CFBundleExecutable"] isEqualToString:@"PurrTypePreferences"], @"preferences helper uses the release executable name");
        AssertTrue([preferencesPlist[@"CFBundlePackageType"] isEqualToString:@"APPL"], @"preferences helper is an app bundle");
        AssertTrue(preferencesPlist[@"LSUIElement"] == nil, @"preferences helper is visible in Cmd+Tab");
        AssertTrue(preferencesPlist[@"LSBackgroundOnly"] == nil, @"preferences helper is not background-only");
        AssertTrue([inputPlist[@"CFBundleIdentifier"] isEqualToString:@"org.purrtype.inputmethod.PurrTypeUnified"], @"public input method uses the release bundle id");
        AssertTrue([inputPlist[@"TISInputSourceID"] isEqualToString:@"org.purrtype.inputmethod.PurrTypeUnified"], @"input method exposes one macOS input source");
        AssertTrue([inputPlist[@"InputMethodConnectionName"] isEqualToString:@"PurrTypeUnified_Connection"], @"input method uses a stable IMK connection name");
        AssertTrue(inputPlist[@"ComponentInputModeDict"] == nil, @"input method keeps mode switching internal instead of declaring mode-level input sources");

        NSString *preinstall = FileTextAtPath([root stringByAppendingPathComponent:@"packaging/scripts/preinstall"]);
        AssertTrue([preinstall containsString:@"pkill -x PurrType"], @"installer stops the input method process");
        AssertTrue([preinstall containsString:@"pkill -x PurrTypePreferences"], @"installer stops the preferences helper");
        AssertTrue([preinstall containsString:@"/Library/Input Methods/PurrTypeIM.app"], @"installer removes the old public app bundle before replacing it");
        AssertTrue([preinstall containsString:@"org.purrtype.inputmethod.PurrTypeUnified.pkg"], @"installer forgets the old public package receipt before replacing it");
        AssertTrue([preinstall containsString:@"-gc"], @"installer preinstall compacts LaunchServices after unregistering stale bundles");
        NSString *postinstall = FileTextAtPath([root stringByAppendingPathComponent:@"packaging/scripts/postinstall"]);
        AssertTrue([postinstall containsString:@"APP=\"/Library/Input Methods/PurrTypeIM.app\""], @"installer registers the system-level input method bundle");
        AssertTrue([postinstall containsString:@"MISPLACED_APP=\"/Library/Application Support/PurrType/PurrTypeIM.app\""], @"installer cleans the old misplaced Application Support input method bundle");
        AssertTrue([postinstall containsString:@"Contents/MacOS/PurrType"], @"installer registers the public executable");
        AssertTrue([postinstall containsString:@"--register-input-source"], @"installer asks the app to register its input source");
        AssertTrue(![postinstall containsString:@"--enable-input-source"], @"package installer leaves input source enabling to the user");
        AssertTrue([postinstall containsString:@"-gc"], @"installer postinstall compacts LaunchServices after registering the valid bundle");
        AssertTrue([postinstall containsString:@"pkill -x TextInputMenuAgent"], @"installer refreshes the macOS input menu cache");
        NSString *localInstall = FileTextAtPath([root stringByAppendingPathComponent:@"scripts/install-local.sh"]);
        AssertTrue([localInstall containsString:@"pkill -x \"$EXECUTABLE_NAME\""], @"local install stops the PurrType process before replacing bundles");
        AssertTrue([localInstall containsString:@"pkill -x TextInputMenuAgent"], @"local install refreshes the macOS input menu icon cache");
        AssertTrue([localInstall containsString:@"-gc"], @"local install compacts LaunchServices after replacing bundles");
        AssertTrue([localInstall containsString:@"--enable-input-source"], @"local install enables PurrType for the current user after registration");
        AssertTrue([localInstall containsString:@"/Library/Application Support/PurrType/PurrTypeIM.app"], @"local install unregisters the old misplaced Application Support input method bundle");
        AssertTrue(![localInstall containsString:@"PurrType.inputmethod"], @"local install does not delete legacy bundle names outside the known migration set");
        NSString *mainSource = FileTextAtPath([root stringByAppendingPathComponent:@"src/main.m"]);
        AssertTrue([mainSource containsString:@"kTISPropertyInputSourceType"], @"TIS inspect prints input source type for grey-menu diagnostics");
        AssertTrue([mainSource containsString:@"kTISPropertyInputSourceCategory"], @"TIS inspect prints input source category for grey-menu diagnostics");
        AssertTrue([mainSource containsString:@"kTISPropertyInputSourceIsASCIICapable"], @"TIS inspect prints ASCII capability for grey-menu diagnostics");
        AssertTrue([mainSource containsString:@"TISCreateInputSourceList((__bridge CFDictionaryRef)filter, includeAllInstalled)"], @"TIS lookup can distinguish enabled sources from installed-only sources");
        AssertTrue([mainSource containsString:@"BundleIsInInputMethodsDirectory"], @"input source registration is limited to valid Input Methods directories");
        AssertTrue([mainSource containsString:@"refusing to register input source from invalid location"], @"development build copies are refused before TIS registration");
        NSString *systemUninstall = FileTextAtPath([root stringByAppendingPathComponent:@"scripts/uninstall-system.sh"]);
        AssertTrue([systemUninstall containsString:@"/Library/Application Support/PurrType/PurrTypeIM.app"], @"system uninstall removes the old misplaced Application Support input method bundle");
        AssertTrue([systemUninstall containsString:@"/Library/Input Methods/PurrTypeIM.app"], @"system uninstall removes the public app bundle");
        AssertTrue([systemUninstall containsString:@"-gc"], @"system uninstall compacts LaunchServices after unregistering removed bundles");
        NSString *dmgUninstall = FileTextAtPath([root stringByAppendingPathComponent:@"packaging/Uninstall-PurrType.command"]);
        AssertTrue([dmgUninstall containsString:@"/Library/Input Methods/PurrTypeIM.app"], @"DMG uninstall removes the system-level PurrType app bundle");
        AssertTrue([dmgUninstall containsString:@"/Library/Application Support/PurrType/PurrTypeIM.app"], @"DMG uninstall removes the old misplaced Application Support input method bundle");
        AssertTrue([dmgUninstall containsString:@"/Library/Input Methods/PurrTypeIM.app"], @"DMG uninstall removes the public app bundle");
        AssertTrue([dmgUninstall containsString:@"-gc"], @"DMG uninstall compacts LaunchServices after unregistering removed bundles");
        NSString *dmgUninstallPackage = FileTextAtPath([root stringByAppendingPathComponent:@"packaging/uninstall-scripts/postinstall"]);
        AssertTrue([dmgUninstallPackage containsString:@"/Library/Input Methods/PurrTypeIM.app"], @"DMG uninstall package removes the system-level PurrType app bundle");
        AssertTrue([dmgUninstallPackage containsString:@"/Library/Application Support/PurrType/PurrTypeIM.app"], @"DMG uninstall package removes the old misplaced Application Support input method bundle");
        AssertTrue([dmgUninstallPackage containsString:@"/Library/Input Methods/PurrTypeIM.app"], @"DMG uninstall package removes the public app bundle");
        AssertTrue([dmgUninstallPackage containsString:@"pkgutil --forget"], @"DMG uninstall package forgets PurrType package receipts");
        AssertTrue(![dmgUninstallPackage containsString:@"$USER_HOME/Library/Application Support/PurrType"], @"DMG uninstall package preserves user learning data");
        AssertTrue(![dmgUninstallPackage containsString:@"$USER_HOME/Library/Preferences/org.purrtype.inputmethod.PurrTypeUnified.plist"], @"DMG uninstall package preserves user preferences");
        NSString *repairInputSource = FileTextAtPath([root stringByAppendingPathComponent:@"scripts/repair-installed-input-source.sh"]);
        AssertTrue([repairInputSource containsString:@"--select-input-source"], @"repair script can explicitly select PurrType when requested");
        AssertTrue([repairInputSource containsString:@"APP=\"/Library/Input Methods/PurrTypeIM.app\""], @"repair script targets the public app bundle");
        AssertTrue([repairInputSource containsString:@"pkill -x TextInputMenuAgent"], @"repair script refreshes the macOS input menu cache");
        NSString *licenseAuditScript = FileTextAtPath([root stringByAppendingPathComponent:@"scripts/audit-license-notices.sh"]);
        AssertTrue(![licenseAuditScript containsString:@"reject_abs_text \"$UNINSTALL_SCRIPT\" \"/Library/Input Methods/PurrTypeIM.app\""], @"license audit must not reject the uninstall package path it requires");
        NSString *fundingConfig = FileTextAtPath([root stringByAppendingPathComponent:@".github/FUNDING.yml"]);
        AssertTrue(![fundingConfig containsString:@"mrz.final"], @"public funding config must not expose placeholder media filenames");

        NSString *packageReadme = FileTextAtPath([root stringByAppendingPathComponent:@"packaging/README.txt"]);
        AssertTrue([packageReadme containsString:@"Install PurrType.pkg"], @"DMG README has a plain-language install package name");
        AssertTrue([packageReadme containsString:@"Uninstall PurrType.pkg"], @"DMG README has a plain-language uninstall package name");
        AssertTrue(![packageReadme containsString:@"Uninstall-PurrType.command"], @"DMG README does not expose a command script as the normal uninstall path");
        AssertTrue(![packageReadme containsString:@"This DMG also includes"], @"DMG README stays focused on install and uninstall");
        AssertTrue([packageReadme containsString:@"No Terminal commands are required"], @"DMG README states normal users do not need Terminal");
        AssertTrue([packageReadme containsString:@"Install Guide.html"], @"DMG README points blocked users to the visual install guide");
        AssertTrue([packageReadme containsString:@"Do not click Move to Bin"], @"DMG README tells users not to discard the installer after Gatekeeper warning");
        AssertTrue([packageReadme containsString:@"Traditional Chinese and English"], @"DMG README mentions the bilingual install guide tabs");
        AssertTrue([packageReadme containsString:@"/Library/Input Methods/PurrTypeIM.app"], @"DMG README documents system-level install location");
        AssertTrue([packageReadme containsString:@"does not enable or select it"], @"DMG README documents manual input source enabling");

        NSString *makefile = FileTextAtPath([root stringByAppendingPathComponent:@"Makefile"]);
        NSString *installGuide = FileTextAtPath([root stringByAppendingPathComponent:@"docs/INSTALL_GUIDE.md"]);
        NSString *dmgInstallGuide = FileTextAtPath([root stringByAppendingPathComponent:@"packaging/INSTALL_GUIDE.html"]);
        AssertTrue([installGuide containsString:@"繁體中文"], @"install guide includes Traditional Chinese text");
        AssertTrue([installGuide containsString:@"加入 PurrType"], @"install guide includes Traditional Chinese add-input-source instructions");
        AssertTrue([installGuide containsString:@"English"], @"install guide includes English text");
        AssertTrue([installGuide containsString:@"Move to Bin"], @"install guide covers the Gatekeeper warning shown to unsigned package users");
        AssertTrue([installGuide containsString:@"Privacy & Security"], @"install guide explains where to allow the blocked installer");
        AssertTrue([installGuide containsString:@"assets/install-guide/step1-gatekeeper-done.jpg"], @"install guide includes the Gatekeeper warning screenshot");
        AssertTrue([installGuide containsString:@"assets/install-guide/step5-add-purrtype.jpg"], @"install guide includes the PurrType input source screenshot");
        AssertTrue([dmgInstallGuide containsString:@"role=\"tablist\""], @"DMG install guide exposes language tabs");
        AssertTrue([dmgInstallGuide containsString:@"繁體中文"], @"DMG install guide includes a Traditional Chinese tab");
        AssertTrue([dmgInstallGuide containsString:@"English"], @"DMG install guide includes an English tab");
        AssertTrue([dmgInstallGuide containsString:@"加入 PurrType"], @"DMG install guide includes Traditional Chinese steps");
        AssertTrue([dmgInstallGuide containsString:@"Open Anyway"], @"DMG install guide explains the Privacy & Security allow flow");
        AssertTrue([dmgInstallGuide containsString:@"Install PurrType.pkg"], @"DMG install guide names the installer package");
        AssertTrue([dmgInstallGuide containsString:@".install-guide-assets/step1-gatekeeper-done.jpg"], @"DMG install guide references copied local screenshots");
        AssertTrue([dmgInstallGuide containsString:@".install-guide-assets/step5-add-purrtype.jpg"], @"DMG install guide references the final add-input-source screenshot");
        AssertTrue([makefile containsString:@"packaging/INSTALL_GUIDE.html"], @"package target depends on the visual install guide");
        AssertTrue([makefile containsString:@"INSTALL_GUIDE_IMAGES"], @"package target tracks install guide screenshots");
        AssertTrue([makefile containsString:@"$(INSTALL_GUIDE_DMG_ASSET_DIR)/step1-gatekeeper-done.jpg"], @"package smoke verifies copied install guide screenshots");
        AssertTrue([makefile containsString:@"$(DMGROOT_DIR)/Install Guide.html"], @"DMG root includes the visual install guide");
        AssertTrue([makefile containsString:@"shasum -a 256 \"PurrType-$(VERSION).dmg\""], @"public checksum file verifies the downloadable DMG by basename");
        AssertTrue(![makefile containsString:@"shasum -a 256 \"$(PKG_PATH)\" \"$(UNINSTALL_PKG_PATH)\" \"$(DMG_PATH)\""], @"public checksum file does not reference unpublished package paths");
        NSString *systemComponent = FileTextAtPath([root stringByAppendingPathComponent:@"packaging/component.plist"]);
        NSString *localComponent = FileTextAtPath([root stringByAppendingPathComponent:@"packaging/component-local.plist"]);
        AssertTrue([systemComponent containsString:@"Library/Input Methods/PurrTypeIM.app"], @"package component plist keeps the system-wide Input Methods path");
        AssertTrue([localComponent containsString:@"Library/Input Methods/PurrTypeIM.app"], @"local component plist keeps the input method in a valid Input Methods path");
        AssertTrue(![localComponent containsString:@"Library/Application Support/PurrType/PurrTypeIM.app"], @"local component plist does not install an input method into Application Support");
        AssertTrue([makefile containsString:@"resources/traditional_compatibility.tsv"], @"build depends on Traditional compatibility table");
        AssertTrue([makefile containsString:@"cp resources/traditional_compatibility.tsv"], @"bundle copies Traditional compatibility table");
        AssertTrue([makefile containsString:@"resources/association_generated.tsv"], @"build depends on generated association source table");
        AssertTrue([makefile containsString:@"resources/association_generated.index"], @"build creates generated association read-only index");
        AssertTrue([makefile containsString:@"cp \"$(ASSOCIATION_GENERATED_INDEX)\""], @"bundle copies generated association index");
        AssertTrue([makefile containsString:@"scripts/index-candidate-tables.rb"], @"build has a candidate table indexer");
        AssertTrue([makefile containsString:@"CANDIDATE_INDEXES"], @"build groups generated candidate table indexes");
        AssertTrue([makefile containsString:@"cp $(CANDIDATE_INDEXES) \"$(RESOURCES_DIR)/CandidateTables/\""], @"bundle copies generated candidate table indexes");
        AssertTrue([makefile containsString:@"scripts/generate-icon.sh"], @"bundle build generates the app icon from the source PNG");
        AssertTrue([makefile containsString:@"PurrType.icns"], @"bundle build generates the app icon resource");
        AssertTrue(![makefile containsString:@"generate-icon.sh \"$(RESOURCES_DIR)/PurrType_sucheng.icns\""], @"bundle build reuses the app icon instead of generating a duplicate Sucheng menu icon");
        AssertTrue(![makefile containsString:@"generate-icon.sh \"$(RESOURCES_DIR)/PurrType_new.icns\""], @"bundle build reuses the app icon instead of generating a duplicate New Sucheng menu icon");
        AssertTrue(![makefile containsString:@"generate-icon.sh \"$(RESOURCES_DIR)/PurrType_cangjie.icns\""], @"bundle build reuses the app icon instead of generating a duplicate Cangjie menu icon");
        AssertTrue(![makefile containsString:@"generate-icon.sh \"$(RESOURCES_DIR)/PurrType_pinyin.icns\""], @"bundle build reuses the app icon instead of generating a duplicate Pinyin menu icon");
        AssertTrue([makefile containsString:@"Contents/Resources/PurrType.icns"], @"package smoke keeps the generated app icon");
        AssertTrue([makefile containsString:@"$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PurrType.icns"], @"package smoke keeps the generated preferences icon");
        NSString *generateIcon = FileTextAtPath([root stringByAppendingPathComponent:@"scripts/generate-icon.sh"]);
        AssertTrue([generateIcon containsString:@"resources/PurrType.png"], @"icon generator uses the checked-in source PNG");
        AssertTrue([generateIcon containsString:@"/usr/bin/iconutil"], @"icon generator uses an absolute iconutil path");
        AssertTrue([generateIcon containsString:@"PURRTYPE_ICON_DRAW_SIZE"], @"icon generator applies transparent padding for tiny menu-bar icons");
        AssertTrue([generateIcon containsString:@"scripts/pad-png-alpha.py"], @"icon generator pads RGBA PNG sources before iconset downscaling");
        AssertTrue([generateIcon containsString:@"/bin/sleep 1"] && [generateIcon containsString:@"/usr/bin/iconutil -c icns"], @"icon generator retries iconutil after transient iconset validation failures");
        AssertTrue([generateIcon containsString:@"scripts/write-icns.py"], @"icon generator has a deterministic ICNS writer fallback");
        AssertTrue([generateIcon containsString:@"BASE_PPM"], @"icon generator keeps the legacy fallback when no source PNG is checked in");
        NSString *writeIcns = FileTextAtPath([root stringByAppendingPathComponent:@"scripts/write-icns.py"]);
        AssertTrue([writeIcns containsString:@"b\"icns\""], @"ICNS fallback writes the ICNS file header");
        AssertTrue([writeIcns containsString:@"b\"ic10\""], @"ICNS fallback includes the 1024px icon entry");
        NSString *englishInfoPlistStrings = FileTextAtPath([root stringByAppendingPathComponent:@"resources/en.lproj/InfoPlist.strings"]);
        AssertTrue([englishInfoPlistStrings containsString:@"\"org.purrtype.inputmethod.PurrTypeUnified\" = \"PurrType\";"], @"English InfoPlist strings expose the public input source name");
        AssertTrue(![englishInfoPlistStrings containsString:@"org.purrtype.inputmethod.PurrTypeUnified.NewSucheng"], @"English InfoPlist strings do not expose New Sucheng as a separate source");
        AssertTrue(![englishInfoPlistStrings containsString:@"PurrType - New Sucheng"], @"English InfoPlist strings keep New Sucheng internal");
        NSString *traditionalInfoPlistStrings = FileTextAtPath([root stringByAppendingPathComponent:@"resources/zh-Hant.lproj/InfoPlist.strings"]);
        AssertTrue(![traditionalInfoPlistStrings containsString:@"org.purrtype.inputmethod.PurrTypeUnified.NewSucheng"], @"Traditional Chinese InfoPlist strings do not expose New Sucheng as a separate source");
        AssertTrue(![traditionalInfoPlistStrings containsString:@"PurrType - 新速成"], @"Traditional Chinese InfoPlist strings keep New Sucheng internal");
        AssertTrue([makefile containsString:@"$(CANGJIE_CANDIDATE_INDEX):"], @"build converts Cangjie source tables into a read-only index");
        AssertTrue(![makefile containsString:@"cp third_party/rime-cangjie/cangjie5.base.dict.yaml"], @"bundle does not copy runtime Rime Cangjie YAML dictionaries");
        AssertTrue(![makefile containsString:@"cangjie5*.yaml"], @"bundle build does not wildcard-copy unused Rime schema files");
        AssertTrue([makefile containsString:@"third_party/rime-pinyin/luna_pinyin.dict.yaml"], @"build depends on full Rime pinyin dictionary");
        AssertTrue([makefile containsString:@"resources/pinyin_phrases.tsv"], @"build depends on the curated Traditional pinyin phrase seeds");
        AssertTrue([makefile containsString:@"$(PINYIN_CANDIDATE_INDEX):"], @"build converts Rime pinyin into a read-only index");
        AssertTrue(![makefile containsString:@"cp third_party/rime-pinyin/luna_pinyin.dict.yaml"], @"bundle does not copy runtime Rime pinyin YAML dictionary");
        AssertTrue(![makefile containsString:@"cp resources/pinyin_seed.tsv"], @"bundle does not copy runtime pinyin seed TSV");
        AssertTrue(![makefile containsString:@"cp resources/pinyin_phrases.tsv"], @"bundle does not copy runtime pinyin phrase TSV");
        AssertTrue([makefile containsString:@".PHONY: all build clean-bundle"], @"clean-bundle is a phony build prerequisite");
        AssertTrue([makefile containsString:@"$(MACOS_DIR)/$(EXECUTABLE_NAME): clean-bundle"], @"bundle executable target always starts from a clean app tree");
        AssertTrue([makefile containsString:@"rm -rf \"$(BUNDLE_DIR)\""], @"bundle build starts from a clean app tree");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/RimeCangjie/cangjie5.dict.yaml\""], @"package smoke rejects unused Rime aggregate dictionary metadata");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/RimeCangjie/cangjie5_express.schema.yaml\""], @"package smoke rejects unused Rime schema files");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/RimePinyin/luna_pinyin.dict.yaml\""], @"package smoke rejects runtime Rime pinyin YAML");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/pinyin_seed.tsv\""], @"package smoke rejects runtime pinyin seed TSV");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/pinyin_phrases.tsv\""], @"package smoke rejects runtime pinyin phrase TSV");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/CINTables\""], @"package smoke rejects stale legacy CIN resource directories");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/ranking_overrides.tsv\""], @"package smoke rejects stale ranking override resources");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/legacy_sucheng_overrides.tsv\""], @"package smoke rejects stale legacy override resources");
        AssertTrue([makefile containsString:@"third_party/ibus-table-chinese/cangjie5.txt"], @"build depends on IBus Cangjie5 table");
        AssertTrue([makefile containsString:@"CandidateTables/cangjie5.index"], @"package smoke keeps indexed IBus/Rime Cangjie candidates");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/IBusTableChinese/cangjie5.txt\""], @"package smoke rejects runtime IBus Cangjie text table");
        AssertTrue([makefile containsString:@"third_party/hkscs/HKSCS2016.json"], @"build depends on HKSCS overlay data");
        AssertTrue([makefile containsString:@"$(RESOURCES_DIR)/HKSCS"], @"bundle copies HKSCS overlay resources");
        AssertTrue([makefile containsString:@"Resources/HKSCS/HKSCS2016.json"], @"package smoke keeps HKSCS overlay data");
        AssertTrue([makefile containsString:@"Resources/HKSCS/TERMS.md"], @"package smoke keeps HKSCS attribution terms reference");
        AssertTrue([makefile containsString:@"audit-hkscs-coverage"], @"Makefile exposes HKSCS coverage audit target");
        AssertTrue([makefile containsString:@"COPYFILE_DISABLE=1 ditto --norsrc --noextattr"], @"package copy avoids AppleDouble metadata files");
        AssertTrue([makefile containsString:@"COPYFILE_DISABLE=1 pkgbuild --root"], @"pkgbuild runs with copyfile metadata serialization disabled");
        AssertTrue([makefile containsString:@"xattr -cr \"$(PKGROOT_DIR)\""], @"package strips extended attributes before pkgbuild can serialize them as AppleDouble payload files");
        AssertTrue([makefile containsString:@"xattr -dr com.apple.provenance \"$(PKGROOT_DIR)\""], @"package strips provenance metadata before pkgbuild can serialize it as AppleDouble payload files");
        AssertTrue([makefile containsString:@"find \"$(PKGROOT_DIR)\" -name '._*' -exec rm -f {} +"], @"package removes AppleDouble sidecar files before pkgbuild");
        AssertTrue([makefile containsString:@"test -z \"$$(find \"$(PKGROOT_DIR)\" -name '._*' -print -quit)\""], @"package smoke rejects source AppleDouble sidecar files before pkgbuild");
        AssertTrue([makefile containsString:@"third_party/ibus-table-chinese/quick-classic.txt"], @"build depends on Sucheng Quick Classic table");
        AssertTrue([makefile containsString:@"CandidateTables/quick-classic.index"], @"package smoke keeps indexed Sucheng Quick Classic candidates");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/IBusTableChinese/quick-classic.txt\""], @"package smoke rejects runtime Sucheng text table");
        AssertTrue([makefile containsString:@"update-association-seeds"], @"Makefile exposes generated association seed refresh target");
        AssertTrue([makefile containsString:@"resources/en.lproj/Localizable.strings"], @"build depends on English preferences localization");
        AssertTrue([makefile containsString:@"resources/zh-Hant.lproj/Localizable.strings"], @"build depends on Traditional Chinese preferences localization");
        AssertTrue([makefile containsString:@"$(PREFERENCES_CONTENTS_DIR)/Resources/en.lproj/Localizable.strings"], @"preferences helper bundles English localization");
        AssertTrue([makefile containsString:@"$(PREFERENCES_CONTENTS_DIR)/Resources/zh-Hant.lproj/Localizable.strings"], @"preferences helper bundles Traditional Chinese localization");
        AssertTrue([makefile containsString:@"PREFERENCE_COVER_RESOURCES"], @"build centralizes preference cover resources");
        AssertTrue([makefile containsString:@"resources/PreferenceCovers/pref_cover_general.png"], @"build depends on General full cover asset");
        AssertTrue([makefile containsString:@"resources/PreferenceCovers/pref_cover_privacy_learning.png"], @"build depends on Privacy & Learning full cover asset");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/PreferenceCovers/pref_cover_general_banner.png\""], @"package smoke rejects main-app banner cover assets");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_general_banner.png\""], @"package smoke rejects preferences-helper banner cover assets");
        AssertTrue(![makefile containsString:@"PREFERENCE_COVER_RESOURCES := resources/PreferenceCovers/pref_cover_general_banner.png"], @"build does not include banner cover assets in preference cover resources");
        AssertTrue([makefile containsString:@"$(PREFERENCES_CONTENTS_DIR)/Resources/PreferenceCovers"], @"preferences helper bundles preference cover assets");
        AssertTrue([makefile containsString:@"Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_general.png"], @"package smoke keeps General full cover assets in the preferences helper");
        AssertTrue([makefile containsString:@"test ! -e \"$(PACKAGE_SMOKE_APP)/Contents/Resources/PreferenceCovers\""], @"package smoke rejects duplicate main-app preference cover assets");
        AssertTrue([makefile containsString:@"Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_about.png"], @"package smoke keeps preferences helper full cover assets");
        AssertTrue([makefile containsString:@"src/PurrTypeCandidatePanel.m"], @"build includes custom candidate panel");
        AssertTrue([makefile containsString:@"src/PurrTypeQuickPhraseStore.m"], @"build includes public Quick Phrases store");
        AssertTrue([makefile containsString:@"src/PurrTypeBackupStore.m"], @"build includes public basic backup store");
        AssertTrue([makefile containsString:@"SYSTEM_INPUT_METHOD_APP := /Library/Input Methods/$(BUNDLE_NAME)"], @"diagnostic targets know the system input method location");
        AssertTrue([makefile containsString:@"USER_INPUT_METHOD_APP := $(HOME)/Library/Input Methods/$(BUNDLE_NAME)"], @"diagnostic targets know the user input method location");
        AssertTrue([makefile containsString:@"RUN_PURRTYPE_APP"], @"diagnostic targets use a shared installed-app launcher");
        AssertTrue([makefile containsString:@"RUN_INSTALLED_PURRTYPE_APP"], @"enable/select diagnostics refuse to register development build copies");
        AssertTrue([makefile containsString:@"repair-input-source"], @"Makefile exposes input-source repair targets");
        AssertTrue([makefile containsString:@"cd \"$(BUILD_DIR)\""], @"build resolves the development app copy to an absolute path before LaunchServices unregister");
        AssertTrue([makefile containsString:@"cd \"$(PKGROOT_DIR)/Library/Input Methods\""], @"package resolves pkgroot app copies to absolute paths before LaunchServices unregister");
        AssertTrue([makefile containsString:@"$(PACKAGE_SMOKE_DIR)/expanded/Payload/Library/Input Methods"] &&
                   [makefile containsString:@"smoke_app=\"$$(cd"],
                   @"package smoke resolves expanded payload app copies to absolute paths before LaunchServices unregister");
        AssertTrue([makefile containsString:@"\"$(LSREGISTER)\" -gc"], @"build and package cleanup compacts LaunchServices after unregistering temporary bundle paths");
        AssertTrue(![makefile containsString:@"tis-inspect: build"], @"TIS inspect does not run the build artifact when an installed app exists");
        AssertTrue(![makefile containsString:@"enable: build"], @"TIS enable does not run the build artifact when an installed app exists");
        AssertTrue(![makefile containsString:@"select: build"], @"TIS select does not run the build artifact when an installed app exists");
        AssertTrue([makefile containsString:@"audit-full-bible"], @"Makefile exposes full Bible audit target");
        AssertTrue([makefile containsString:@"audit-sucheng-ranking"], @"Makefile exposes Sucheng ranking audit target");
        AssertTrue([makefile containsString:@"dump-sucheng-pages"], @"Makefile exposes Sucheng page dump target");
        AssertTrue([makefile containsString:@"update-sucheng-snapshot"], @"Makefile exposes Sucheng snapshot refresh target");
        AssertTrue([makefile containsString:@"release-artifacts"], @"Makefile exposes unsigned release artifact target");
        AssertTrue([makefile containsString:@"release-signed"], @"Makefile exposes signed and notarized release target");
        AssertTrue([makefile containsString:@"DEVELOPER_ID_APPLICATION_IDENTITY"], @"Makefile requires explicit Developer ID Application identity");
        AssertTrue([makefile containsString:@"DEVELOPER_ID_INSTALLER_IDENTITY"], @"Makefile requires explicit Developer ID Installer identity");
        AssertTrue([makefile containsString:@"notarytool submit"], @"Makefile submits signed DMG to Apple notarization");
        AssertTrue([makefile containsString:@"stapler staple"], @"Makefile staples notarization ticket to signed DMG");
        AssertTrue([makefile containsString:@"scripts/write-release-provenance.rb"], @"Makefile writes release provenance metadata");

        NSString *troubleshooting = FileTextAtPath([root stringByAppendingPathComponent:@"docs/TROUBLESHOOTING.md"]);
        AssertTrue([troubleshooting containsString:@"PurrType Is Grey In Text Fields"], @"troubleshooting documents the active-text-field grey menu state");
        AssertTrue([troubleshooting containsString:@"--enable-input-source"], @"troubleshooting documents user-session input source re-enable repair");
        AssertTrue([troubleshooting containsString:@"LaunchServices has seen development or expanded-package"], @"troubleshooting documents duplicate LaunchServices records");
        AssertTrue([troubleshooting containsString:@"\"$LSREGISTER\" -gc"], @"troubleshooting compacts LaunchServices after stale-path unregister commands");
        AssertTrue([troubleshooting containsString:@"log show --last 15m"], @"troubleshooting documents process log collection");
        AssertTrue([troubleshooting containsString:@"DiagnosticReports"], @"troubleshooting documents crash report collection");
        AssertTrue([troubleshooting containsString:@"Manual Smoke Test Matrix"], @"troubleshooting documents manual GUI smoke test matrix");
        AssertTrue([troubleshooting containsString:@"make release-signed"], @"troubleshooting documents signed release verification path");
        NSString *branchProtection = FileTextAtPath([root stringByAppendingPathComponent:@"docs/BRANCH_PROTECTION.md"]);
        AssertTrue([branchProtection containsString:@"Require the `Release preflight` status check"], @"branch protection policy requires CI release preflight");
        AssertTrue([branchProtection containsString:@"Block force pushes"], @"branch protection policy blocks force pushes");
        AssertTrue([branchProtection containsString:@"Block branch deletion"], @"branch protection policy blocks branch deletion");
        NSString *ciWorkflow = FileTextAtPath([root stringByAppendingPathComponent:@".github/workflows/ci.yml"]);
        AssertTrue([ciWorkflow containsString:@"build/PurrType-*.pkg"], @"CI uploads PurrType package artifacts");
        AssertTrue([ciWorkflow containsString:@"build/PurrType-*.dmg"], @"CI uploads PurrType DMG artifacts");
        AssertTrue([ciWorkflow containsString:@"build/typing-simulation-report.md"], @"CI uploads typing simulation report");
        AssertTrue([ciWorkflow containsString:@"build/legacy_*.tsv"], @"CI uploads legacy parity TSV reports");
        AssertTrue(![ciWorkflow containsString:@"build/windows_xp_"], @"CI does not keep stale Windows XP artifact paths");
        NSString *bugReportTemplate = FileTextAtPath([root stringByAppendingPathComponent:@".github/ISSUE_TEMPLATE/bug_report.yml"]);
        AssertTrue([bugReportTemplate containsString:@"PurrType input method problem"], @"bug report template uses current product name");
        AssertTrue([bugReportTemplate containsString:@"PurrType version or commit SHA"], @"bug report template asks for the current product version");
        AssertTrue(![bugReportTemplate containsString:@"Mac Keyboard"], @"bug report template does not keep stale product naming");

        NSString *englishLocalization = FileTextAtPath([root stringByAppendingPathComponent:@"resources/en.lproj/Localizable.strings"]);
        NSString *traditionalChineseLocalization = FileTextAtPath([root stringByAppendingPathComponent:@"resources/zh-Hant.lproj/Localizable.strings"]);
        NSString *preferencesController = FileTextAtPath([root stringByAppendingPathComponent:@"src/PurrTypePreferencesWindowController.m"]);
        NSString *preferencesConstants = FileTextAtPath([root stringByAppendingPathComponent:@"src/PurrTypePreferencesConstants.h"]);
        AssertTrue([preferencesController containsString:@"MKPreferencesSidebarItemInset = 14.0"], @"preferences sidebar keeps readable compact item padding");
        AssertTrue([preferencesController containsString:@"MKPreferencesSidebarTitleInset = 20.0"], @"preferences sidebar keeps the title away from the window edge in compact layout");
        AssertTrue([preferencesController containsString:@"MKPreferencesSidebarWidth - (MKPreferencesSidebarItemInset * 2.0)"], @"preferences sidebar button width follows item padding");
        AssertTrue([preferencesController containsString:@"MKPreferencesTabGeneral"], @"preferences controller restores the General tab identifier");
        AssertTrue([preferencesController containsString:@"MKPreferencesCoverAspectRatio = 1672.0 / 941.0"], @"preferences cover card uses the artwork aspect ratio");
        AssertTrue([preferencesController containsString:@"MKPreferencesCoverMaxWidth = 380.0"], @"preferences cover card caps visual width for compact portrait layout");
        AssertTrue([preferencesController containsString:@"MIN(scaleX, scaleY)"], @"preferences cover drawing preserves the full artwork without cropping");
        AssertTrue([preferencesController containsString:@"pref_cover_general.png"], @"preferences controller loads the General full cover");
        AssertTrue(![preferencesController containsString:@"_banner.png"], @"preferences controller does not load banner cover assets");
        AssertTrue(![preferencesController containsString:@"startHereCard"], @"preferences controller does not keep Start Here onboarding UI");
        AssertTrue(![preferencesController containsString:@"supportedFeaturesCard"], @"preferences controller does not keep fake support chips UI");
        AssertTrue(![preferencesController containsString:@"readOnlySwitch"], @"preferences controller does not render fake read-only toggles");
        AssertTrue([englishLocalization containsString:@"\"General\" = \"General\";"], @"English preferences localization includes General");
        AssertTrue([englishLocalization containsString:@"\"Input Modes\" = \"Input Modes\";"], @"English preferences localization includes Input Modes");
        AssertTrue([englishLocalization containsString:@"\"Privacy & Learning\" = \"Privacy & Learning\";"], @"English preferences localization includes Privacy & Learning");
        AssertTrue([englishLocalization containsString:@"\"Privacy Lock\" = \"Privacy Lock\";"], @"English preferences localization includes Privacy Lock");
        AssertTrue([englishLocalization containsString:@"\"Candidate Page Size\" = \"Candidate Page Size\";"], @"English preferences localization includes candidate page size");
        AssertTrue([englishLocalization containsString:@"\"Show raw English candidate as 0\""], @"English preferences localization includes raw-English candidate setting");
        AssertTrue([englishLocalization containsString:@"\"English spelling suggestions\""], @"English preferences localization includes spelling suggestion setting");
        AssertTrue([englishLocalization containsString:@"\"Quick Phrases\" = \"Quick Phrases\";"], @"English preferences localization includes Quick Phrases");
        AssertTrue([englishLocalization containsString:@"\"Backup / Restore\" = \"Backup / Restore\";"], @"English preferences localization includes basic backup");
        AssertTrue([englishLocalization containsString:@"\"Temporary English with Shift\" = \"Uppercase English with Shift\";"], @"English preferences localization explains Shift as uppercase English");
        AssertTrue([englishLocalization containsString:@"\"On - learning paused\""], @"English preferences localization includes clear Privacy Lock state");
        AssertTrue([traditionalChineseLocalization containsString:@"\"General\" = \"一般\";"], @"Traditional Chinese preferences localization includes General");
        AssertTrue([traditionalChineseLocalization containsString:@"\"Input Modes\" = \"輸入模式\";"], @"Traditional Chinese preferences localization includes Input Modes");
        AssertTrue([traditionalChineseLocalization containsString:@"\"Privacy & Learning\" = \"私隱與學習\";"], @"Traditional Chinese preferences localization includes Privacy & Learning");
        AssertTrue([traditionalChineseLocalization containsString:@"\"Privacy Lock\" = \"私隱鎖\";"], @"Traditional Chinese preferences localization includes Privacy Lock");
        AssertTrue([traditionalChineseLocalization containsString:@"\"Candidate Page Size\" = \"候選頁大小\";"], @"Traditional Chinese preferences localization includes candidate page size");
        AssertTrue([traditionalChineseLocalization containsString:@"\"Show raw English candidate as 0\" = \"以 0 顯示原文英文候選\";"], @"Traditional Chinese preferences localization includes raw-English candidate setting");
        AssertTrue([traditionalChineseLocalization containsString:@"\"English spelling suggestions\" = \"英文串字建議\";"], @"Traditional Chinese preferences localization includes spelling suggestion setting");
        AssertTrue([traditionalChineseLocalization containsString:@"\"Quick Phrases\" = \"快速短語\";"], @"Traditional Chinese preferences localization includes Quick Phrases");
        AssertTrue([traditionalChineseLocalization containsString:@"\"Backup / Restore\" = \"備份 / 還原\";"], @"Traditional Chinese preferences localization includes basic backup");
        AssertTrue([traditionalChineseLocalization containsString:@"\"Temporary English with Shift\" = \"按 Shift 輸入大楷英文\";"], @"Traditional Chinese preferences localization explains Shift as uppercase English");
        AssertTrue([traditionalChineseLocalization containsString:@"\"On - learning paused\" = \"開：學習暫停\";"], @"Traditional Chinese preferences localization includes clear Privacy Lock state");
        AssertTrue([preferencesConstants containsString:@"https://buymeacoffee.com/mrz.final.v1_1_1_1.mov"], @"Buy Me a Coffee link points to the requested URL");
        AssertTrue([preferencesController containsString:@"horizontalButtonRowWithButtons"], @"About Links uses a horizontal button row");
        AssertTrue([preferencesController containsString:@"CIQRCodeGenerator"], @"About Links generates a Buy Me a Coffee QR code locally");
        AssertTrue([englishLocalization containsString:@"\"Buy Me a Coffee QR Code\""], @"English localization includes QR accessibility label");
        AssertTrue([traditionalChineseLocalization containsString:@"\"Buy Me a Coffee QR Code\""], @"Traditional Chinese localization includes QR accessibility label");

        NSString *traditionalCompatibility = FileTextAtPath([root stringByAppendingPathComponent:@"resources/traditional_compatibility.tsv"]);
        AssertTrue([traditionalCompatibility containsString:@"着\ttu\ttqbu"], @"Traditional compatibility table includes CUV 着 mapping");
        AssertTrue([traditionalCompatibility containsString:@"弑\tkm\tkdipm"], @"Traditional compatibility table includes CUV 弑 mapping");
        NSString *generatedAssociations = FileTextAtPath([root stringByAppendingPathComponent:@"resources/association_generated.tsv"]);
        AssertTrue([generatedAssociations containsString:@"# Generated by scripts/generate-association-seeds.rb."], @"generated association table is reproducible");
        AssertTrue([generatedAssociations containsString:@"神\t"], @"generated association table includes corpus-derived keys");
        NSString *associationSeedGenerator = FileTextAtPath([root stringByAppendingPathComponent:@"scripts/generate-association-seeds.rb"]);
        AssertTrue([associationSeedGenerator containsString:@"MAX_CANDIDATES_PER_KEY = 120"], @"generated association table keeps enough per-key candidates for related-word paging");
        NSString *associationIndexGenerator = FileTextAtPath([root stringByAppendingPathComponent:@"scripts/index-association-generated.rb"]);
        AssertTrue([associationIndexGenerator containsString:@"PTAIDX01"], @"generated association table is converted into a binary index at build time");
        AssertTrue([associationIndexGenerator containsString:@"sort_by"], @"generated association index keeps keys sorted for runtime lookup");

        NSString *controller = FileTextAtPath([root stringByAppendingPathComponent:@"src/PurrTypeInputController.m"]);
        AssertTrue([controller containsString:@"#import <Carbon/Carbon.h>"], @"input controller can inspect macOS secure event input state");
        AssertTrue([controller containsString:@"- (BOOL)isSecureTextInputActive"], @"input controller centralizes secure input detection");
        AssertTrue([controller containsString:@"IsSecureEventInputEnabled()"], @"input controller uses the system secure-input API");
        AssertTrue([controller containsString:@"- (void)bypassForSecureTextInput"], @"input controller has an explicit secure-input bypass path");
        AssertTrue([controller containsString:@"[self bypassForSecureTextInput];"], @"secure input bypass runs before candidate handling");
        AssertTrue([controller containsString:@"secureInputMonitorTimer"], @"secure input monitor keeps checking Terminal password prompts even before IMK receives another key event");
        AssertTrue([controller containsString:@"MKSecureInputMonitorInterval = 0.25"], @"secure input monitor uses a low-frequency active-window poll");
        AssertTrue([controller containsString:@"MKFrontmostApplicationMayOwnSecureTextInputPrompt"], @"secure input monitor is scoped to terminal-style apps instead of global secure-input state");
        AssertTrue([controller containsString:@"com.apple.Terminal"] &&
                   [controller containsString:@"com.googlecode.iterm2"] &&
                   [controller containsString:@"dev.warp.Warp-Stable"],
                   @"secure input monitor covers common terminal apps");
        AssertTrue([controller containsString:@"shouldMonitorSecureTextInputForActiveApplication"], @"secure input monitor has an explicit app-scope gate");
        AssertTrue([controller containsString:@"- (void)pollSecureTextInputState:(NSTimer *)timer"], @"secure input monitor has an explicit poll callback");
        AssertTrue([controller containsString:@"TISCopyCurrentASCIICapableKeyboardLayoutInputSource"], @"secure input can choose the active ASCII keyboard layout");
        AssertTrue([controller containsString:@"TISCopyCurrentASCIICapableKeyboardInputSource"], @"secure input has an ASCII input-source fallback");
        AssertTrue([controller containsString:@"TISSelectInputSource(asciiSource)"], @"secure input switches away from PurrType before password typing continues");
        AssertTrue([controller containsString:@"MKAssociationCandidateFetchLimit = 120"], @"input controller fetches enough association candidates for paging");
        AssertTrue([controller containsString:@"limit:MKAssociationCandidateFetchLimit"], @"input controller uses the association paging fetch limit");
        AssertTrue([controller containsString:@"handlePreferencesShortcutForKey"], @"input controller handles preferences shortcut");
        AssertTrue([controller containsString:@"isPreferencesShortcutKeyCode"], @"input controller delegates preferences shortcut behavior");
        AssertTrue([controller containsString:@"[self.preferences privacyLockEnabled]"], @"input controller reads Privacy Lock through the preferences store");
        AssertTrue([controller containsString:@"MKQuickPhraseCandidateSource"], @"input controller has Quick Phrases candidates");
        AssertTrue([controller containsString:@"convertSemicolonPunctuationToQuickPhraseWithString"], @"input controller turns ; prefix typing into Quick Phrases composition");
        AssertTrue([controller containsString:@"PurrTypeQuickPhraseStore isTriggerContinuationString"], @"Quick Phrases runtime uses strict semicolon trigger continuation syntax");
        NSString *privacyLockSuppressionMethod = SubstringBetween(controller,
                                                                  @"- (BOOL)privacyLockPausesLearningContextForMode:(NSString *)mode {\n",
                                                                  @"\n}\n\n- (void)resetLearning");
        AssertTrue([privacyLockSuppressionMethod containsString:@"privacyLockShouldPauseLearningContextForMode:mode"] &&
                   [privacyLockSuppressionMethod containsString:@"enabled:self.privacyLockEnabled"],
                   @"Privacy Lock delegates mode policy instead of suppressing associations globally");
        AssertTrue(![privacyLockSuppressionMethod containsString:@"MKInputModeSucheng]"] &&
                   ![privacyLockSuppressionMethod containsString:@"MKInputModeCangjie"] &&
                   ![privacyLockSuppressionMethod containsString:@"MKInputModePinyin"],
                   @"Privacy Lock must leave fixed Classic Sucheng, Cangjie, and Pinyin associations visible");
        AssertTrue(![controller containsString:@"showAssociations && !self.privacyLockEnabled"],
                   @"Privacy Lock must not suppress fixed Classic Sucheng association dictionaries globally");
        AssertTrue([controller containsString:@"effectiveLearningEnabledFromPreferences"] &&
                   [controller containsString:@"self.engine.learningEnabled = [self effectiveLearningEnabledFromPreferences]"],
                   @"Privacy Lock pauses local learning without overwriting learning preference");
        NSString *preferencesStore = FileTextAtPath([root stringByAppendingPathComponent:@"src/PurrTypePreferencesStore.m"]);
        AssertTrue([preferencesStore containsString:@"[NSBundle mainBundle].bundleIdentifier isEqualToString:MKUserDefaultsSuiteName"] &&
                   [preferencesStore containsString:@"[NSUserDefaults standardUserDefaults]"],
                   @"preferences store uses standard defaults for its own bundle domain instead of opening its own suite name");
        AssertTrue([controller containsString:@"self.lastInputClient = sender ?: [self client];"], @"input controller remembers latest event client for candidate positioning");
        AssertTrue([controller containsString:@"- (BOOL)inputText:(NSString *)string client:(id)sender"], @"input controller handles IMK text-only input callbacks");
        NSString *inputTextFallbackSection = SubstringBetween(controller,
                                                              @"- (BOOL)inputText:(NSString *)string client:(id)sender",
                                                              @"- (BOOL)handleInputText:");
        AssertTrue([inputTextFallbackSection containsString:@"MKUnknownKeyCode"], @"text-only IMK callbacks route through shared input handling without a hardware key code");
        AssertTrue([inputTextFallbackSection containsString:@"hasKeyEvent:NO"], @"text-only IMK callbacks disable key-code-only shortcut handling");
        AssertTrue([controller containsString:@"- (void)activateServer:(id)sender"], @"input controller tracks IMK activation when switching apps");
        AssertTrue([controller containsString:@"- (NSDictionary *)modes:(id)sender"], @"input controller explicitly keeps IMK mode metadata empty");
        AssertTrue([controller containsString:@"return @{};"], @"input controller does not expose internal modes as macOS input sources");
        AssertTrue([controller containsString:@"- (id)valueForTag:(NSInteger)tag client:(id)sender"], @"input controller reports the unified input source value to IMK");
        AssertTrue([controller containsString:@"- (id)activeInputClient"], @"input controller centralizes active client selection");
        AssertTrue([controller containsString:@"- (id)candidatePanelClientForCurrentState"], @"input controller separates composition and post-commit association panel client routing");
        AssertTrue([controller containsString:@"shouldUsePreservedCandidatePanelAnchorForCurrentState"], @"input controller gates preserved candidate-panel anchors explicitly");
        AssertTrue([controller containsString:@"self.inputState.associationModeActive &&"], @"post-commit association panel routing checks association state");
        AssertTrue([controller containsString:@"return nil;"], @"post-commit association panel routing reuses preserved anchor instead of querying selectedRange");
        AssertTrue([controller containsString:@"usePreservedAnchor:usePreservedAnchor"], @"post-commit association panel passes an explicit preserved-anchor flag");
        AssertTrue(![controller containsString:@"PurrTypeUnified.NewSucheng"], @"input controller does not keep stale mode-level input source identifiers");
        AssertTrue(![controller containsString:@"MKInputSourceMode"], @"input controller keeps mode switching internal to PurrType");
        AssertTrue(![controller containsString:@"ComponentInputModeDict"], @"input controller does not read mode-level source metadata");
        AssertTrue(![controller containsString:@"selectInputMode:"], @"input controller switches modes internally without selecting macOS-visible mode sources");
        NSString *switchToEngineModeSection = SubstringBetween(controller,
                                                               @"- (void)switchToEngineMode:(NSString *)mode updateClientInputMode:(BOOL)updateClientInputMode client:(id)sender {",
                                                               @"- (void)addModeMenuItemWithTitle:");
        AssertTrue(![switchToEngineModeSection containsString:@"TISSelectInputSource"], @"internal mode switching does not mutate macOS input sources");
        AssertTrue([switchToEngineModeSection containsString:@"[self refreshEnabledInputModesFromDefaults];"], @"stale menu actions refresh enabled modes before switching internally");
        AssertTrue([controller containsString:@"- (void)refreshEnabledInputModesFromDefaults"], @"input controller can refresh enabled modes directly from shared preferences");
        AssertTrue([controller containsString:@"- (NSMenu *)menu {\n    [self refreshEnabledInputModesFromDefaults];"], @"input menu refreshes enabled modes before rendering rows");
        AssertTrue([controller containsString:@"if (![self isEnabledEngineMode:mode]) {\n        return;\n    }\n\n    SEL action = @selector(selectCangjieMode:);"],
                   @"input menu omits disabled internal mode rows");
        AssertTrue([controller containsString:@"- (BOOL)handleModeShortcutForKey:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender {\n    (void)sender;\n    [self refreshEnabledInputModesFromDefaults];"], @"mode shortcuts refresh enabled modes before routing");
        AssertTrue([controller containsString:@"- (void)warmUpEngineInBackground"], @"input controller warms the engine after activation setup");
        AssertTrue([controller containsString:@"dispatch_get_global_queue(QOS_CLASS_UTILITY"], @"background engine warm-up does not run at UI-interactive priority");
        AssertTrue(![controller containsString:@"_engine = [PurrTypeEngine sharedEngine];"], @"input controller does not synchronously build the full engine during controller initialization");
        AssertTrue([controller containsString:@"PurrTypePreferencesStore"], @"input controller delegates shared defaults access to the preferences store");
        AssertTrue(![controller containsString:@"NSUserDefaults"], @"input controller does not read or write preferences defaults directly");
        AssertTrue(![controller containsString:@"recentCommittedTextSegments"], @"input controller does not own learning-ranking rolling text state");
        AssertTrue([controller containsString:@"modeMenuImageForMode"], @"input controller attaches mode icons to menu rows");
        AssertTrue([controller containsString:@"beginCandidateAnchorSessionForClient"], @"input controller starts explicit candidate anchor sessions");
        AssertTrue([controller containsString:@"resetCompositionPreservingCandidateAnchor"], @"input controller preserves the anchor for association candidates after commit");
        NSString *activateServerSection = SubstringBetween(controller, @"- (void)activateServer:", @"- (void)deactivateServer:");
        AssertTrue([activateServerSection containsString:@"[super activateServer:sender]"], @"input controller preserves IMK activation behavior");
        AssertTrue([activateServerSection containsString:@"rememberActiveInputClient"], @"input controller remembers the app client on activation");
        AssertTrue([activateServerSection containsString:@"startSecureInputMonitor"], @"input controller starts gated secure-input monitoring on activation");
        NSString *deactivateServerSection = SubstringBetween(controller, @"- (void)deactivateServer:", @"- (void)hidePalettes");
        AssertTrue([deactivateServerSection containsString:@"stopSecureInputMonitor"], @"input controller stops secure-input monitoring on deactivate");
        AssertTrue([deactivateServerSection containsString:@"commitComposition"], @"input controller commits pending composition on deactivate");
        AssertTrue([deactivateServerSection containsString:@"resetComposition"], @"input controller clears candidate panel state on deactivate");
        AssertTrue([deactivateServerSection containsString:@"self.lastInputClient = nil"], @"input controller drops stale app client references on deactivate");
        AssertTrue([deactivateServerSection containsString:@"lastPrivacyLockBacktickTime = 0"], @"input controller resets transient shortcut state on deactivate");
        NSString *hidePalettesSection = SubstringBetween(controller, @"- (void)hidePalettes", @"- (NSUInteger)recognizedEvents");
        AssertTrue([hidePalettesSection containsString:@"candidateUpdateSerial += 1"], @"hidePalettes cancels delayed candidate panel updates");
        AssertTrue([hidePalettesSection containsString:@"clearAnchorSession"], @"hidePalettes clears candidate panel anchor state");
        NSString *setCandidatePoolSection = SubstringBetween(controller, @"- (void)setCandidatePool:", @"- (void)updateCurrentCandidatePage");
        AssertTrue(![setCandidatePoolSection containsString:@"updateCandidatePanel"], @"candidate panel is not positioned before marked text is updated");
        NSString *updateCompositionSection = SubstringBetween(controller, @"- (void)updateComposition", @"- (void)commitCandidateAtIndex");
        AssertTrue([updateCompositionSection containsString:@"[target setMarkedText:markedText"], @"composition updates marked text before candidate positioning");
        AssertTrue([updateCompositionSection containsString:@"scheduleCandidatePanelUpdate"], @"composition schedules candidate positioning after marked text update");
        NSString *commitTextSection = SubstringBetween(controller, @"- (void)commitText:(NSString *)text client:(id)sender resetFirst:(BOOL)resetFirst showAssociations:", @"- (void)resetComposition");
        AssertTrue([commitTextSection containsString:@"sender ?: [self activeInputClient]"], @"commitText falls back to the active IMK client after app switches");
        NSString *inputTextSection = SubstringBetween(controller,
                                                      @"hasKeyEvent:(BOOL)hasKeyEvent {\n    [self rememberActiveInputClient:sender];",
                                                      @"- (BOOL)didCommandBySelector:");
        NSRange rawContinuationRange = [inputTextSection rangeOfString:@"isRawEnglishContinuationString"];
        NSRange punctuationRange = [inputTextSection rangeOfString:@"showPunctuationCandidatesForString"];
        AssertTrue(rawContinuationRange.location != NSNotFound && punctuationRange.location != NSNotFound && rawContinuationRange.location < punctuationRange.location,
                   @"raw English continuation is handled before punctuation candidates");
        NSRange pinyinSpaceCommitRange = [inputTextSection rangeOfString:@"[self commitCandidateAtIndex:[self candidateIndexForCurrentCommit] client:sender]"];
        NSRange candidatePageKeyRange = [inputTextSection rangeOfString:@"handleCandidatePageKey"];
        AssertTrue(pinyinSpaceCommitRange.location != NSNotFound &&
                   candidatePageKeyRange.location != NSNotFound &&
                   pinyinSpaceCommitRange.location < candidatePageKeyRange.location,
                   @"Pinyin Space commits the highlighted candidate before Space can page candidates");
        NSString *scheduleCandidatePanelUpdateSection = SubstringBetween(controller,
                                                                         @"- (void)scheduleCandidatePanelUpdate {",
                                                                         @"- (void)updateCandidatePanel {");
        AssertTrue([scheduleCandidatePanelUpdateSection containsString:@"dispatch_after"], @"candidate panel positioning gets a delayed re-anchor for apps that update caret rect asynchronously");
        AssertTrue([controller containsString:@"[self scheduleCandidatePanelUpdate];"], @"association and punctuation candidates use scheduled positioning");
        AssertTrue([controller containsString:@"candidatePanelAnchorCharacterIndex"], @"input controller passes the composing character index to candidate positioning");
        AssertTrue([controller containsString:@"showPunctuationCandidatesForString"], @"input controller opens punctuation candidates");
        AssertTrue([controller containsString:@"punctuationAnchorText"], @"input controller keeps a transient marked-text anchor for punctuation candidates");
        AssertTrue([controller containsString:@"updatePunctuationCompositionForClient"], @"punctuation candidates update marked text before positioning");
        AssertTrue([controller containsString:@"self.punctuationCandidateTexts.count > 0 && self.punctuationAnchorText.length > 0"] &&
                   [controller containsString:@"return @(self.punctuationAnchorText.length - 1);"],
                   @"punctuation candidates use the same active marked character index as text candidates");
        AssertTrue([controller containsString:@"commitPunctuationCandidateText"], @"input controller commits selected punctuation");
        AssertTrue([controller containsString:@"shouldAutoCommitDefaultPunctuationForInputString"], @"input controller auto-commits default punctuation when typing continues without alternate selection");
        AssertTrue([controller containsString:@"handlePinyinCandidateSelectionKey"] &&
                   [controller containsString:@"handlePinyinCandidateSelectionSelector"] &&
                   [controller containsString:@"candidatePanelSelectedIndexForCandidateTexts"],
                   @"input controller supports Pinyin Up/Down candidate selection and panel highlighting");
        AssertTrue([controller containsString:@"selectedIndex:[self candidatePanelSelectedIndexForCandidateTexts:candidateTexts]"],
                   @"candidate panel receives the active selected row from the input controller");

        NSString *inputBehavior = FileTextAtPath([root stringByAppendingPathComponent:@"src/PurrTypeInputBehavior.m"]);
        AssertTrue([inputBehavior containsString:@"MKInputBehaviorKeyCodeComma = 43"], @"preferences shortcut uses comma key");
        AssertTrue([inputBehavior containsString:@"punctuationCandidateDisplayTextsForString"], @"input behavior exposes punctuation candidate display rows");
        AssertTrue([inputBehavior containsString:@"shouldAutoCommitDefaultPunctuationForInputString"], @"input behavior exposes pending punctuation default-commit rules");
        AssertTrue([inputBehavior containsString:@"@[@\".\", @\"。\", @\"．\", @\"・\", @\"…\"]"], @"period candidates follow open-table punctuation order");
        AssertTrue([inputBehavior containsString:@"@[@\"*\", @\"＊\", @\"†\", @\"‡\", @\"§\"]"], @"asterisk candidates include open-table reference marks");
        NSString *inputState = FileTextAtPath([root stringByAppendingPathComponent:@"src/PurrTypeInputState.m"]);
        AssertTrue([inputState containsString:@"character >= 33 && character <= 126"], @"raw English keeps printable ASCII punctuation inside the token");
        NSString *engine = FileTextAtPath([root stringByAppendingPathComponent:@"src/PurrTypeEngine.m"]);
        AssertTrue([engine containsString:@"association_generated.index"], @"engine loads generated association index");
        AssertTrue(![engine containsString:@"loadAssociationSeedAtPath:self.associationGenerated"], @"engine does not parse the generated TSV on first association lookup");
        AssertTrue([engine containsString:@"associationLookupKeysForText"], @"engine can use full committed phrases before single-character fallback");
        AssertTrue(![engine containsString:@"SecItem"], @"engine does not use credential-store APIs for learning");
        AssertTrue(![engine containsString:@"Security/Security.h"], @"engine does not import security framework APIs for learning");
        AssertTrue([engine containsString:@"learning-rankings.json"], @"engine stores permission-free hashed local ranking data");
        AssertTrue([engine containsString:@"candidateHashes"], @"engine persists candidate ranking by hash");
        AssertTrue([engine containsString:@"associationHashes"], @"engine persists association ranking by hash");
        AssertTrue([engine containsString:@"recordCommittedCandidateText"], @"engine owns committed-candidate learning context updates");

        NSString *candidatePanel = FileTextAtPath([root stringByAppendingPathComponent:@"src/PurrTypeCandidatePanel.m"]);
        AssertTrue([candidatePanel containsString:@"MKCandidatePanelRowHeight = 21.0"], @"custom candidate panel uses readable compact fixed row height");
        AssertTrue([candidatePanel containsString:@"MKCandidatePanelHeaderHeight = 18.0"], @"custom candidate panel reserves a page-count header");
        AssertTrue([candidatePanel containsString:@"MKCandidatePanelMaxWidth = 154.0"], @"custom candidate panel uses compact bounded width");
        AssertTrue([candidatePanel containsString:@"MKCandidatePanelCaretHorizontalGap"], @"custom candidate panel positions beside the caret");
        AssertTrue([candidatePanel containsString:@"attributesForCharacterIndex:lineHeightRectangle:"], @"custom candidate panel can use the IMK line-height caret anchor");
        AssertTrue([candidatePanel containsString:@"NSMakeRange(NSMaxRange(markedRange), 0)"], @"custom candidate panel follows the marked-text insertion endpoint");
        AssertTrue([candidatePanel containsString:@"anchorRectFromLineHeightAttributesForClient"], @"custom candidate panel keeps line-height anchoring centralized");
        AssertTrue([candidatePanel containsString:@"resolveAnchorRect:&anchorRect"], @"custom candidate panel routes all candidate types through the same anchor resolver");
        AssertTrue([candidatePanel containsString:@"forClient:client"], @"custom candidate panel resolves anchors against the active client");
        AssertTrue([candidatePanel containsString:@"usePreservedAnchor:(BOOL)usePreservedAnchor"], @"custom candidate panel makes preserved-anchor reuse explicit");
        AssertTrue(![candidatePanel containsString:@"mouseLocation"], @"custom candidate panel does not fall back to mouse location when the caret anchor is unavailable");
        AssertTrue([candidatePanel containsString:@"beginAnchorSessionForClient"], @"custom candidate panel locks anchor sessions explicitly");
        AssertTrue(![candidatePanel containsString:@"NSScrollView"], @"custom candidate panel does not use a scrollbar");
        AssertTrue([candidatePanel containsString:@"ignoresMouseEvents = NO"], @"custom candidate panel accepts mouse selection");
        AssertTrue([candidatePanel containsString:@"selectCandidateAtPanelPoint"], @"custom candidate panel exposes row hit-testing selection");

        NSString *preferencesMain = FileTextAtPath([root stringByAppendingPathComponent:@"src/preferences_main.m"]);
        NSString *preferencesBuildWindowContentSection = SubstringBetween(preferencesController,
                                                                          @"- (void)buildWindowContent",
                                                                          @"- (NSArray<NSDictionary<NSString *, NSString *> *> *)sidebarItems");
        AssertTrue(![preferencesBuildWindowContentSection containsString:@"reloadState"], @"preferences window defers initial content build until a delegate is available");
        AssertTrue([preferencesController containsString:@"preferenceCoverImagesByFilename"], @"preferences window caches cover images between tab rebuilds");
        AssertTrue([preferencesController containsString:@"cachedAppIconImage"], @"preferences window caches the app icon between sidebar rebuilds");
        AssertTrue([preferencesMain containsString:@"Show PurrType Preferences"], @"preferences helper installs app menu entry localization key");
        AssertTrue([preferencesMain containsString:@"Quit PurrType Preferences"], @"preferences helper installs quit menu entry localization key");
        AssertTrue(![preferencesMain containsString:@"buildEngine"], @"preferences helper does not synchronously build the full input engine");
        AssertTrue(![preferencesMain containsString:@"PurrTypeEngine"], @"preferences helper does not call engine APIs directly");
        AssertTrue(![preferencesMain containsString:@"removeItemAtPath"], @"preferences helper does not delete learning files directly");
        AssertTrue([preferencesMain containsString:@"requestLearningReset"], @"preferences helper records reset requests through the preferences store");
        AssertTrue([preferencesMain containsString:@"postPreferencesChangedNotification"], @"preferences helper settings changes notify the input controller");

        NSLog(@"PASS: PurrTypeBundleTests");
    }
    return 0;
}
