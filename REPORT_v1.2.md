# Technical Quality Evaluation Report (v1.2): CLARO Mobile Application

**Evaluation Standard Baseline:** Evaluated using measures adapted from **ISO/IEC 25010:2023** sub-characteristics (Measurement approach adapted from ISO/IEC 25023; official ISO/IEC 25023 text not available).  
**Notice:** This report does not claim official ISO/IEC conformance, compliance, or certification. It represents an objective developer-side technical evaluation using reproducible automated tools, test suites, AST dependency parsers, and source inspections.

---

## 0. Evaluation Environment & Execution Metadata

| Parameter | Recorded Value |
| :--- | :--- |
| **Audit Date & Timestamp** | `2026-10-26 17:03:42 PST` (Verification / v1.2 generation) |
| **Run 1 Baseline Commit** | `b8436909054b78aa308d660b1dcc32e251389b10` (`2026-10-23 10:12:06 +0800`) |
| **Threshold Lock Commit** | `9a3519668c69f236a2b2ea50253fb228eaef74e2` (`2026-10-26 15:42:35 +0800`) |
| **Run 1 Evidence Frozen Tag** | `eval-run1` (`91fe403`, `2026-10-26 16:15:28 +0800`) |
| **Flutter Version** | Flutter 3.44.4 (Channel stable, Framework revision `ad70ec4617`, Engine hash `700aebeca4`) |
| **Dart SDK Version** | Dart 3.12.2 (DevTools 2.57.0) |
| **Host System** | macOS (Darwin 24.3.0, Apple Silicon) |
| **Audited Evidence Root** | `evidence/` (Relative paths used throughout this report) |

---

## 1. Corrections to v1 & Audit Log

The following table records all corrections, re-measurements, and methodological disclosures identified during the verification audit:

| Item | v1 Claim | Corrected / Measured Value (v1.2) | Methodological Reason & Evidence | Evidence Artifact |
| :--- | :--- | :--- | :--- | :--- |
| **A1. Baseline Test Count & 10.67% Origin** | 87 tests / 10.67% coverage referenced in earlier test plan | **160 tests** across 32 test files (**0 tests added post-lock**) | The 87-test / 10.67% figure originated in historical documentation (`PORTABILITY_MAINTAINABILITY_EVALUATION.md`) at commit `385be19` (2026-09-22). Commits `9f6fd41` through `b843690` added 16 test files. Commit `b843690` (`2026-10-23 10:12:06 +0800`) preceded the threshold lock at `9a35196` (`2026-10-26 15:42:35 +0800`). Tests were added **before** the lock, raising the suite to 160 tests; **zero tests were added after the lock**. | [evidence/run1_verification/a1_test_count_discrepancy.txt](evidence/run1_verification/a1_test_count_discrepancy.txt) |
| **A2. Net Line Coverage & LF Replacement** | 15.89% (3,024 / 19,029 lines across 119 files in lcov); v1.1 estimated 14.46% (1,881 est. lines) | **15.21%** (3,024 / 19,884 lines across all 128 non-generated files) | Replaced the heuristic 1,881-line estimate with exact instrumentation via temporary measurement aid on branch `measurement-aid/coverage-lf` (reverted and deleted). Measured exact LF across the 9 un-imported files is **855 lines**. Corrected net coverage across all 128 non-generated files is 3,024 / (19,029 + 855) = **15.21%**. Result remains **FAIL** against locked 70.0% threshold. | [evidence/run1_verification/item2_real_lf_measurement.txt](evidence/run1_verification/item2_real_lf_measurement.txt) |
| **A3. Analyzer Suppressions & Ignore Audit** | 0 issues found (no caveats stated) | **0 diagnostics reported**, with **8 ignore directives active** (6 generated, 2 hand-written) | Detailed AST audit confirmed 8 ignore comments across `lib/`: 6 in generated files (`firebase_options.dart` and `generated/l10n/*`), and 2 in hand-written files (`nutri_score_calculator.dart:2` and `voice_assistant_service.dart:412`). Result remains **PASS** for static analysis. | [evidence/run1_verification/item4_ignore_comments.txt](evidence/run1_verification/item4_ignore_comments.txt) |
| **A4. Live Interoperability** | "External service live exchange rate: 3/3 PASS" | **"Endpoint reachability: 3/3 PASS"**; Valid authenticated exchange: **NOT TESTED** | HTTP 405 (Gemini proxy), HTTP 400 (Cloudinary), and HTTP 404 (Firebase Identity) verify TCP routing, DNS resolution, and endpoint existence, but do not prove authenticated transactions. Live authenticated exchange is marked **NOT TESTED** due to absence of dedicated test credentials. | [evidence/run1_verification/a4_live_interop_labeling.txt](evidence/run1_verification/a4_live_interop_labeling.txt) |
| **A5. Modifiability Counts** | ">100 tests failed" | **1 modified file, 5 compile-broken files, 20 failed suites out of 32, 47 passed tests, 0 assertion failures, 113 compile-blocked tests** (160 total) | Replaced vague estimate with exact compiler counts. Injecting `sesame` into `HealthProfile` caused Dart 3 exhaustive pattern matching build errors in 5 consumer files across 3 layers, failing 20 suites. 0 tests failed assertions. Result remains **FAIL** against locked threshold ($X = 0$). | [evidence/run1_verification/a5_modifiability_exact.txt](evidence/run1_verification/a5_modifiability_exact.txt) |
| **A6. Layer Violations Count** | 12 layer violations (SERVICES -> SCREENS) | **15 layer violations** (12 SERVICES -> SCREENS + 3 DATA_DOMAIN -> SERVICES) | v1 omitted the 3 lower-layer upward imports (`product_repository.dart` and `backend_locator.dart` importing services). Total violations under locked rules is 15. Result remains **FAIL** against locked threshold (0 violations). | [evidence/run1_verification/a6_layer_matrix_reconciliation.txt](evidence/run1_verification/a6_layer_matrix_reconciliation.txt) |
| **A7. Privacy Masking & Disclosure** | Plain private worker hostname printed in run1 | **Masked placeholders** (`<GEMINI_PROXY_HOST>`, `<CLOUDINARY_CLOUD>`, `<FIREBASE_PROJECT>`) | All reports, verification files, and scripts use masked placeholders. Disclosed: frozen raw log `evidence/run1/live_interop_checks.txt` under tag `eval-run1` retains original probe output per Ground Rule 1 immutability. | [evidence/run1_verification/a7_privacy_reaudit.txt](evidence/run1_verification/a7_privacy_reaudit.txt) |

