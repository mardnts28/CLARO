# CLARO - ISO/IEC 25010:2023 Locked Evaluation Thresholds & Methodology
**Evaluation Standard Baseline:** Evaluated using measures adapted from ISO/IEC 25010:2023 sub-characteristics (Measurement approach adapted from ISO/IEC 25023; ISO/IEC 25023 official text not available).
**Lock Date:** 2026-10-26
**Commit Status:** Locked prior to test execution.

---

## 1. Global Governance & Rules
1. **No 25023 Conformance Claims:** All measures are explicitly identified as *"Adapted measure (ISO/IEC 25023 text not available)"*.
2. **Threshold Immutability:** Thresholds are locked in this document before running evaluation commands. No threshold shall be retroactively modified after observing test results.
3. **Data Security & Privacy:** No API keys, credentials, session tokens, or sensitive user data will be logged or stored in evidence files. All network or configuration checks must mask sensitive secrets.
4. **Coverage Exclusions (Pre-declared):**
   - Generated files: `*.g.dart`, `lib/generated/**`
   - Platform bootstrap: `lib/firebase_options.dart`
   - Both gross coverage (without exclusions) and net coverage (with exclusions) will be reported.

---

## 2. Intended Architectural Layering & Direction
The team defines the following unidirectional dependency hierarchy:
- **Presentation Layer:** `lib/screens/`, `lib/widgets/` (May depend on Services, Models, Data, Core)
- **Service Layer:** `lib/services/` (May depend on Data, Models, Core; **MUST NOT** depend on `lib/screens/`)
- **Data & Domain Layer:** `lib/data/`, `lib/models/`, `lib/core/` (Foundational layer; **MUST NOT** depend on `lib/screens/` or `lib/widgets/`)
- **Cycle Rule:** 0 circular package dependencies permitted across modules.

---

## 3. Locked Thresholds Table

| Characteristic | Sub-Characteristic | Adapted Measure | Formula ($X = A / B$) | Locked Threshold | Origin | Rationale |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Compatibility** | **Co-existence** | Co-existence conflict rate | $A$ = Resource contention conflicts (camera lock, audio focus loss, background kill, crash) under concurrency/memory pressure.<br>$B$ = Total scenarios executed across device matrix. | $X = 0$ | Team-defined (pending adviser approval) | Any camera or audio contention directly breaks the core product scan and advisory flow. |
| **Compatibility** | **Interoperability (Layer A)** | Interface schema contract conformance (Mock/Local) | $A$ = Number of schema/serialization unit tests passing.<br>$B$ = Total schema/serialization unit tests defined. | $X_{\text{mock}} = 1.0$ (100%) | Team-defined (pending adviser approval) | Ensures internal data model consistency; note: proves consistency with internal schemas only. |
| **Compatibility** | **Interoperability (Layer B)** | External service live exchange rate (Live) | $A$ = Number of live backend interfaces responding validly without format error (Firebase, Gemini Proxy, Cloudinary).<br>$B$ = Total live interfaces queried (3). | $X_{\text{live}} = 1.0$ (100%) | Team-defined (pending adviser approval) | Each external service sits on the critical path of the scan, OCR, or auth flow. |
| **Maintainability** | **Modularity (Coupling)** | Architectural layer dependency violation count | $A$ = Number of layer violations (e.g. data/service importing screens) + circular dependencies. | $A = 0$ violations,<br>$0$ cycles | Team-defined (pending adviser approval) | Changes in lower-level data or business services must never cause cascading breakages in UI components. |
| **Maintainability** | **Modularity (Size Proxy)** | High-complexity source file ratio (Proxy only) | $A$ = Non-generated Dart files in `lib/` with $> 500$ LOC.<br>$B$ = Total non-generated Dart files in `lib/`. | $X \le 0.15$ (15%) | Team-defined (pending adviser approval) | Proxy indicator for single-responsibility concentration and architectural bloat. |
| **Maintainability** | **Reusability** | Shared component utilization ratio (Heuristic) | $A$ = Components in `lib/widgets`, `lib/services`, `lib/core` imported by $\ge 2$ distinct feature modules.<br>$B$ = Total components in those directories. | $X \ge 0.30$ (30%) | Team-defined (pending adviser approval) | Demonstrates that shared logic is meaningfully reused across multiple application flows. |
| **Maintainability** | **Analysability** | Static analysis diagnostic density | $A_1$ = Fatal errors<br>$A_2$ = Compiler warnings<br>$A_3$ = Informational lint findings<br>$B$ = KLOC (thousand lines of code) | Errors = 0<br>Warnings = 0<br>Info $< 1.0$ / KLOC | Errors/Warnings: Tool default (`flutter analyze`).<br>Info: Team-defined (pending adviser approval). | Zero warnings guarantees language safety; low info density ensures maintainable, clean code. |
| **Maintainability** | **Modifiability** | Regression defect rate upon schema extension | $A$ = Broken tests outside the modified boundary after adding a new condition/allergen on a test branch.<br>$B$ = Total automated regression tests. | $X = 0$ | Team-defined (pending adviser approval) | Adding a new domain category must be isolated and must not induce regressions in unrelated modules. |
| **Maintainability** | **Testability** | Automated test line coverage | $A$ = Lines hit ($LH$) in `lcov.info`.<br>$B$ = Lines found ($LF$) in `lcov.info`. | $X \ge 70.0\%$ (LOCKED) | Team-defined (pending adviser approval) | 70% line coverage provides a defensible statistical baseline for regression and defect prevention. |

---

## 4. Device Matrix Specification for Compatibility
- **D1 (Low-end):** Android 7.0 (API 24), 2 GB RAM (Emulator or physical)
- **D2 (Mid-range):** Android 11–13 (API 30–33), 3–4 GB RAM
- **D3 (Recent):** Android 14+ (API 34–36), 6–8 GB RAM
- **Physical Device:** Required for valid camera, TFLite, and audio focus benchmarks.
- *Policy:* Any device tier or hardware requirement not physically or virtually attachable during testing will be explicitly marked **NOT TESTED** with manual verification steps.
