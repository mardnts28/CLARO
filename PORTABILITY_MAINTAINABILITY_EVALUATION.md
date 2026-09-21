# Testing Portability and Maintainability of the CLARO System

## Abstract

This report evaluates the CLARO mobile application against the portability and maintainability characteristics of ISO/IEC 25010:2011. CLARO is a Flutter application using Firebase services, native device plugins, and a web platform scaffold. The evaluation was performed on 21 September 2026 using Flutter 3.44.4, Dart 3.12.2, macOS 27.0 on darwin-arm64, and Android SDK 36.1.0.

The current implementation successfully passes the automated Flutter test suite with 87/87 tests and produces an Android debug APK. Static analysis reports zero errors and zero warnings when informational diagnostics are treated as non-fatal. However, the project still has 36 informational diagnostics, approximately 10.67% measured line coverage, no integration-test suite, and several portability scenarios that require physical-device or browser execution. The evidence supports strong build portability and functional testability, but only moderate overall maintainability until coverage and deployment-matrix testing are expanded.

## 1. Introduction

### 1.1 Purpose

The purpose of this evaluation is to assess CLARO's portability and maintainability using the ISO/IEC 25010 quality model. The assessment combines repeatable command-line measurements, automated tests, static analysis, build verification, and structural source inspection.

### 1.2 System Under Test

| Property | Current value |
|---|---|
| Application | CLARO v1.0.0+1 |
| Framework | Flutter 3.44.4 |
| Language/runtime | Dart 3.12.2 |
| Backend | Firebase Authentication, Firestore, Cloud Functions |
| Primary target | Android |
| Additional target scaffold | Web |
| Source files | 113 Dart files |
| Source size | 53,430 lines |
| Test files | 16 Dart files |
| Test source size | 2,735 lines |
| Automated test cases | 87 |
| Localization references | 208 |
| Platform-conditional expressions | 4 |
| Native capabilities | Camera, speech-to-text, text-to-speech, TFLite |

### 1.3 Evaluation Environment

| Property | Result |
|---|---|
| Host OS | macOS 27.0, darwin-arm64 |
| Flutter channel | Stable |
| Android SDK | 36.1.0, platform android-36.1 |
| Android emulator tooling | 36.5.11.0 |
| Java | OpenJDK 21.0.10, Android Studio bundled JDK |
| Xcode | 27.0 |
| Chrome | Not installed; browser execution was not available |
| Connected device | macOS desktop device detected |

## 2. Evaluation Method

The evaluation used the following evidence categories:

1. **Portability:** environment diagnostics, Android compilation, platform scaffold inspection, SDK configuration, and platform-conditional code counts.
2. **Installability:** Android artifact generation and dependency resolution.
3. **Replaceability:** inspection of the data/service organization, localization resources, and runtime-loaded assets.
4. **Maintainability:** static analysis, automated tests, LCOV coverage, source metrics, async-safety checks, and automated analyzer fixes.
5. **Evidence boundaries:** claims requiring physical devices, browser execution, Firebase Test Lab, release signing, upgrade installation, or accessibility settings were not marked as completed without direct execution evidence.

## 3. Commands Executed

### 3.1 Environment and project metrics

```bash
flutter --version
flutter doctor -v
find lib -name '*.dart' | wc -l
find lib -name '*.dart' -exec cat {} + | wc -l
find test -name '*.dart' | wc -l
find test -name '*.dart' -exec cat {} + | wc -l
grep -R -E 'Platform\.isAndroid|Platform\.isIOS|kIsWeb|defaultTargetPlatform' lib --include='*.dart' | wc -l
grep -R -E 'AppLocalizations|S\.of|S\.current' lib --include='*.dart' | wc -l
```

### 3.2 Static analysis

```bash
flutter analyze
flutter analyze --no-fatal-infos
grep -c 'use_build_context_synchronously' analyzer-output.txt
dart fix --dry-run
dart fix --apply
```

The automated Dart cleanup applied 230 mechanical fixes across 37 files. The remaining analyzer output consists of 36 informational findings: 23 `avoid_print` findings, 7 constant naming findings, and 6 deprecated Radio API findings. There are zero errors, zero warnings, and zero `use_build_context_synchronously` findings. The default `flutter analyze` command still returns a non-zero status because informational findings are treated as fatal by the command; `flutter analyze --no-fatal-infos` returns exit code 0.

### 3.3 Automated tests and coverage

```bash
flutter test
flutter test --coverage
awk -F: '/^SF:/{files++} /^LF:/{lf+=$2} /^LH:/{lh+=$2} END{printf "files=%d lines_found=%d lines_hit=%d coverage=%.2f%%\n", files, lf, lh, (lf ? 100*lh/lf : 0)}' coverage/lcov.info
```

### 3.4 Build and dependency verification

```bash
flutter build apk --debug
flutter pub get
flutter pub outdated --no-dependency-overrides
```

### 3.5 Structural inspection