---

## 2. Technical Evaluation Results Table (v1.2)

All custom evaluation scripts referenced below are committed under `evidence/scripts/` with verified SHA-256 digests. Confidence is classified as:
- **VERIFIED:** Independently confirmed by an alternative method, AST parser, or dual-tool verification.
- **REPRODUCED:** Re-run and confirmed using the identical automated evaluation script.
- **NOT TESTED:** Prerequisite environment or credentials unavailable.

| Characteristic | Sub-characteristic | Adapted Measure | Exact Command / Script | Evidence Artifact | Measured Value | Locked Threshold | Result | Confidence |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Compatibility** | **Co-existence** | Co-existence conflict rate | `adb devices -l && flutter devices` | [evidence/run1/device_detection.txt](evidence/run1/device_detection.txt) | No hardware attached (0 devices detected) | $X = 0$ conflicts | **NOT TESTED** | **NOT TESTED** |
| **Compatibility** | **Interoperability (Layer A)** | Schema contract rate (Mock) | `flutter test test/health_profile_model_test.dart test/health_advisory_model_test.dart test/product_characteristics_test.dart test/audit_verification/` | [evidence/run1/mock_contract_tests.txt](evidence/run1/mock_contract_tests.txt) | $X_{\text{mock}} = 18 / 18$ ($100.0\%$) | $X_{\text{mock}} = 1.0$ ($100\%$) | **PASS** | **REPRODUCED** |
| **Compatibility** | **Interoperability (Layer B)** | Endpoint reachability (Live) | `python3 evidence/scripts/live_interop_probe.py` | [evidence/run1/live_interop_checks.txt](evidence/run1/live_interop_checks.txt) | $X_{\text{reach}} = 3 / 3$ ($100.0\%$) | $X_{\text{reach}} = 1.0$ ($100\%$) | **PASS** | **REPRODUCED** |
| **Compatibility** | **Interoperability (Layer B)** | Valid authenticated data exchange | Probe requiring dedicated test credentials | [evidence/run1_verification/a4_live_interop_labeling.txt](evidence/run1_verification/a4_live_interop_labeling.txt) | No dedicated test credentials provisioned | $X_{\text{live}} = 1.0$ ($100\%$) | **NOT TESTED** | **NOT TESTED** |
| **Maintainability** | **Modularity (Coupling)** | Layer dependency violation count | `python3 evidence/scripts/modularity_analysis.py` | [evidence/run1_verification/a6_layer_matrix_reconciliation.txt](evidence/run1_verification/a6_layer_matrix_reconciliation.txt) | **15 violations**, **3 circular cycles** | 0 violations, 0 cycles | **FAIL** | **VERIFIED** (Violations independently re-derived via grep) |
| **Maintainability** | **Modularity (Size Proxy)** | High-complexity source file ratio ($>500$ LOC) | `python3 evidence/scripts/modularity_analysis.py` | [evidence/run1/modularity_analysis.txt](evidence/run1/modularity_analysis.txt) | **34 / 128 files** ($26.56\%$) *(or 34 / 129 incl. firebase_options, $26.36\%$)* | $X \le 0.15$ ($15.0\%$) | **FAIL** | **REPRODUCED** |
| **Maintainability** | **Reusability** | Shared component utilization ratio | `python3 evidence/scripts/reusability_analysis.py` | [evidence/run1/reusability_analysis.txt](evidence/run1/reusability_analysis.txt) | **33 / 68 components** ($48.53\%$) | $X \ge 0.30$ ($30.0\%$) | **PASS** | **REPRODUCED** |
| **Maintainability** | **Analysability** | Static diagnostic density | `flutter analyze` | [evidence/run1/analyze_output.txt](evidence/run1/analyze_output.txt) | 0 errors, 0 warnings, 0 info ($0.00$ / KLOC) | 0 err, 0 warn, $<1.0$ info/KLOC | **PASS** | **VERIFIED** (8 active ignore comments audited) |
| **Maintainability** | **Modifiability** | Regression defect rate upon schema mutation | `bash evidence/scripts/modifiability_eval.sh` | [evidence/run1_verification/a5_modifiability_exact.txt](evidence/run1_verification/a5_modifiability_exact.txt) | **5 files broken**, **20 failed suites out of 32 total**, 113 tests blocked, 0 assertion failures | $X = 0$ ($0\%$) | **FAIL** | **VERIFIED** (Exhaustive switch compile-breakage confirmed) |
| **Maintainability** | **Testability** | Net automated line coverage | `python3 evidence/scripts/coverage_audit.py` | [evidence/run1_verification/item2_real_lf_measurement.txt](evidence/run1_verification/item2_real_lf_measurement.txt) | 3,024 / 19,884 lines (**15.21%** across 128 non-gen files; 15.89% lcov-only) | $X \ge 70.0\%$ (LOCKED) | **FAIL** | **VERIFIED** (LF measured via temporary measurement aid) |

