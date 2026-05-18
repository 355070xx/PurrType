BUNDLE_NAME := PurrTypeIM.app
EXECUTABLE_NAME := PurrType
VERSION := 0.1.0
BUNDLE_VERSION := $(shell printf "%s" "$(VERSION)" | awk -F. '{printf "%d", ($$1 * 10000) + ($$2 * 100) + $$3}')
BUILD_DIR := build
BUNDLE_DIR := $(BUILD_DIR)/$(BUNDLE_NAME)
CONTENTS_DIR := $(BUNDLE_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
PREFERENCES_BUNDLE_NAME := PurrTypePreferences.app
PREFERENCES_EXECUTABLE_NAME := PurrTypePreferences
PREFERENCES_BUNDLE_DIR := $(RESOURCES_DIR)/$(PREFERENCES_BUNDLE_NAME)
PREFERENCES_CONTENTS_DIR := $(PREFERENCES_BUNDLE_DIR)/Contents
PREFERENCES_MACOS_DIR := $(PREFERENCES_CONTENTS_DIR)/MacOS
PREFERENCE_COVER_RESOURCES := resources/PreferenceCovers/pref_cover_general.png resources/PreferenceCovers/pref_cover_input_modes.png resources/PreferenceCovers/pref_cover_typing.png resources/PreferenceCovers/pref_cover_privacy_learning.png resources/PreferenceCovers/pref_cover_about.png
PKG_ID := org.purrtype.inputmethod.PurrTypeUnified.pkg
PKGROOT_DIR := $(BUILD_DIR)/pkgroot
DMGROOT_DIR := $(BUILD_DIR)/dmgroot
PKG_PATH := $(BUILD_DIR)/PurrType-$(VERSION).pkg
UNINSTALL_PKG_ID := org.purrtype.inputmethod.PurrTypeUnified.uninstall.pkg
UNINSTALL_PKG_PATH := $(BUILD_DIR)/Uninstall-PurrType-$(VERSION).pkg
DMG_PATH := $(BUILD_DIR)/PurrType-$(VERSION).dmg
UNSIGNED_RELEASE_PKG_PATH := $(BUILD_DIR)/PurrType-$(VERSION)-unsigned-release.pkg
UNSIGNED_UNINSTALL_PKG_PATH := $(BUILD_DIR)/Uninstall-PurrType-$(VERSION)-unsigned.pkg
SIGNED_PKG_PATH := $(BUILD_DIR)/PurrType-$(VERSION)-signed.pkg
SIGNED_UNINSTALL_PKG_PATH := $(BUILD_DIR)/Uninstall-PurrType-$(VERSION)-signed.pkg
SIGNED_DMG_PATH := $(BUILD_DIR)/PurrType-$(VERSION)-signed.dmg
CHECKSUMS_PATH := $(BUILD_DIR)/PurrType-$(VERSION)-checksums.sha256
SIGNED_CHECKSUMS_PATH := $(BUILD_DIR)/PurrType-$(VERSION)-signed-checksums.sha256
PROVENANCE_PATH := $(BUILD_DIR)/PurrType-$(VERSION)-provenance.json
SIGNED_PROVENANCE_PATH := $(BUILD_DIR)/PurrType-$(VERSION)-signed-provenance.json
PACKAGE_SMOKE_DIR := $(BUILD_DIR)/package-smoke
LEARNING_PATH := $(HOME)/Library/Application Support/PurrType/learning-rankings.json
LEGACY_LEARNING_PATH := $(HOME)/Library/Application Support/PurrType/learning.json
COMPONENT_PLIST := packaging/component.plist
PACKAGE_SMOKE_APP := $(PACKAGE_SMOKE_DIR)/expanded/Payload/Library/Input Methods/$(BUNDLE_NAME)
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
SDK_PATH := $(shell xcrun --sdk macosx --show-sdk-path)
MIN_MACOS := 12.0
DEVELOPER_ID_APPLICATION_IDENTITY ?=
DEVELOPER_ID_INSTALLER_IDENTITY ?=
NOTARY_KEYCHAIN_PROFILE ?= PurrTypeNotary
ASSOCIATION_GENERATED_TSV := resources/association_generated.tsv
ASSOCIATION_GENERATED_INDEX := resources/association_generated.index
ASSOCIATION_INDEX_SCRIPT := scripts/index-association-generated.rb
CANDIDATE_INDEX_DIR := resources/CandidateTables
QUICK_CANDIDATE_INDEX := $(CANDIDATE_INDEX_DIR)/quick-classic.index
CANGJIE_CANDIDATE_INDEX := $(CANDIDATE_INDEX_DIR)/cangjie5.index
PINYIN_CANDIDATE_INDEX := $(CANDIDATE_INDEX_DIR)/pinyin.index
CANDIDATE_INDEXES := $(QUICK_CANDIDATE_INDEX) $(CANGJIE_CANDIDATE_INDEX) $(PINYIN_CANDIDATE_INDEX)
CANDIDATE_INDEX_SCRIPT := scripts/index-candidate-tables.rb

OBJCFLAGS := -fobjc-arc -Wall -Wextra -ObjC -isysroot $(SDK_PATH) -mmacosx-version-min=$(MIN_MACOS)
FRAMEWORKS := -framework Cocoa -framework InputMethodKit -framework Carbon -framework CoreImage
ENGINE_TEST_FRAMEWORKS := -framework Foundation
ENGINE_SOURCES := src/PurrTypeEngine.m
INPUT_STATE_SOURCES := src/PurrTypeInputState.m
INPUT_BEHAVIOR_SOURCES := src/PurrTypeInputBehavior.m
CANDIDATE_PANEL_SOURCES := src/PurrTypeCandidatePanel.m
PREFERENCES_SOURCES := src/PurrTypePreferencesWindowController.m
PREFERENCES_STORE_SOURCES := src/PurrTypePreferencesStore.m
APP_SOURCES := src/main.m src/PurrTypeInputController.m src/PurrTypeInputDelegate.m $(ENGINE_SOURCES) $(INPUT_STATE_SOURCES) $(INPUT_BEHAVIOR_SOURCES) $(CANDIDATE_PANEL_SOURCES) $(PREFERENCES_SOURCES) $(PREFERENCES_STORE_SOURCES)
PREFERENCES_APP_SOURCES := src/preferences_main.m $(PREFERENCES_SOURCES) $(PREFERENCES_STORE_SOURCES) $(ENGINE_SOURCES) $(INPUT_BEHAVIOR_SOURCES)
TEST_SOURCES := tests/PurrTypeEngineTests.m $(ENGINE_SOURCES)
STARTUP_BENCHMARK_SOURCES := tests/PurrTypeEngineStartupBenchmark.m $(ENGINE_SOURCES)
INPUT_STATE_TEST_SOURCES := tests/PurrTypeInputStateTests.m $(INPUT_STATE_SOURCES)
INPUT_BEHAVIOR_TEST_SOURCES := tests/PurrTypeInputBehaviorTests.m $(INPUT_BEHAVIOR_SOURCES) $(ENGINE_SOURCES)
CANDIDATE_PANEL_TEST_SOURCES := tests/PurrTypeCandidatePanelTests.m $(CANDIDATE_PANEL_SOURCES)
TYPING_SIMULATION_TEST_SOURCES := tests/PurrTypeTypingSimulationTests.m $(ENGINE_SOURCES) $(INPUT_BEHAVIOR_SOURCES)
FULL_BIBLE_AUDIT_SOURCES := tests/PurrTypeFullBibleTypingAudit.m $(ENGINE_SOURCES) $(INPUT_BEHAVIOR_SOURCES)
CLASSIC_SUCHENG_RANKING_AUDIT_SOURCES := tests/PurrTypeClassicSuchengRankingAudit.m $(ENGINE_SOURCES)
ASSOCIATION_AUDIT_SOURCES := tests/PurrTypeAssociationAudit.m $(ENGINE_SOURCES)
PREFERENCES_TEST_SOURCES := tests/PurrTypePreferencesTests.m $(PREFERENCES_SOURCES) $(PREFERENCES_STORE_SOURCES) $(ENGINE_SOURCES) $(INPUT_BEHAVIOR_SOURCES)
BUNDLE_TEST_SOURCES := tests/PurrTypeBundleTests.m
TIS_PROBE_SOURCES := tests/TISProbe.m
SUCHENG_SNAPSHOT_SOURCES := tests/SuchengSnapshot.m $(ENGINE_SOURCES)
PURRTYPE_TIS_ID := org.purrtype.inputmethod.PurrTypeUnified
TIS_ID ?= $(PURRTYPE_TIS_ID)
SYSTEM_INPUT_METHOD_APP := /Library/Input Methods/$(BUNDLE_NAME)
USER_INPUT_METHOD_APP := $(HOME)/Library/Input Methods/$(BUNDLE_NAME)
RUN_PURRTYPE_APP = app=""; \
	if [ -x "$(USER_INPUT_METHOD_APP)/Contents/MacOS/$(EXECUTABLE_NAME)" ]; then \
	  app="$(USER_INPUT_METHOD_APP)"; \
	elif [ -x "$(SYSTEM_INPUT_METHOD_APP)/Contents/MacOS/$(EXECUTABLE_NAME)" ]; then \
	  app="$(SYSTEM_INPUT_METHOD_APP)"; \
	else \
	  $(MAKE) build >/dev/null; \
	  app="$(BUNDLE_DIR)"; \
	fi; \
	"$$app/Contents/MacOS/$(EXECUTABLE_NAME)"
RUN_INSTALLED_PURRTYPE_APP = app=""; \
	if [ -x "$(USER_INPUT_METHOD_APP)/Contents/MacOS/$(EXECUTABLE_NAME)" ]; then \
	  app="$(USER_INPUT_METHOD_APP)"; \
	elif [ -x "$(SYSTEM_INPUT_METHOD_APP)/Contents/MacOS/$(EXECUTABLE_NAME)" ]; then \
	  app="$(SYSTEM_INPUT_METHOD_APP)"; \
	else \
	  echo "PurrType is not installed under ~/Library/Input Methods or /Library/Input Methods." >&2; \
	  echo "Run make install, or install build/PurrType-$(VERSION).pkg first." >&2; \
	  exit 1; \
	fi; \
	"$$app/Contents/MacOS/$(EXECUTABLE_NAME)"

.PHONY: all build clean-bundle test audit-full-bible audit-sucheng-ranking audit-classic-sucheng-ranking audit-associations audit-hkscs-coverage audit-legacy-parity audit-version audit-version-consistency license-audit dump-sucheng-pages package-smoke release-preflight update-sucheng-snapshot update-association-seeds tis-probe tis-inspect enable select repair-input-source repair-input-source-select install uninstall-local uninstall-system reset-learning stop uninstall-package package release-artifacts checksums provenance check-signing-identities check-notary-profile signed-package signed-uninstall-package signed-dmg notarize-dmg release-signed signed-checksums signed-provenance clean

all: build

build: $(MACOS_DIR)/$(EXECUTABLE_NAME)

clean-bundle:
	rm -rf "$(BUNDLE_DIR)"

$(MACOS_DIR)/$(EXECUTABLE_NAME): clean-bundle $(APP_SOURCES) $(PREFERENCES_APP_SOURCES) src/PurrTypeInputState.h src/PurrTypeInputBehavior.h src/PurrTypeCandidatePanel.h src/PurrTypePreferencesWindowController.h src/PurrTypePreferencesStore.h src/PurrTypePreferencesConstants.h resources/Info.plist resources/PurrTypePreferencesInfo.plist resources/Base.lproj/InfoPlist.strings resources/English.lproj/InfoPlist.strings resources/en.lproj/InfoPlist.strings resources/en.lproj/Localizable.strings resources/zh-Hant.lproj/InfoPlist.strings resources/zh-Hant.lproj/Localizable.strings resources/zh_TW.lproj/InfoPlist.strings resources/PurrType.png $(PREFERENCE_COVER_RESOURCES) LICENSE docs/CREDITS.md docs/PRIVACY_POLICY.md docs/LICENSE_AUDIT.md resources/pinyin_seed.tsv resources/sucheng_order_guards.tsv resources/smart_phrases.tsv resources/association_phrases.tsv $(ASSOCIATION_GENERATED_INDEX) $(CANDIDATE_INDEXES) resources/traditional_compatibility.tsv resources/sucheng_first_pages.tsv scripts/generate-icon.sh scripts/pad-png-alpha.py third_party/rime-cangjie/LICENSE third_party/rime-cangjie/AUTHORS third_party/rime-pinyin/LICENSE third_party/rime-pinyin/AUTHORS third_party/mcbopomofo/LICENSE.txt third_party/ibus-table-chinese/LICENSE third_party/ibus-table-chinese/README.md third_party/hkscs/HKSCS2016.json third_party/hkscs/README.md third_party/hkscs/TERMS.md
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)/CandidateTables" "$(RESOURCES_DIR)/RimeCangjie" "$(RESOURCES_DIR)/RimePinyin" "$(RESOURCES_DIR)/IBusTableChinese" "$(RESOURCES_DIR)/HKSCS" "$(RESOURCES_DIR)/Legal" "$(PREFERENCES_MACOS_DIR)" "$(PREFERENCES_CONTENTS_DIR)/Resources" "$(PREFERENCES_CONTENTS_DIR)/Resources/PreferenceCovers"
	cp resources/Info.plist "$(CONTENTS_DIR)/Info.plist"
	mkdir -p "$(RESOURCES_DIR)/Base.lproj" "$(RESOURCES_DIR)/English.lproj" "$(RESOURCES_DIR)/en.lproj" "$(RESOURCES_DIR)/zh-Hant.lproj" "$(RESOURCES_DIR)/zh_TW.lproj"
	mkdir -p "$(PREFERENCES_CONTENTS_DIR)/Resources/en.lproj" "$(PREFERENCES_CONTENTS_DIR)/Resources/zh-Hant.lproj"
	cp resources/Base.lproj/InfoPlist.strings "$(RESOURCES_DIR)/Base.lproj/InfoPlist.strings"
	cp resources/English.lproj/InfoPlist.strings "$(RESOURCES_DIR)/English.lproj/InfoPlist.strings"
	cp resources/en.lproj/InfoPlist.strings "$(RESOURCES_DIR)/en.lproj/InfoPlist.strings"
	cp resources/en.lproj/Localizable.strings "$(RESOURCES_DIR)/en.lproj/Localizable.strings"
	cp resources/en.lproj/Localizable.strings "$(PREFERENCES_CONTENTS_DIR)/Resources/en.lproj/Localizable.strings"
	cp resources/zh-Hant.lproj/InfoPlist.strings "$(RESOURCES_DIR)/zh-Hant.lproj/InfoPlist.strings"
	cp resources/zh-Hant.lproj/Localizable.strings "$(RESOURCES_DIR)/zh-Hant.lproj/Localizable.strings"
	cp resources/zh-Hant.lproj/Localizable.strings "$(PREFERENCES_CONTENTS_DIR)/Resources/zh-Hant.lproj/Localizable.strings"
	cp resources/zh_TW.lproj/InfoPlist.strings "$(RESOURCES_DIR)/zh_TW.lproj/InfoPlist.strings"
	for file in "$(RESOURCES_DIR)"/*.lproj/InfoPlist.strings; do iconv -f UTF-8 -t UTF-16 "$$file" > "$$file.tmp" && mv "$$file.tmp" "$$file"; done
	cp resources/PurrTypePreferencesInfo.plist "$(PREFERENCES_CONTENTS_DIR)/Info.plist"
	cp resources/pinyin_seed.tsv "$(RESOURCES_DIR)/pinyin_seed.tsv"
	cp resources/sucheng_order_guards.tsv "$(RESOURCES_DIR)/sucheng_order_guards.tsv"
	cp resources/smart_phrases.tsv "$(RESOURCES_DIR)/smart_phrases.tsv"
	cp resources/association_phrases.tsv "$(RESOURCES_DIR)/association_phrases.tsv"
	cp "$(ASSOCIATION_GENERATED_INDEX)" "$(RESOURCES_DIR)/association_generated.index"
	cp $(CANDIDATE_INDEXES) "$(RESOURCES_DIR)/CandidateTables/"
	cp resources/traditional_compatibility.tsv "$(RESOURCES_DIR)/traditional_compatibility.tsv"
	cp resources/sucheng_first_pages.tsv "$(RESOURCES_DIR)/sucheng_first_pages.tsv"
	PURRTYPE_ICON_SOURCE=resources/PurrType.png ./scripts/generate-icon.sh "$(RESOURCES_DIR)/PurrType.icns"
	cp third_party/rime-cangjie/AUTHORS third_party/rime-cangjie/LICENSE "$(RESOURCES_DIR)/RimeCangjie/"
	cp third_party/rime-pinyin/AUTHORS third_party/rime-pinyin/LICENSE "$(RESOURCES_DIR)/RimePinyin/"
	cp third_party/ibus-table-chinese/LICENSE third_party/ibus-table-chinese/README.md "$(RESOURCES_DIR)/IBusTableChinese/"
	cp third_party/hkscs/HKSCS2016.json third_party/hkscs/README.md third_party/hkscs/TERMS.md "$(RESOURCES_DIR)/HKSCS/"
	cp LICENSE "$(RESOURCES_DIR)/Legal/LICENSE.txt"
	cp docs/CREDITS.md "$(RESOURCES_DIR)/Legal/CREDITS.md"
	cp docs/PRIVACY_POLICY.md "$(RESOURCES_DIR)/Legal/PRIVACY_POLICY.md"
	cp docs/LICENSE_AUDIT.md "$(RESOURCES_DIR)/Legal/LICENSE_AUDIT.md"
	cp third_party/mcbopomofo/LICENSE.txt "$(RESOURCES_DIR)/Legal/MCBOPOMOFO_LICENSE.txt"
	cp $(PREFERENCE_COVER_RESOURCES) "$(PREFERENCES_CONTENTS_DIR)/Resources/PreferenceCovers/"
	printf 'APPL????' > "$(CONTENTS_DIR)/PkgInfo"
	cp "$(RESOURCES_DIR)/PurrType.icns" "$(PREFERENCES_CONTENTS_DIR)/Resources/PurrType.icns"
	printf 'APPL????' > "$(PREFERENCES_CONTENTS_DIR)/PkgInfo"
	clang $(OBJCFLAGS) $(PREFERENCES_APP_SOURCES) -framework Cocoa -framework CoreImage -o "$(PREFERENCES_MACOS_DIR)/$(PREFERENCES_EXECUTABLE_NAME)"
	xattr -cr "$(PREFERENCES_BUNDLE_DIR)" 2>/dev/null || true
	codesign --force --sign - "$(PREFERENCES_BUNDLE_DIR)"
	clang $(OBJCFLAGS) $(APP_SOURCES) $(FRAMEWORKS) -o "$(MACOS_DIR)/$(EXECUTABLE_NAME)"
	xattr -cr "$(BUNDLE_DIR)" 2>/dev/null || true
	codesign --force --sign - "$(BUNDLE_DIR)"
	if [ -x "$(LSREGISTER)" ] && [ -d "$(BUNDLE_DIR)" ]; then app="$$(cd "$(BUILD_DIR)" && pwd)/$(BUNDLE_NAME)"; "$(LSREGISTER)" -u "$$app" >/dev/null 2>&1 || true; "$(LSREGISTER)" -gc >/dev/null 2>&1 || true; fi

test: $(TEST_SOURCES) $(STARTUP_BENCHMARK_SOURCES) $(INPUT_STATE_TEST_SOURCES) $(INPUT_BEHAVIOR_TEST_SOURCES) $(CANDIDATE_PANEL_TEST_SOURCES) $(TYPING_SIMULATION_TEST_SOURCES) $(PREFERENCES_TEST_SOURCES) $(BUNDLE_TEST_SOURCES) src/PurrTypeInputState.h src/PurrTypeInputBehavior.h src/PurrTypeCandidatePanel.h src/PurrTypePreferencesWindowController.h src/PurrTypePreferencesStore.h docs/typing/one_hour_typing_corpus.md resources/en.lproj/Localizable.strings resources/zh-Hant.lproj/Localizable.strings resources/pinyin_seed.tsv resources/sucheng_order_guards.tsv resources/smart_phrases.tsv resources/association_phrases.tsv $(ASSOCIATION_GENERATED_INDEX) $(CANDIDATE_INDEXES) resources/traditional_compatibility.tsv resources/sucheng_first_pages.tsv third_party/hkscs/HKSCS2016.json
	mkdir -p "$(BUILD_DIR)"
	clang $(OBJCFLAGS) $(TEST_SOURCES) $(ENGINE_TEST_FRAMEWORKS) -o "$(BUILD_DIR)/PurrTypeEngineTests"
	"$(BUILD_DIR)/PurrTypeEngineTests"
	clang $(OBJCFLAGS) $(STARTUP_BENCHMARK_SOURCES) $(ENGINE_TEST_FRAMEWORKS) -o "$(BUILD_DIR)/PurrTypeEngineStartupBenchmark"
	"$(BUILD_DIR)/PurrTypeEngineStartupBenchmark"
	clang $(OBJCFLAGS) -Isrc $(INPUT_STATE_TEST_SOURCES) -framework Foundation -o "$(BUILD_DIR)/PurrTypeInputStateTests"
	"$(BUILD_DIR)/PurrTypeInputStateTests"
	clang $(OBJCFLAGS) $(INPUT_BEHAVIOR_TEST_SOURCES) -framework Cocoa -o "$(BUILD_DIR)/PurrTypeInputBehaviorTests"
	"$(BUILD_DIR)/PurrTypeInputBehaviorTests"
	clang $(OBJCFLAGS) $(CANDIDATE_PANEL_TEST_SOURCES) -framework Cocoa -o "$(BUILD_DIR)/PurrTypeCandidatePanelTests"
	"$(BUILD_DIR)/PurrTypeCandidatePanelTests"
	clang $(OBJCFLAGS) $(TYPING_SIMULATION_TEST_SOURCES) -framework Cocoa -o "$(BUILD_DIR)/PurrTypeTypingSimulationTests"
	"$(BUILD_DIR)/PurrTypeTypingSimulationTests"
	mkdir -p "$(BUILD_DIR)/en.lproj" "$(BUILD_DIR)/zh-Hant.lproj"
	cp resources/en.lproj/Localizable.strings "$(BUILD_DIR)/en.lproj/Localizable.strings"
	cp resources/zh-Hant.lproj/Localizable.strings "$(BUILD_DIR)/zh-Hant.lproj/Localizable.strings"
	clang $(OBJCFLAGS) $(PREFERENCES_TEST_SOURCES) -framework Cocoa -framework CoreImage -o "$(BUILD_DIR)/PurrTypePreferencesTests"
	"$(BUILD_DIR)/PurrTypePreferencesTests"
	clang $(OBJCFLAGS) $(BUNDLE_TEST_SOURCES) -framework Foundation -o "$(BUILD_DIR)/PurrTypeBundleTests"
	"$(BUILD_DIR)/PurrTypeBundleTests"

audit-full-bible: $(FULL_BIBLE_AUDIT_SOURCES) src/PurrTypeInputBehavior.h docs/typing/full_bible_typing_corpus.md resources/pinyin_seed.tsv resources/sucheng_order_guards.tsv resources/smart_phrases.tsv resources/association_phrases.tsv $(ASSOCIATION_GENERATED_INDEX) $(CANDIDATE_INDEXES) resources/traditional_compatibility.tsv resources/sucheng_first_pages.tsv
	mkdir -p "$(BUILD_DIR)"
	clang $(OBJCFLAGS) $(FULL_BIBLE_AUDIT_SOURCES) -framework Cocoa -o "$(BUILD_DIR)/PurrTypeFullBibleTypingAudit"
	"$(BUILD_DIR)/PurrTypeFullBibleTypingAudit"

audit-sucheng-ranking: $(CLASSIC_SUCHENG_RANKING_AUDIT_SOURCES) resources/sucheng_first_pages.tsv resources/sucheng_order_guards.tsv $(QUICK_CANDIDATE_INDEX)
	mkdir -p "$(BUILD_DIR)"
	clang $(OBJCFLAGS) $(CLASSIC_SUCHENG_RANKING_AUDIT_SOURCES) $(ENGINE_TEST_FRAMEWORKS) -o "$(BUILD_DIR)/PurrTypeClassicSuchengRankingAudit"
	"$(BUILD_DIR)/PurrTypeClassicSuchengRankingAudit"

audit-classic-sucheng-ranking: audit-sucheng-ranking

audit-associations: $(ASSOCIATION_AUDIT_SOURCES) resources/association_phrases.tsv $(ASSOCIATION_GENERATED_TSV) $(ASSOCIATION_GENERATED_INDEX) $(CANDIDATE_INDEXES) resources/pinyin_seed.tsv resources/sucheng_order_guards.tsv
	mkdir -p "$(BUILD_DIR)"
	clang $(OBJCFLAGS) $(ASSOCIATION_AUDIT_SOURCES) $(ENGINE_TEST_FRAMEWORKS) -o "$(BUILD_DIR)/PurrTypeAssociationAudit"
	"$(BUILD_DIR)/PurrTypeAssociationAudit"

audit-hkscs-coverage: scripts/audit-hkscs-coverage.rb third_party/hkscs/HKSCS2016.json third_party/ibus-table-chinese/cangjie5.txt third_party/ibus-table-chinese/quick-classic.txt third_party/rime-cangjie/cangjie5.base.dict.yaml third_party/rime-cangjie/cangjie5.extended.dict.yaml
	ruby scripts/audit-hkscs-coverage.rb

audit-legacy-parity: scripts/audit-legacy-parity.rb resources/sucheng_first_pages.tsv resources/sucheng_position_anchors.tsv third_party/ibus-table-chinese/cangjie5.txt third_party/ibus-table-chinese/quick-classic.txt third_party/cin-tables/mscj3.cin
	ruby scripts/audit-legacy-parity.rb

audit-version-consistency: scripts/audit-version-consistency.rb Makefile resources/Info.plist resources/PurrTypePreferencesInfo.plist README.md docs/BUILD_AND_INSTALL.md docs/MANUAL_QA.md docs/TROUBLESHOOTING.md packaging/README.txt docs/CHANGELOG.md
	ruby scripts/audit-version-consistency.rb

audit-version: audit-version-consistency

license-audit: package scripts/audit-license-notices.sh docs/PRIVACY_POLICY.md docs/LICENSE_AUDIT.md docs/MANUAL_QA.md docs/CREDITS.md LICENSE
	sh scripts/audit-license-notices.sh "$(PKG_PATH)"

dump-sucheng-pages: scripts/dump-sucheng-pages.rb resources/sucheng_order_guards.tsv third_party/ibus-table-chinese/quick-classic.txt
	ruby scripts/dump-sucheng-pages.rb $(CODES)

update-sucheng-snapshot: $(SUCHENG_SNAPSHOT_SOURCES) resources/pinyin_seed.tsv resources/sucheng_order_guards.tsv resources/smart_phrases.tsv resources/association_phrases.tsv resources/association_generated.tsv resources/traditional_compatibility.tsv $(CANDIDATE_INDEXES)
	mkdir -p "$(BUILD_DIR)"
	clang $(OBJCFLAGS) $(SUCHENG_SNAPSHOT_SOURCES) $(ENGINE_TEST_FRAMEWORKS) -o "$(BUILD_DIR)/SuchengSnapshot"
	"$(BUILD_DIR)/SuchengSnapshot" > resources/sucheng_first_pages.tsv

update-association-seeds: scripts/generate-association-seeds.rb resources/association_phrases.tsv resources/smart_phrases.tsv docs/typing/one_hour_typing_corpus.md docs/typing/full_bible_typing_corpus.md third_party/rime-cangjie/cangjie5.base.dict.yaml third_party/rime-cangjie/cangjie5.extended.dict.yaml third_party/rime-pinyin/luna_pinyin.dict.yaml third_party/mcbopomofo/associated-phrases-v2.txt third_party/ibus-table-chinese/cangjie5.txt
	ruby scripts/generate-association-seeds.rb
	ruby "$(ASSOCIATION_INDEX_SCRIPT)" "$(ASSOCIATION_GENERATED_TSV)" "$(ASSOCIATION_GENERATED_INDEX)"

$(ASSOCIATION_GENERATED_INDEX): $(ASSOCIATION_INDEX_SCRIPT) $(ASSOCIATION_GENERATED_TSV)
	ruby "$(ASSOCIATION_INDEX_SCRIPT)" "$(ASSOCIATION_GENERATED_TSV)" "$(ASSOCIATION_GENERATED_INDEX)"

$(QUICK_CANDIDATE_INDEX): $(CANDIDATE_INDEX_SCRIPT) third_party/ibus-table-chinese/quick-classic.txt
	ruby "$(CANDIDATE_INDEX_SCRIPT)" quick "$@" third_party/ibus-table-chinese/quick-classic.txt

$(CANGJIE_CANDIDATE_INDEX): $(CANDIDATE_INDEX_SCRIPT) third_party/ibus-table-chinese/cangjie5.txt third_party/rime-cangjie/cangjie5.base.dict.yaml third_party/rime-cangjie/cangjie5.extended.dict.yaml
	ruby "$(CANDIDATE_INDEX_SCRIPT)" cangjie "$@" third_party/ibus-table-chinese/cangjie5.txt third_party/rime-cangjie/cangjie5.base.dict.yaml third_party/rime-cangjie/cangjie5.extended.dict.yaml

$(PINYIN_CANDIDATE_INDEX): $(CANDIDATE_INDEX_SCRIPT) resources/pinyin_seed.tsv third_party/rime-pinyin/luna_pinyin.dict.yaml third_party/ibus-table-chinese/quick-classic.txt
	ruby "$(CANDIDATE_INDEX_SCRIPT)" pinyin "$@" resources/pinyin_seed.tsv third_party/rime-pinyin/luna_pinyin.dict.yaml third_party/ibus-table-chinese/quick-classic.txt

tis-probe: $(TIS_PROBE_SOURCES)
	mkdir -p "$(BUILD_DIR)"
	clang $(OBJCFLAGS) $(TIS_PROBE_SOURCES) -framework Foundation -framework Carbon -o "$(BUILD_DIR)/TISProbe"
	"$(BUILD_DIR)/TISProbe" "$(TIS_ID)"

tis-inspect:
	$(RUN_PURRTYPE_APP) --inspect-input-source

enable:
	$(RUN_INSTALLED_PURRTYPE_APP) --enable-input-source

select:
	$(RUN_INSTALLED_PURRTYPE_APP) --select-input-source

repair-input-source:
	sh scripts/repair-installed-input-source.sh

repair-input-source-select:
	sh scripts/repair-installed-input-source.sh --select

install: build
	./scripts/install-local.sh

uninstall-local:
	./scripts/uninstall-local.sh

uninstall-system:
	./scripts/uninstall-system.sh

reset-learning:
	rm -f "$(LEARNING_PATH)"
	rm -f "$(LEGACY_LEARNING_PATH)"

stop:
	./scripts/stop-running.sh

uninstall-package: $(UNINSTALL_PKG_PATH)

$(UNINSTALL_PKG_PATH): packaging/uninstall-scripts/postinstall
	mkdir -p "$(BUILD_DIR)"
	pkgbuild --nopayload --identifier "$(UNINSTALL_PKG_ID)" --version "$(VERSION)" --scripts packaging/uninstall-scripts "$(UNINSTALL_PKG_PATH)"
	@echo "Uninstall package: $(UNINSTALL_PKG_PATH)"

package: build uninstall-package packaging/README.txt packaging/Uninstall-PurrType.command packaging/scripts/preinstall packaging/scripts/postinstall $(COMPONENT_PLIST) LICENSE docs/CREDITS.md docs/PRIVACY_POLICY.md docs/LICENSE_AUDIT.md docs/MANUAL_QA.md
	rm -rf "$(PKGROOT_DIR)" "$(DMGROOT_DIR)" "$(PKG_PATH)" "$(DMG_PATH)"
	mkdir -p "$(PKGROOT_DIR)/Library/Input Methods" "$(DMGROOT_DIR)"
	COPYFILE_DISABLE=1 ditto --norsrc "$(BUNDLE_DIR)" "$(PKGROOT_DIR)/Library/Input Methods/$(BUNDLE_NAME)"
	pkgbuild --root "$(PKGROOT_DIR)" --identifier "$(PKG_ID)" --version "$(VERSION)" --scripts packaging/scripts --component-plist "$(COMPONENT_PLIST)" --install-location "/" "$(PKG_PATH)"
	if [ -x "$(LSREGISTER)" ] && [ -d "$(PKGROOT_DIR)/Library/Input Methods/$(BUNDLE_NAME)" ]; then app="$$(cd "$(PKGROOT_DIR)/Library/Input Methods" && pwd)/$(BUNDLE_NAME)"; "$(LSREGISTER)" -u "$$app" >/dev/null 2>&1 || true; "$(LSREGISTER)" -gc >/dev/null 2>&1 || true; fi
	cp "$(PKG_PATH)" "$(DMGROOT_DIR)/Install PurrType.pkg"
	cp "$(UNINSTALL_PKG_PATH)" "$(DMGROOT_DIR)/Uninstall PurrType.pkg"
	cp packaging/README.txt "$(DMGROOT_DIR)/README.txt"
	hdiutil create -volname "PurrType" -srcfolder "$(DMGROOT_DIR)" -ov -format UDZO "$(DMG_PATH)"
	if [ -x "$(LSREGISTER)" ]; then for parent in "$(BUILD_DIR)" "$(PKGROOT_DIR)/Library/Input Methods"; do if [ -d "$$parent/$(BUNDLE_NAME)" ]; then app="$$(cd "$$parent" && pwd)/$(BUNDLE_NAME)"; "$(LSREGISTER)" -u "$$app" >/dev/null 2>&1 || true; fi; done; "$(LSREGISTER)" -gc >/dev/null 2>&1 || true; fi
	@echo "Package: $(PKG_PATH)"
	@echo "DMG: $(DMG_PATH)"

release-artifacts: package checksums provenance

checksums: package
	shasum -a 256 "$(PKG_PATH)" "$(UNINSTALL_PKG_PATH)" "$(DMG_PATH)" > "$(CHECKSUMS_PATH)"
	@echo "Checksums: $(CHECKSUMS_PATH)"

provenance: package
	ruby scripts/write-release-provenance.rb "$(VERSION)" "$(PROVENANCE_PATH)" "$(PKG_PATH)" "$(UNINSTALL_PKG_PATH)" "$(DMG_PATH)"
	@echo "Provenance: $(PROVENANCE_PATH)"

check-signing-identities:
	test -n "$(DEVELOPER_ID_APPLICATION_IDENTITY)" || (echo "Set DEVELOPER_ID_APPLICATION_IDENTITY to the exact Developer ID Application certificate name." >&2; exit 1)
	test -n "$(DEVELOPER_ID_INSTALLER_IDENTITY)" || (echo "Set DEVELOPER_ID_INSTALLER_IDENTITY to the exact Developer ID Installer certificate name." >&2; exit 1)
	security find-identity -v -p codesigning | grep -F "$(DEVELOPER_ID_APPLICATION_IDENTITY)" >/dev/null || (echo "Developer ID Application identity not found: $(DEVELOPER_ID_APPLICATION_IDENTITY)" >&2; exit 1)
	security find-certificate -c "$(DEVELOPER_ID_INSTALLER_IDENTITY)" >/dev/null || (echo "Developer ID Installer certificate not found: $(DEVELOPER_ID_INSTALLER_IDENTITY)" >&2; exit 1)

check-notary-profile:
	xcrun notarytool history --keychain-profile "$(NOTARY_KEYCHAIN_PROFILE)" >/dev/null

signed-package: build packaging/README.txt packaging/scripts/preinstall packaging/scripts/postinstall $(COMPONENT_PLIST) check-signing-identities
	rm -rf "$(PKGROOT_DIR)" "$(UNSIGNED_RELEASE_PKG_PATH)" "$(SIGNED_PKG_PATH)"
	codesign --force --timestamp --options runtime --sign "$(DEVELOPER_ID_APPLICATION_IDENTITY)" "$(PREFERENCES_BUNDLE_DIR)"
	codesign --force --timestamp --options runtime --sign "$(DEVELOPER_ID_APPLICATION_IDENTITY)" "$(BUNDLE_DIR)"
	codesign --verify --deep --strict --verbose=2 "$(BUNDLE_DIR)"
	mkdir -p "$(PKGROOT_DIR)/Library/Input Methods"
	COPYFILE_DISABLE=1 ditto --norsrc "$(BUNDLE_DIR)" "$(PKGROOT_DIR)/Library/Input Methods/$(BUNDLE_NAME)"
	pkgbuild --root "$(PKGROOT_DIR)" --identifier "$(PKG_ID)" --version "$(VERSION)" --scripts packaging/scripts --component-plist "$(COMPONENT_PLIST)" --install-location "/" "$(UNSIGNED_RELEASE_PKG_PATH)"
	productsign --sign "$(DEVELOPER_ID_INSTALLER_IDENTITY)" "$(UNSIGNED_RELEASE_PKG_PATH)" "$(SIGNED_PKG_PATH)"
	spctl -a -vv -t install "$(SIGNED_PKG_PATH)"
	@echo "Signed package: $(SIGNED_PKG_PATH)"

signed-uninstall-package: uninstall-package check-signing-identities
	rm -f "$(UNSIGNED_UNINSTALL_PKG_PATH)" "$(SIGNED_UNINSTALL_PKG_PATH)"
	cp "$(UNINSTALL_PKG_PATH)" "$(UNSIGNED_UNINSTALL_PKG_PATH)"
	productsign --sign "$(DEVELOPER_ID_INSTALLER_IDENTITY)" "$(UNSIGNED_UNINSTALL_PKG_PATH)" "$(SIGNED_UNINSTALL_PKG_PATH)"
	spctl -a -vv -t install "$(SIGNED_UNINSTALL_PKG_PATH)"
	@echo "Signed uninstall package: $(SIGNED_UNINSTALL_PKG_PATH)"

signed-dmg: signed-package signed-uninstall-package packaging/README.txt LICENSE docs/CREDITS.md docs/PRIVACY_POLICY.md docs/LICENSE_AUDIT.md docs/MANUAL_QA.md
	rm -rf "$(DMGROOT_DIR)" "$(SIGNED_DMG_PATH)"
	mkdir -p "$(DMGROOT_DIR)"
	cp "$(SIGNED_PKG_PATH)" "$(DMGROOT_DIR)/Install PurrType.pkg"
	cp "$(SIGNED_UNINSTALL_PKG_PATH)" "$(DMGROOT_DIR)/Uninstall PurrType.pkg"
	cp packaging/README.txt "$(DMGROOT_DIR)/README.txt"
	hdiutil create -volname "PurrType" -srcfolder "$(DMGROOT_DIR)" -ov -format UDZO "$(SIGNED_DMG_PATH)"
	codesign --force --timestamp --sign "$(DEVELOPER_ID_APPLICATION_IDENTITY)" "$(SIGNED_DMG_PATH)"
	codesign --verify --verbose=2 "$(SIGNED_DMG_PATH)"
	spctl -a -vv -t open --context context:primary-signature "$(SIGNED_DMG_PATH)"
	@echo "Signed DMG: $(SIGNED_DMG_PATH)"

notarize-dmg: signed-dmg check-notary-profile
	xcrun notarytool submit "$(SIGNED_DMG_PATH)" --keychain-profile "$(NOTARY_KEYCHAIN_PROFILE)" --wait
	xcrun stapler staple "$(SIGNED_DMG_PATH)"
	xcrun stapler validate "$(SIGNED_DMG_PATH)"
	spctl -a -vv -t open --context context:primary-signature "$(SIGNED_DMG_PATH)"
	@echo "Notarized DMG: $(SIGNED_DMG_PATH)"

release-signed: notarize-dmg signed-checksums signed-provenance

signed-checksums: notarize-dmg
	shasum -a 256 "$(SIGNED_PKG_PATH)" "$(SIGNED_UNINSTALL_PKG_PATH)" "$(SIGNED_DMG_PATH)" > "$(SIGNED_CHECKSUMS_PATH)"
	@echo "Signed checksums: $(SIGNED_CHECKSUMS_PATH)"

signed-provenance: notarize-dmg
	ruby scripts/write-release-provenance.rb "$(VERSION)" "$(SIGNED_PROVENANCE_PATH)" "$(SIGNED_PKG_PATH)" "$(SIGNED_UNINSTALL_PKG_PATH)" "$(SIGNED_DMG_PATH)"
	@echo "Signed provenance: $(SIGNED_PROVENANCE_PATH)"

package-smoke: package
	rm -rf "$(PACKAGE_SMOKE_DIR)"
	mkdir -p "$(PACKAGE_SMOKE_DIR)"
	pkgutil --expand-full "$(PKG_PATH)" "$(PACKAGE_SMOKE_DIR)/expanded"
	test -d "$(PACKAGE_SMOKE_APP)"
	test -x "$(PACKAGE_SMOKE_APP)/Contents/MacOS/$(EXECUTABLE_NAME)"
	test -x "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/MacOS/$(PREFERENCES_EXECUTABLE_NAME)"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/en.lproj/Localizable.strings"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/zh-Hant.lproj/Localizable.strings"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/en.lproj/Localizable.strings"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/zh-Hant.lproj/Localizable.strings"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/traditional_compatibility.tsv"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/sucheng_order_guards.tsv"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/association_generated.index"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/association_generated.tsv"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/CandidateTables/cangjie5.index"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/CandidateTables/quick-classic.index"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/CandidateTables/pinyin.index"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/IBusTableChinese/cangjie5.txt"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/IBusTableChinese/quick-classic.txt"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/IBusTableChinese/LICENSE"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/HKSCS/HKSCS2016.json"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/HKSCS/TERMS.md"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/Legal/LICENSE.txt"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/Legal/CREDITS.md"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/Legal/PRIVACY_POLICY.md"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/Legal/LICENSE_AUDIT.md"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/Legal/MCBOPOMOFO_LICENSE.txt"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/PurrType.icns"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/PurrType_sucheng.icns"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/PurrType_new.icns"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/PurrType_cangjie.icns"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/PurrType_pinyin.icns"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PurrType.icns"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/PreferenceCovers"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/PreferenceCovers/pref_cover_general_banner.png"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/PreferenceCovers/pref_cover_input_modes_banner.png"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/PreferenceCovers/pref_cover_typing_banner.png"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/PreferenceCovers/pref_cover_privacy_learning_banner.png"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/PreferenceCovers/pref_cover_about_banner.png"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_general.png"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_input_modes.png"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_typing.png"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_privacy_learning.png"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_about.png"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_general_banner.png"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_input_modes_banner.png"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_typing_banner.png"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_privacy_learning_banner.png"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Resources/PreferenceCovers/pref_cover_about_banner.png"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/RimeCangjie/cangjie5.base.dict.yaml"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/RimeCangjie/cangjie5.extended.dict.yaml"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/RimePinyin/luna_pinyin.dict.yaml"
	test -s "$(PACKAGE_SMOKE_APP)/Contents/Resources/RimePinyin/LICENSE"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/RimeCangjie/cangjie5.dict.yaml"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/RimeCangjie/cangjie5_express.schema.yaml"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/CINTables"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/ranking_overrides.tsv"
	test ! -e "$(PACKAGE_SMOKE_APP)/Contents/Resources/legacy_sucheng_overrides.tsv"
	! pkgutil --payload-files "$(PKG_PATH)" | grep -F '/._'
	test "$$(/usr/libexec/PlistBuddy -c 'Print :TISInputSourceID' "$(PACKAGE_SMOKE_APP)/Contents/Info.plist")" = "$(PURRTYPE_TIS_ID)"
	test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$(PACKAGE_SMOKE_APP)/Contents/Info.plist")" = "PurrType.icns"
	test "$$(/usr/libexec/PlistBuddy -c 'Print :tsInputMethodIconFileKey' "$(PACKAGE_SMOKE_APP)/Contents/Info.plist")" = "PurrType.icns"
	! /usr/libexec/PlistBuddy -c 'Print :ComponentInputModeDict' "$(PACKAGE_SMOKE_APP)/Contents/Info.plist" >/dev/null 2>&1
	test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(PACKAGE_SMOKE_APP)/Contents/Info.plist")" = "$(VERSION)"
	test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$(PACKAGE_SMOKE_APP)/Contents/Info.plist")" = "$(BUNDLE_VERSION)"
	test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Info.plist")" = "$(PURRTYPE_TIS_ID).Preferences"
	test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Info.plist")" = "$(VERSION)"
	test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$(PACKAGE_SMOKE_APP)/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)/Contents/Info.plist")" = "$(BUNDLE_VERSION)"
	hdiutil imageinfo "$(DMG_PATH)" >/dev/null
	test -s "$(DMGROOT_DIR)/Install PurrType.pkg"
	test -s "$(DMGROOT_DIR)/Uninstall PurrType.pkg"
	test -s "$(DMGROOT_DIR)/README.txt"
	test ! -e "$(DMGROOT_DIR)/LICENSE.txt"
	test ! -e "$(DMGROOT_DIR)/ACKNOWLEDGEMENTS.md"
	test ! -e "$(DMGROOT_DIR)/CREDITS.md"
	test ! -e "$(DMGROOT_DIR)/THIRD_PARTY_NOTICES.md"
	test ! -e "$(DMGROOT_DIR)/PRIVACY_POLICY.md"
	test ! -e "$(DMGROOT_DIR)/LICENSE_AUDIT.md"
	test ! -e "$(DMGROOT_DIR)/MANUAL_QA.md"
	pkgutil --expand-full "$(DMGROOT_DIR)/Uninstall PurrType.pkg" "$(PACKAGE_SMOKE_DIR)/uninstall-expanded"
	test -s "$(PACKAGE_SMOKE_DIR)/uninstall-expanded/Scripts/postinstall"
	grep -F "/Library/Input Methods/PurrTypeIM.app" "$(PACKAGE_SMOKE_DIR)/uninstall-expanded/Scripts/postinstall" >/dev/null
	grep -F "pkgutil --forget" "$(PACKAGE_SMOKE_DIR)/uninstall-expanded/Scripts/postinstall" >/dev/null
	! grep -F '$$USER_HOME/Library/Application Support/PurrType' "$(PACKAGE_SMOKE_DIR)/uninstall-expanded/Scripts/postinstall" >/dev/null
	! grep -F '$$USER_HOME/Library/Preferences/org.purrtype.inputmethod.PurrTypeUnified.plist' "$(PACKAGE_SMOKE_DIR)/uninstall-expanded/Scripts/postinstall" >/dev/null
	if [ -x "$(LSREGISTER)" ]; then \
	  build_app="$$(cd "$(BUILD_DIR)" && pwd)/$(BUNDLE_NAME)"; \
	  pkgroot_app="$$(cd "$(PKGROOT_DIR)/Library/Input Methods" && pwd)/$(BUNDLE_NAME)"; \
	  smoke_app="$$(cd "$(PACKAGE_SMOKE_DIR)/expanded/Payload/Library/Input Methods" && pwd)/$(BUNDLE_NAME)"; \
	  build_prefs="$$build_app/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)"; \
	  pkgroot_prefs="$$pkgroot_app/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)"; \
	  smoke_prefs="$$smoke_app/Contents/Resources/$(PREFERENCES_BUNDLE_NAME)"; \
	  rm -rf "$(PACKAGE_SMOKE_DIR)"; \
	  for attempt in 1 2 3 4; do \
	    sleep 2; \
	    for app in "$$build_app" "$$build_prefs" "$$pkgroot_app" "$$pkgroot_prefs" "$$smoke_app" "$$smoke_prefs"; do \
	      "$(LSREGISTER)" -u "$$app" >/dev/null 2>&1 || true; \
	    done; \
	    "$(LSREGISTER)" -gc >/dev/null 2>&1 || true; \
	  done; \
	  ! "$(LSREGISTER)" -dump | /usr/bin/grep -E "$$(pwd)/build/(PurrTypeIM\\.app|pkgroot|package-smoke)"; \
	fi
	@echo "PASS: package smoke $(PKG_PATH) $(DMG_PATH)"

release-preflight: test audit-version audit-sucheng-ranking audit-associations audit-full-bible audit-legacy-parity license-audit package-smoke

clean:
	rm -rf "$(BUILD_DIR)" .build dist
	find . -name .DS_Store -delete