```bash
grep -R 'try {' lib --include='*.dart' | wc -l
grep -R -E 'print\(|debugPrint\(' lib --include='*.dart' | wc -l
grep -R -E 'class .*Exception|class .*Error' lib --include='*.dart' | wc -l
find web -maxdepth 1 -type f
find lib/generated/l10n -maxdepth 1 -type f
```

## 4. Portability Evaluation

### 4.1 Adaptability

#### 4.1.1 Android compilation

**Result: Pass.** The command `flutter build apk --debug` completed successfully and generated `build/app/outputs/flutter-apk/app-debug.apk`. The final observed Gradle build time was approximately 8 seconds after dependencies were available.

The build emitted a forward-compatibility notice for the `cloud_functions`, `flutter_tts`, and `mobile_scanner` plugins because they currently apply the Kotlin Gradle Plugin pattern flagged by newer Flutter tooling. This notice did not prevent compilation, but it is a portability maintenance item for a future Flutter upgrade.

#### 4.1.2 Platform support and isolation

The project contains Android and web platform files. The iOS directory is absent by project decision, so iOS portability was not tested and must not be represented as a passing target. Chrome is not installed on the evaluation host, so a web build and browser smoke test were not executed.

Only four platform-conditional expressions were found in the Dart source. Relative to 53,430 source lines, this is approximately 0.0075%. This supports a strong platform-abstraction result for the Dart layer, although plugin behavior still requires platform-specific device testing.

#### 4.1.3 Android SDK configuration

The Android module delegates `compileSdk`, `minSdk`, and `targetSdk` to the Flutter Gradle extension. The installed Android toolchain is platform android-36.1 with build-tools 36.1.0. The project has previously resolved Flutter defaults of min SDK 24 and compile/target SDK 36; this should be rechecked whenever the Flutter SDK changes.

#### 4.1.4 Responsive and accessibility portability

The source uses Flutter responsive primitives including `MediaQuery`, `LayoutBuilder`, `Flexible`, `Expanded`, `SafeArea`, and `SingleChildScrollView`. This is structural evidence only. No physical-device matrix was executed for 16:9, 19.5:9, 20:9, cutouts, large-font accessibility settings, or tablet layouts. Those scenarios remain required for a complete portability claim.

### 4.2 Installability

**Android artifact result: Pass.** A standard debug APK was generated successfully. This verifies compilation and artifact generation, but not a clean installation time, release AAB signing, permission flow, upgrade migration, or uninstall behavior.

**Dependency result: Pass with maintenance items.** Dependency resolution completed successfully. `flutter pub outdated` reported 42 packages with newer versions available during dependency resolution; 25 dependencies were constrained below the latest resolvable major versions. This is not a build failure, but it reduces long-term portability and should be managed through scheduled dependency upgrades.

### 4.3 Replaceability

The project separates screens, services, data services, repositories, models, and core utilities. This provides a useful replacement boundary for Firebase-backed operations, but the application is not fully decoupled through interfaces for every external service. Replaceability is therefore assessed as **moderate**, not high.

Flutter localization resources are generated for English and Tagalog. The 208 localization references and standard Flutter localization mechanism support extension to additional languages. TFLite assets are loaded at runtime, which supports model replacement without changing the application architecture, provided the model contract remains compatible.

### 4.4 Portability summary

| Sub-characteristic | Evidence | Assessment |
|---|---|---|
| Adaptability | Android build passes; web scaffold exists; four platform-conditionals | High for verified Android/Dart scope |
| Installability | Debug APK generated; dependency resolution succeeds | Moderate until install/upgrade tests are executed |
| Replaceability | Layered data/services and runtime-loaded assets | Moderate |
| Overall portability | Strong Android build portability, incomplete device/browser evidence | Moderate-high |

## 5. Maintainability Evaluation

### 5.1 Modularity

The current source tree contains 113 Dart files and is divided across presentation, service, data, core, widget, model, and generated-localization areas. This decomposition supports separation of responsibilities. However, several screen files remain large and combine UI, state, navigation, and service coordination. Large screens increase change impact and should be decomposed into view models/controllers and smaller widgets over time.

**Assessment: Moderate-high.**

### 5.2 Reusability

Reusable assets include shared widgets, core utility functions, service classes, data models, localization infrastructure, and runtime-loaded ML assets. The service and utility organization supports reuse, but many services remain application-specific and are not packaged as independent components.

**Assessment: Moderate-high.**

### 5.3 Analysability and diagnostic quality

The latest analyzer state is:

| Diagnostic category | Result |
|---|---:|
| Errors | 0 |
| Warnings | 0 |
| Async-context violations | 0 |
| Informational findings | 36 |
| `avoid_print` findings | 23 |
| Constant naming findings | 7 |
| Deprecated Radio API findings | 6 |

The project includes extensive error handling, but the use of informal printing remains a diagnostic limitation. Production observability would improve through structured logging with event context, error codes, timestamps, and Crashlytics breadcrumbs.

**Assessment: Moderate-high.**

### 5.4 Modifiability