---

## 3. In-Depth Technical Evidence & Reconciliations

### 3.1 Reconciled File Counts (128 vs 129)
The repository contains **132 total `.dart` files** under `lib/`. The breakdown is:
- **Generated localization files (3 files):**
  - `lib/generated/l10n/app_localizations.dart`
  - `lib/generated/l10n/app_localizations_en.dart`
  - `lib/generated/l10n/app_localizations_tl.dart`
- **Generated platform configuration (1 file):**
  - `lib/firebase_options.dart` (Auto-generated by FlutterFire CLI; header: `// File generated by FlutterFire CLI.`)
- **Canonical Hand-Written Non-Generated Source Files (N = 128):**
  - Exactly **128 non-generated source files** comprise the hand-written codebase. A complete enumerated list of all 128 files is archived in [evidence/run1_verification/item1_non_generated_files.txt](evidence/run1_verification/item1_non_generated_files.txt).

**Reconciliation of 128 vs 129:**
In v1, the modularity script excluded only `*.g.dart` and `/generated/`, thereby counting `firebase_options.dart` as one of **129 files** (yielding 34 / 129 = 26.36% > 500 LOC). In contrast, the coverage audit excluded `firebase_options.dart` as an external CLI bootstrap file, yielding **128 non-generated files** (34 / 128 = 26.56% > 500 LOC). This report establishes **N = 128** as the canonical hand-written non-generated file count used consistently across all metrics.

### 3.2 Exact Replacement of Estimated Lines (Measurement Aid Method)
In v1.1, the 9 non-generated files un-imported by test suites were estimated at 1,881 executable lines. In accordance with Ground Rules, this heuristic estimate was replaced with exact measurement.

**Methodology (Measurement Aid, not Added Tests):**
On a throwaway git branch (`measurement-aid/coverage-lf`), a temporary test harness importing the 9 un-imported files was run under `flutter test --coverage`. This forced the Dart VM coverage profiler to instrument the files and output their exact Lines Found (`LF`). Zero assertions were added. The temporary test was deleted, the branch was deleted, and `main` was left untouched.

| Un-Imported File Path | Measured LF | Measured LH | Notes |
| :--- | :--- | :--- | :--- |
| `lib/main.dart` | 159 | 3 | Top-level entrypoint |
| `lib/screens/get_started_screen.dart` | 203 | 2 | Onboarding UI |
| `lib/screens/select_language_screen.dart` | 292 | 1 | Localization selection UI |
| `lib/screens/splash_screen.dart` | 56 | 0 | App launch animation |
| `lib/services/get_started_service.dart` | 9 | 0 | First-time onboarding state |
| `lib/services/yolo_recognition_service.dart` | 0 | 0 | Export-only conditional library (no executable lines) |
| `lib/services/yolo_recognition_service_web.dart` | 19 | 0 | Web stub for FFI |
| `lib/widgets/dome_clipper.dart` | 33 | 1 | Custom UI clipper path |
| `lib/widgets/dome_page_route.dart` | 84 | 0 | Custom navigation transition |
| **TOTAL** | **855** | **7** | **855 Lines Found (LF)** |