A failed onboarding test was corrected to reflect the current product contract: name, date of birth, and avatar are required before proceeding. The remaining async-context and nullability warnings were fixed, and 230 additional mechanical analyzer fixes were applied. These changes were validated by the complete test suite and Android build.

The codebase remains exposed to plugin API evolution, particularly the Kotlin Gradle Plugin migration notice and six deprecated Radio API usages.

**Assessment: High for current verified changes; moderate risk for future Flutter/plugin upgrades.**

### 5.5 Testability

The final automated test run produced:

| Metric | Result |
|---|---:|
| Test files | 16 |
| Tests executed | 87 |
| Tests passed | 87 |
| Tests failed | 0 |
| Pass rate | 100% |
| Line coverage | 10.67% |
| Instrumented files in LCOV | 104 |
| Lines found in LCOV | 16,856 |
| Lines hit in LCOV | 1,799 |
| Integration tests | 0 |

The `flutter_tts` plugin reports `MissingPluginException` messages during widget tests because native plugin hosts are unavailable in that environment. The messages are handled and do not fail the test suite.

The 100% pass rate demonstrates regression stability for the existing test set. The 10.67% overall line coverage is below a 70%–80% target and does not support a high-confidence claim for untested screens, widgets, native integrations, or end-to-end workflows.

**Assessment: Moderate.**

## 6. Consolidated ISO/IEC 25010 Assessment

| Quality characteristic | Sub-characteristic | Assessment |
|---|---|---:|
| Portability | Adaptability | High for verified Android/Dart scope |
| Portability | Installability | Moderate; artifact verified, installation lifecycle pending |
| Portability | Replaceability | Moderate |
| Maintainability | Modularity | Moderate-high |
| Maintainability | Reusability | Moderate-high |
| Maintainability | Analysability | Moderate-high |
| Maintainability | Modifiability | High for verified changes |
| Maintainability | Testability | Moderate |

The evidence supports an overall classification of **moderate-high**, with the strongest results in Android compilation, automated regression testing, platform abstraction, and analyzer warning removal. The classification should not be interpreted as full cross-platform certification because iOS, browser execution, physical-device accessibility, clean installation, upgrade migration, and integration testing were not executed.

## 7. Limitations and Risks

1. The iOS project is absent, so iOS portability is outside the tested scope.
2. Chrome is unavailable; web compilation and browser behavior were not verified.
3. No Firebase Test Lab or physical-device matrix was executed.
4. No measured clean-install, upgrade, uninstall, or permission-flow test was performed.
5. No release AAB signing or production deployment was verified.
6. Overall coverage is 10.67%, below the proposed 70%–80% target.
7. No integration or end-to-end tests are currently included.
8. The default analyzer command returns non-zero because informational findings remain, although there are zero errors and warnings and `--no-fatal-infos` passes.
9. Kotlin Gradle Plugin migration notices remain for three plugins.
10. Cyclomatic complexity, Halstead volume, maintainability index, and formal coupling/cohesion scores were not calculated; they require a dedicated metrics tool or script.

## 8. Recommendations

| Priority | Recommendation | Rationale |
|---|---|---|
| High | Add integration tests for authentication, scanning, product comparison, offline sync, and onboarding | Raises confidence beyond isolated unit/widget tests |
| High | Increase core business-logic coverage toward 70%–80% | Current measured coverage is 10.67% overall |
| High | Execute Android device/API and font-scale matrix tests | Verifies real portability, accessibility, and plugin behavior |
| Medium | Add browser CI for the web target | Confirms that the web scaffold is actually buildable and usable |
| Medium | Replace remaining `print` calls with structured logging | Improves production diagnosis and traceability |
| Medium | Replace deprecated Radio APIs and update affected plugins | Reduces future Flutter migration risk |
| Medium | Add release AAB, clean-install, upgrade, and uninstall checks | Verifies installability beyond debug compilation |
| Low | Introduce interfaces for external repositories and services | Improves backend replaceability and test isolation |
| Low | Measure complexity and maintainability index in CI | Makes modifiability claims reproducible |

## 9. Conclusion

The current CLARO checkout demonstrates a successful Android build and a fully passing automated test suite of 87 tests. The Dart layer has very low explicit platform branching, and the project structure provides a reasonable modular foundation. Analyzer warnings and async-context violations identified during retesting were removed, and automated analyzer fixes reduced the remaining diagnostic output to 36 informational findings.

The principal maintainability limitation is test depth: measured line coverage is 10.67%, with no integration tests. The principal portability limitations are the absence of iOS, unavailable Chrome execution, and the lack of physical-device, accessibility, installation, upgrade, and network-matrix tests. Consequently, CLARO currently supports a defensible **moderate-high** ISO/IEC 25010 assessment for the verified scope, but not a claim of complete cross-platform or high-coverage certification.

**Evaluation date:** 21 September 2026  
**Framework:** Flutter 3.44.4 / Dart 3.12.2  
**Standard:** ISO/IEC 25010:2011