**Recomputed Net Line Coverage:**
- Run 1 `lcov.info` Baseline (119 files): $LH = 3,024$, $LF = 19,029$ ($15.89\%$)
- Measured 9 Un-imported Files: $LF = 855$
- **Total Non-Generated Source Lines (128 files):** $LF = 19,029 + 855 = 19,884$
- **Corrected Net Coverage:** $3,024 / 19,884 =$ **15.21%** (Replaces v1.1's estimated 14.46%).

### 3.3 Commit History & Baseline Test Count Disclosure
- Historical commit `385be19` (2026-09-22) contained 87 unit tests and 10.67% coverage as documented in `PORTABILITY_MAINTAINABILITY_EVALUATION.md`.
- Commits `9f6fd41` through `b843690` expanded the test suite to 160 tests across 32 test files.
- Commit `b843690` ("improved parts for ISO requirements") was committed on **2026-10-23 10:12:06 +0800**.
- The evaluation thresholds were locked in commit `9a35196` on **2026-10-26 15:42:35 +0800**.
- **Formal Disclosure:** Tests were added **before** the lock. Zero tests were added after the lock at `9a35196`. When Run 1 commenced, the pre-existing test suite consisted of exactly 160 tests.

### 3.4 Static Analysis Suppression Audit & `analysis_options.yaml`
Static analysis via `flutter analyze` reported 0 errors, 0 warnings, and 0 lints. A comprehensive regex audit across all Dart files identified **8 active ignore comments**:

| Location | Directive & Suppressed Rule | File Classification | Justification / Context |
| :--- | :--- | :--- | :--- |
| `lib/core/utils/nutri_score_calculator.dart:2` | `// ignore_for_file: constant_identifier_names` | **Hand-written** | Legacy enum/constant naming convention (`Score_A`, `Score_B`). |
| `lib/firebase_options.dart:2` | `// ignore_for_file: type=lint` | **Generated** | Auto-generated by FlutterFire CLI. |
| `lib/generated/l10n/app_localizations.dart:11` | `// ignore_for_file: type=lint` | **Generated** | Auto-generated by `flutter gen-l10n`. |
| `lib/generated/l10n/app_localizations_en.dart:1` | `// ignore: unused_import` | **Generated** | Auto-generated localization boilerplate. |
| `lib/generated/l10n/app_localizations_en.dart:5` | `// ignore_for_file: type=lint` | **Generated** | Auto-generated by `flutter gen-l10n`. |
| `lib/generated/l10n/app_localizations_tl.dart:1` | `// ignore: unused_import` | **Generated** | Auto-generated localization boilerplate. |
| `lib/generated/l10n/app_localizations_tl.dart:5` | `// ignore_for_file: type=lint` | **Generated** | Auto-generated by `flutter gen-l10n`. |
| `lib/services/voice_assistant_service.dart:412` | `// ignore: deprecated_member_use` | **Hand-written** | References `TextToSpeech.setLanguage` prior to plugin API upgrade. |

Only 2 ignore directives exist in hand-written code; neither suppresses build errors or critical logic flaws.

**Full `analysis_options.yaml` Configuration:**
```yaml
# This file configures the analyzer, which statically analyzes Dart code to
# check for errors, warnings, and lints.
#
# The issues identified by the analyzer are surfaced in the UI of Dart-enabled
# IDEs (https://dart.dev/tools#ides-and-editors). The analyzer can also be
# invoked from the command line by running `flutter analyze`.

# The following line activates a set of recommended lints for Flutter apps,
# packages, and plugins designed to encourage good coding practices.
analyzer:
  exclude:
    - build/**
    - android/**
    - web/**
    - windows/**
    - macos/**
    - linux/**
include: package:flutter_lints/flutter.yaml

linter:
  # The lint rules applied to this project can be customized in the
  # section below to disable rules from the `package:flutter_lints/flutter.yaml`
  # included above or to enable additional rules. A list of all available lints
  # and their documentation is published at https://dart.dev/lints.
  #
  # Instead of disabling a lint rule for the entire project in the
  # section below, it can also be suppressed for a single line of code
  # or a specific dart file by using the `// ignore: name_of_lint` and
  # `// ignore_for_file: name_of_lint` syntax on the line or in the file
  # producing the lint.
  rules:
    # avoid_print: false  # Uncomment to disable the `avoid_print` rule
    # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule

# Additional information about this file can be found at
# https://dart.dev/guides/language/analysis-options
```

### 3.5 Architectural Layering Rules, Violations & Path Classification Analysis

**Locked Layer Direction (Quoted from `evidence/thresholds_locked.md`, Section 2):**
> "The team defines the following unidirectional dependency hierarchy:
> - **Presentation Layer:** `lib/screens/`, `lib/widgets/` (May depend on Services, Models, Data, Core)
> - **Service Layer:** `lib/services/` (May depend on Data, Models, Core; **MUST NOT** depend on `lib/screens/`)
> - **Data & Domain Layer:** `lib/data/`, `lib/models/`, `lib/core/` (Foundational layer; **MUST NOT** depend on `lib/screens/` or `lib/widgets/`)
> - **Cycle Rule:** 0 circular package dependencies permitted across modules."

**Complete Enumeration of the 15 Layer Violations:**
1. `lib/services/voice_command_router.dart:6` $\rightarrow$ `lib/screens/nutrition_guide_screen.dart` (`SERVICES -> SCREENS`)
2. `lib/services/voice_command_router.dart:7` $\rightarrow$ `lib/screens/group_screen.dart` (`SERVICES -> SCREENS`)
3. `lib/services/voice_command_router.dart:15` $\rightarrow$ `lib/screens/personal_info_screen.dart` (`SERVICES -> SCREENS`)
4. `lib/services/voice_command_router.dart:16` $\rightarrow$ `lib/screens/preference_screen.dart` (`SERVICES -> SCREENS`)
5. `lib/services/voice_command_router.dart:17` $\rightarrow$ `lib/screens/suggestion_screen.dart` (`SERVICES -> SCREENS`)
6. `lib/services/voice_command_router.dart:18` $\rightarrow$ `lib/screens/change_password_screen.dart` (`SERVICES -> SCREENS`)
7. `lib/services/voice_command_router.dart:19` $\rightarrow$ `lib/screens/theme_screen.dart` (`SERVICES -> SCREENS`)
8. `lib/services/voice_command_router.dart:20` $\rightarrow$ `lib/screens/review_history_screen.dart` (`SERVICES -> SCREENS`)
9. `lib/services/voice_command_router.dart:21` $\rightarrow$ `lib/screens/compare_products_screen.dart` (`SERVICES -> SCREENS`)
10. `lib/services/voice_command_router.dart:22` $\rightarrow$ `lib/screens/more_details_screen.dart` (`SERVICES -> SCREENS`)
11. `lib/services/voice_command_router.dart:23` $\rightarrow$ `lib/screens/product_detail_screen.dart` (`SERVICES -> SCREENS`)
12. `lib/services/voice_command_router.dart:24` $\rightarrow$ `lib/screens/unknown_product_submission_screen.dart` (`SERVICES -> SCREENS`)
13. `lib/data/repositories/product_repository.dart:23` $\rightarrow$ `lib/services/nutrition_service.dart` (`DATA_DOMAIN -> SERVICES`)
14. `lib/data/services/backend_locator.dart:27` $\rightarrow$ `lib/services/pending_reports_service.dart` (`DATA_DOMAIN -> SERVICES`)
15. `lib/data/services/backend_locator.dart:28` $\rightarrow$ `lib/services/connectivity_service.dart` (`DATA_DOMAIN -> SERVICES`)

**Analysis of `lib/data/services/*` Classification & False Violations:**
Under the strict path-prefix rule (`lib/data/*` $\in$ `DATA_DOMAIN`), `lib/data/services/backend_locator.dart` is categorized as `DATA_DOMAIN`. Consequently, its imports of `pending_reports_service.dart` and `connectivity_service.dart` are flagged as layer violations (DATA_DOMAIN importing SERVICES). 

However, `backend_locator.dart` is functionally a service locator / dependency injector sitting at the Service/Infrastructure boundary rather than an entity model or database DAO. If the classification rules categorized `lib/data/services/` under the `SERVICES` layer, violations #14 and #15 would dissolve, reducing total layer violations from 15 to 13. Nonetheless, violation #13 (`product_repository.dart` importing `nutrition_service.dart`) represents genuine domain-to-service coupling, and violations #1 through #12 represent unambiguous architectural inversion where a background service directly instantiates and pushes UI screens.

### 3.6 Privacy Re-Audit Results & Repository Cleanliness

A comprehensive automated regex audit was executed across both the working directory `evidence/` and the entire git commit history of `evidence/`:

| Sensitive Pattern Description | Regular Expression Filter | Working Copy Matches | Git History Matches | Status |
| :--- | :--- | :--- | :--- | :--- |
| Google API Keys | `AIza[0-9A-Za-z-_]{35}` | 0 | 0 | **CLEAN** |
| JSON Web Tokens | `eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?...` | 0 | 0 | **CLEAN** |
| Bearer Authentication Tokens | `bearer [a-zA-Z0-9_.-]+` | 0 | 0 | **CLEAN** |
| Password Key/Value Pairs | `password\s*[:=]\s*["'][^"']+["']` | 0 | 0 | **CLEAN** |
| Secret Key/Value Pairs | `secret\s*[:=]\s*["'][^"']+["']` | 0 | 0 | **CLEAN** |
| URL Token Parameters | `token=[a-zA-Z0-9_-]{10,}` | 0 | 0 | **CLEAN** |
| API Key URL Parameters | `apikey=[a-zA-Z0-9_-]{10,}` | 0 | 0 | **CLEAN** |
| Cloudflare Workers Hostnames | `[a-zA-Z0-9_-]+\.workers\.dev` | 1 | 1 | **CONTAINED** (Frozen run1 only) |
| Cloudinary Cloud Identifiers | `api\.cloudinary\.com/v1_1/[a-zA-Z0-9_-]+` | 0 | 0 | **CLEAN** |
| Firebase Database / Project URLs | `[a-z0-9-]+\.firebaseio\.com` | 0 | 0 | **CLEAN** |
| User Email Addresses | `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}` | 1 | 2 | **CONTAINED** (Author git log) |

**Disclosure on Frozen Run 1 Evidence:**
Per Ground Rule 1, `evidence/run1/` is frozen and immutable. The raw probe output captured during Run 1 (`evidence/run1/live_interop_checks.txt`, tagged under `eval-run1`) contains the unmasked worker hostname `claro-gemini-proxy.claro-app.workers.dev`. In accordance with Ground Rule 5, all markdown reports (`REPORT_v1.1.md`, `REPORT_v1.2.md`), verification documents, and reproducible probe scripts use the masked placeholder `<GEMINI_PROXY_HOST>`.

---

## 4. Evaluator Self-Check & Independent Verification

### 4.1 Reproducible Script Catalog & Cryptographic Manifest
All evaluation scripts have been formalized, made executable, and saved to `evidence/scripts/`:

| Script Name | Purpose | SHA-256 Digest |
| :--- | :--- | :--- |
| `evidence/scripts/coverage_audit.py` | Calculates gross, net, and corrected coverage across 128 non-generated files | `de9bbe4993cee139fb7c48bf5e5883ab2250caf21fa615d137c5edd98608717f` |
| `evidence/scripts/live_interop_probe.py` | Performs HTTP reachability diagnostic probes with privacy masking | `2cecf06888fd8881d04932d1df1b24e3e0cb6e2cfd7e5955f430fd6b34b3f763` |
| `evidence/scripts/modifiability_eval.sh` | Automates throwaway branch creation, enum mutation, test execution, and rollback | `9d00bf4fe8d427d3d8010853324687fbd3e19d818cc6cf0a572cabfc3bbca239` |
| `evidence/scripts/modularity_analysis.py` | Computes layer import matrix, violations, cycles (Tarjan), and 500-LOC proxy | `718c0224cc6dbedff2d60553a869ac5eddfdc37fbbf1b58075a220db37d02a1b` |
| `evidence/scripts/privacy_reaudit.sh` | Regex scanner for sensitive tokens, keys, passwords, and private worker URLs | `7004838b5581303ab6aa1e19dd010ec5b176170917d1c6793ae7abdf4b250544` |
| `evidence/scripts/reusability_analysis.py` | Calculates shared component multi-module utilization ratio | `34200d5a77a330c7715d2143f2d85e4f40fbf03050dba0561c3671e58bc696eb` |

### 4.2 Independent Re-derivation of Sampled Results
Three results were selected for dual-method verification using a documented pseudo-random selection method (`SHA256("CLARO_ISO_EVAL_SEED")` modulo index):

1. **Sample 1: Test Count (160 tests)**
   - *Primary Method:* `flutter test` summary line (`+160: All tests passed!`).
   - *Alternative Method:* AST / regex count of `\b(?:test|testWidgets)\s*\(` across all 32 test files under `test/**/*.dart`.
   - *Independent Result:* Exactly **160 test definitions** identified. Verified 100% concordant.

2. **Sample 2: Line Coverage (15.21% net across 128 non-generated files)**
   - *Primary Method:* Sum of `LH` / `LF` records in `lcov.info` combined with measurement aid test output.
   - *Alternative Method:* Direct source code AST line iteration summing non-empty, non-comment executable line tokens against VM coverage profile.
   - *Independent Result:* $3,024 / (19,029 + 855) = 3,024 / 19,884 =$ **15.21%**. Verified 100% concordant.

3. **Sample 3: Architectural Layer Violation in `voice_command_router.dart`**
   - *Primary Method:* Python AST import graph scanner (`modularity_analysis.py`).
   - *Alternative Method:* Direct shell ripgrep `grep -n "screens/" lib/services/voice_command_router.dart`.
   - *Independent Result:* Confirmed lines 6, 7, 15, 16, 17, 18, 19, 20, 21, 22, 23, and 24 directly import screen widgets. Verified 100% concordant.

### 4.3 Immutability of Frozen Run 1 Evidence & Manifest Verification

- **Git Diff Check against Frozen Tag `eval-run1`:**
  ```bash
  git diff eval-run1 -- evidence/run1
  ```
  *Output:* **Empty** (0 lines changed). Guarantees that Run 1 evidence has not been tampered with or modified.

- **Cryptographic Hash Verification (`evidence/MANIFEST.sha256`):**
  ```
  evidence/run1/analyze_output.txt: OK
  evidence/run1/coverage_analysis.txt: OK
  evidence/run1/device_detection.txt: OK
  evidence/run1/lcov.info: OK
  evidence/run1/live_interop_checks.txt: OK
  evidence/run1/mock_contract_tests.txt: OK
  evidence/run1/modifiability_test_run.txt: OK
  evidence/run1/modularity_analysis.txt: OK
  evidence/run1/reusability_analysis.txt: OK
  evidence/run1/test_run.txt: OK
  evidence/run1/thresholds_locked.md: OK
  evidence/run1_verification/a1_test_count_discrepancy.txt: OK
  evidence/run1_verification/a2_coverage_completeness.txt: OK
  evidence/run1_verification/a3_analyzer_suppression_audit.txt: OK
  evidence/run1_verification/a4_live_interop_labeling.txt: OK
  evidence/run1_verification/a5_modifiability_exact.txt: OK
  evidence/run1_verification/a5_modifiability_raw.txt: OK
  evidence/run1_verification/a6_layer_matrix_reconciliation.txt: OK
  evidence/run1_verification/a7_privacy_reaudit.txt: OK
  evidence/run1_verification/item1_non_generated_files.txt: OK
  evidence/run1_verification/item2_real_lf_measurement.txt: OK
  evidence/run1_verification/item4_ignore_comments.txt: OK
  evidence/scripts/coverage_audit.py: OK
  evidence/scripts/live_interop_probe.py: OK
  evidence/scripts/modifiability_eval.sh: OK
  evidence/scripts/modularity_analysis.py: OK
  evidence/scripts/privacy_reaudit.sh: OK
  evidence/scripts/reusability_analysis.py: OK
  evidence/thresholds_locked.md: OK
  ```
  Every evidence artifact and reproducible script matches its cryptographic fingerprint.

---

## 5. Limitations & Threats to Validity

1. **Proxy Measures:** The 500-LOC metric is an empirical proxy for single-responsibility concentration and maintainability risk, not a direct measurement of cyclomatic complexity, cognitive complexity, or Halstead volume.
2. **Self-Testing by AI Agent:** All test runs, static analysis checks, and AST scripts were invoked by the developer AI agent within the local macOS environment. No independent third-party certification lab executed the tests.
3. **Absence of Hardware Co-existence Matrix:** No physical or virtual Android devices were attached during testing. Native camera sensor exclusive locking, audio focus preemption, and low-memory background terminations remain unverified on hardware.
4. **Compile-time coupling vs. runtime regressions:** Dart 3's exhaustive switch pattern matching on enums is intentionally engineered to generate compile-time build errors whenever a new enum case is introduced. From a compiler-safety perspective, this is a desirable feature that prevents silent unhandled runtime cases. However, under the ISO/IEC 25010 modifiability definition ($X = \text{broken test suites outside modified boundary} / \text{total}$), modifying a single data model enum causes cascading build failures across 5 consumer files in 3 architectural layers, causing 20 out of 32 test suites to fail compilation.
5. **Coverage Scope:** While 100% of existing automated unit/widget tests pass (160/160), net line coverage is 15.21% across all 128 non-generated source files. Nine critical files (including `main.dart`, onboarding, and language selection screens) have 0% coverage.

---

## 6. Uncertainties

1. **Adviser Acceptance of Proxy Limits:** Whether institutional academic advisers will accept the team-defined 500-LOC proxy and 30% reusability threshold, or mandate formal Halstead volume / McCabe cyclomatic complexity tooling.
2. **Live Test Account Provisioning & Sandbox Isolation:** Whether an active Firebase and Cloudinary test account with authenticated network read/write transactions can be provisioned in the evaluation environment without risk of polluting production collections or exceeding billing quotas, and whether academic advisers accept local mock contract tests ($X_{\text{mock}} = 18/18$) in lieu of authenticated live network traffic.

---

## 7. Human Action Items

The following actions require human intervention and cannot be executed autonomously:
1. **Adviser Approval:** Submit [evidence/thresholds_locked.md](evidence/thresholds_locked.md) to academic advisers for formal signature and threshold ratification.
2. **Hardware Attachment:** Connect an Android physical device (minSdk 24+ or Android 11–14) via USB with ADB debugging enabled to execute Part C (Co-existence).
3. **Dedicated Test Account:** Provision a dedicated non-production Firebase test user (e.g. `test-audit@claro.app`) if live authenticated valid-exchange testing is required.
4. **Authorization to Proceed:** Reply with **"proceed with Part D"** to begin architectural remediation on branch `remediation/run2`.
