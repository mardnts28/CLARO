# Comprehensive Evaluation Breakdown: CLARO Mobile Application (Run 1)

This document tabulates the developer-side technical evaluation and user perception survey results for the CLARO mobile application. The evaluation used measures adapted from ISO/IEC 25010:2023 sub-characteristics. The measurement approach was adapted from ISO/IEC 25023 because the official text was not available. The application does not claim official ISO/IEC compliance, conformance, or certification. The development team performed all automated tests using an AI coding assistant. No independent verification agency repeated the evaluation.

---

## Section 1. Scope and Methods

Table 1 summarizes the two evaluation methods, the instruments used, and the system environment under test.

#### Table 1. Scope and Evaluation Methods
| Method | What was evaluated | Instrument or tools | Characteristics covered | Execution metadata |
| :--- | :--- | :--- | :--- | :--- |
| **A. User perception survey** | Subjective user ratings, accessibility perception, and usability feedback ($n = 50$) | 11 questionnaire items (Q5–Q15) using a 5-point Likert scale and open-ended feedback | Functional Suitability, Performance Efficiency, Interaction Capability, Reliability, Security, Flexibility, Safety | Administered post-testing; 50 respondents; all responses collected in October 2026 |
| **B. Developer technical evaluation (Run 1)** | Objective source code metrics, test suite execution, architectural coupling, and endpoint reachability | Flutter test runner, `lcov`, Dart analyzer, custom AST dependency scripts, HTTP probe | Compatibility (Interoperability, Co-existence), Maintainability (Modularity, Reusability, Analysability, Modifiability, Testability) | Tested commit: `b843690` (2026-10-23 10:12:06 +0800); locked commit: `9a35196` (2026-10-26 15:42:35 +0800); tag: `eval-run1` (2026-10-26 16:15:28 +0800); Flutter 3.44.4; Dart 3.12.2 |

*Note on Table 1:* Technical evaluations and user surveys were conducted on the same application baseline. Technical evaluations were executed locally on macOS without an independent QA auditor. The user survey captured subjective perceptions rather than technical benchmarks.

---

## Section 2. Coverage Summary

Table 2 reports the evaluation coverage across all nine ISO/IEC 25010:2023 product quality characteristics.

#### Table 2. ISO/IEC 25010:2023 Quality Characteristic Coverage Summary
| Characteristic | Total sub-characteristics | Evaluated directly | Evaluated indirectly | Not evaluated | Method(s) used | Overall status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Functional Suitability** | 3 | 2 | 1 | 0 | User perception survey | Partly |
| **Performance Efficiency** | 3 | 1 | 1 | 1 | User perception survey | Partly |
| **Compatibility** | 2 | 1 | 0 | 1 | Automated unit tests, HTTP probe, device discovery | Partly |
| **Interaction Capability** | 8 | 0 | 6 | 2 | User perception survey | Indirect only |
| **Reliability** | 4 | 0 | 2 | 2 | User perception survey | Indirect only |
| **Security** | 6 | 0 | 1 | 5 | User perception survey | Indirect only |
| **Maintainability** | 5 | 5 | 0 | 0 | AST scripts, Dart analyzer, test runner, lcov audit | Fully |
| **Flexibility** | 4 | 0 | 2 | 2 | User perception survey | Indirect only |
| **Safety** | 5 | 0 | 1 | 4 | User perception survey | Indirect only |
| **TOTAL** | **40** | **9** | **14** | **17** | **Survey, test suites, AST scripts, HTTP probe** | **Partly** |

*Note on Table 2:* Exactly 9 sub-characteristics were directly measured using automated code analysis or targeted survey items. Fourteen sub-characteristics were evaluated indirectly through perception items. Seventeen sub-characteristics were not evaluated or not tested due to missing hardware, credentials, or instruments.

---

## Section 3. Detailed Results by Characteristic

Tables 3.1 through 3.9 present findings for all 40 sub-characteristics. Each table follows an identical column schema. Survey rows list descriptive interpretations; technical rows list locked threshold decisions.

#### Table 3.1. Detailed Results for Functional Suitability
| Sub-characteristic | Evaluated? | Measure or survey item | Result (value) | Threshold or interpretation | Passed? | Method and tools | Audit trail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Completeness** | Indirect | Q15 (task completion assistance); open-ended product feedback | 42 alone (84.0%), 8 with help (16.0%) | Not applicable (no pre-set threshold) | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Correctness** | Yes | Q5 (recognition), Q6 (profile warnings) | Q5: 100.0% fav (mean = 4.50); Q6: 100.0% fav (mean = 4.64) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Appropriateness** | Yes | Q7 (relevance of health suggestions) | Q7: 100.0% fav (mean = 4.78) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |

*Note on Table 3.1:* Users rated recognition and warning appropriateness highly. However, these ratings reflect perceived accuracy across limited test products. Objective algorithmic recall and OCR precision were not measured with ground-truth test datasets.

#### Table 3.2. Detailed Results for Performance Efficiency
| Sub-characteristic | Evaluated? | Measure or survey item | Result (value) | Threshold or interpretation | Passed? | Method and tools | Audit trail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Time behaviour** | Yes | Q8 (scan response speed), Q9 (interface responsiveness) | Q8: 100.0% fav (mean = 4.58); Q9: 100.0% fav (mean = 4.58) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Resource utilization** | Indirect | Q9 (scanner did not slow host phone) | Q9: 100.0% fav (mean = 4.58) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Capacity** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No stress or load testing performed | None; NOT EVALUATED |

*Note on Table 3.2:* Survey respondents perceived camera scanning and UI transitions as fast. Technical latency benchmarks (e.g. frame render times or OCR inference duration) were not instrumented. Peak memory allocation and thread contention were not measured.

#### Table 3.3. Detailed Results for Compatibility
| Sub-characteristic | Evaluated? | Measure or survey item | Result (value) | Threshold or interpretation | Passed? | Method and tools | Audit trail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Co-existence** | Not tested | Co-existence conflict rate | 0 devices attached (no hardware detected) | $X = 0$ conflicts | NOT TESTED | `adb devices -l && flutter devices` | `evidence/run1/device_detection.txt`; manual check; NOT TESTED |
| **Interoperability (Mock)** | Yes | Schema contract rate (Mock) | $X_{\text{mock}} = 18 / 18$ ($100.0\%$) | $X_{\text{mock}} = 1.0$ ($100\%$) | PASS | Automated schema tests | `evidence/run1/mock_contract_tests.txt`; test runner; REPRODUCED |
| **Interoperability (Reachability)** | Yes | Endpoint reachability (Live) | $X_{\text{reach}} = 3 / 3$ ($100.0\%$) | $X_{\text{reach}} = 1.0$ ($100\%$) | PASS | Diagnostic HTTP probe | `evidence/run1/live_interop_checks.txt`; `live_interop_probe.py` (`2cecf068`); REPRODUCED |
| **Interoperability (Valid Exchange)** | Not tested | Valid authenticated exchange | Dedicated test credentials not provisioned | $X_{\text{live}} = 1.0$ ($100\%$) | NOT TESTED | Authenticated API probe | `evidence/run1_verification/a4_live_interop_labeling.txt`; manual check; NOT TESTED |

*Note on Table 3.3:* Internal schema serialization passed all automated unit tests. External endpoints were reachable over the network. Hardware co-existence and live authenticated transactions were not tested due to missing devices and credentials.

#### Table 3.4. Detailed Results for Interaction Capability
| Sub-characteristic | Evaluated? | Measure or survey item | Result (value) | Threshold or interpretation | Passed? | Method and tools | Audit trail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Appropriateness recognizability** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No pre-use cognitive walkthrough | None; NOT EVALUATED |
| **Learnability** | Indirect | Q15 (task completion assistance) | 42 alone (84.0%), 8 with help (16.0%) | Not applicable (no pre-set threshold) | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Operability** | Indirect | Q10 (layout/buttons), Q14 (overall usability) | Q10: 100.0% fav (mean = 4.76); Q14: 100.0% fav (mean = 4.76) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **User error protection** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No input boundary error testing | None; NOT EVALUATED |
| **User engagement** | Indirect | Q14 (aesthetic satisfaction and operation) | Q14: 100.0% fav (mean = 4.76) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Inclusivity** | Indirect | Q10 (visual clarity), Q11 (voice assistance); 38% low-vision sample | Q10: 100.0% fav (mean = 4.76); Q11: 88.0% yes | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **User assistance** | Indirect | Q11 (voice assistant usability) | 44 yes (88.0%), 0 no (0.0%), 6 not used (12.0%) | Not applicable (no pre-set threshold) | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Self-descriptiveness** | Indirect | Q10 (clarity of icons, colors, labels) | Q10: 100.0% fav (mean = 4.76) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |

*Note on Table 3.4:* Respondents reported favorable impressions of visual layout, voice assistance, and overall operability. However, 16% of users required assistance to complete tasks. Formal accessibility audits (e.g. screen reader navigation and touch target sizing) were not conducted.

#### Table 3.5. Detailed Results for Reliability
| Sub-characteristic | Evaluated? | Measure or survey item | Result (value) | Threshold or interpretation | Passed? | Method and tools | Audit trail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Faultlessness** | Indirect | Q12 (perceived crash absence) | Q12: 100.0% fav (mean = 4.70) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Availability** | Indirect | Q12 (data access persistence); offline use requests | Q12: 100.0% fav (mean = 4.70) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Fault tolerance** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No network fault injection performed | None; NOT EVALUATED |
| **Recoverability** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No abrupt crash recovery tests performed | None; NOT EVALUATED |

*Note on Table 3.5:* Users did not report application crashes during the testing session. Objective mean time between failures was not calculated. Automated crash logging and network recovery mechanisms were not verified.

#### Table 3.6. Detailed Results for Security
| Sub-characteristic | Evaluated? | Measure or survey item | Result (value) | Threshold or interpretation | Passed? | Method and tools | Audit trail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Confidentiality** | Indirect | Q13 (perceived data and login safety) | Q13: 100.0% fav (mean = 4.78) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Integrity** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No data tampering tests performed | None; NOT EVALUATED |
| **Non-repudiation** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No digital signature auditing performed | None; NOT EVALUATED |
| **Accountability** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No security audit log verification | None; NOT EVALUATED |
| **Authenticity** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No certificate or token validation audit | None; NOT EVALUATED |
| **Resistance** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No penetration or fuzz testing performed | None; NOT EVALUATED |

*Note on Table 3.6:* Users expressed trust in the safety of their login and health data. However, user perception cannot establish cryptographic security. Automated penetration testing and vulnerability scans were outside the scope of Run 1.

#### Table 3.7. Detailed Results for Maintainability
| Sub-characteristic | Evaluated? | Measure or survey item | Result (value) | Threshold or interpretation | Passed? | Method and tools | Audit trail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Modularity (Coupling)** | Yes | Layer dependency violation count | 15 violations, 3 circular cycles | 0 violations, 0 circular cycles | FAIL | AST layer scanner | `evidence/run1_verification/a6_layer_matrix_reconciliation.txt`; `modularity_analysis.py` (`718c0224`); PARTIALLY VERIFIED |
| **Modularity (Size Proxy)** | Yes | High-complexity source file ratio (>500 LOC) | 34 / 128 files (26.56%) [or 34/129, 26.36%] | $X \le 0.15$ (15.0%) | FAIL | Line count scanner | `evidence/run1/modularity_analysis.txt`; `modularity_analysis.py` (`718c0224`); REPRODUCED |
| **Reusability** | Yes | Shared component utilization ratio | 33 / 68 components (48.53%) | $X \ge 0.30$ (30.0%) | PASS | Import cross-referencer | `evidence/run1/reusability_analysis.txt`; `reusability_analysis.py` (`34200d5a`); REPRODUCED |
| **Analysability** | Yes | Static diagnostic density | 0 errors, 0 warnings, 0 info (0.00 / KLOC) [8 ignores active] | 0 err, 0 warn, <1.0 info/KLOC | PASS | `flutter analyze` | `evidence/run1/analyze_output.txt`; `item4_ignore_comments.txt`; REPRODUCED |
| **Modifiability** | Yes | Regression defect rate upon schema mutation | 5 files broken, 20 of 32 suites failed compile, 113 blocked, 0 assertion fails | $X = 0$ (0%) | FAIL | Mutation build test | `evidence/run1_verification/a5_modifiability_exact.txt`; `modifiability_eval.sh` (`9d00bf4f`); REPRODUCED |
| **Testability** | Yes | Net automated line coverage | 3,024 / 19,884 lines (15.21% across 128 non-gen files; 15.89% lcov-only) | $X \ge 70.0\%$ (LOCKED) | FAIL | `flutter test --coverage` + lcov audit | `evidence/run1_verification/item2_real_lf_measurement.txt`; `coverage_audit.py` (`de9bbe49`); REPRODUCED |

*Note on Table 3.7:* Static analysis and component reusability satisfied locked thresholds. Modularity failed due to architectural layer coupling and oversized files. Modifiability and testability failed due to cascading compile-time breakage and low line coverage.

#### Table 3.8. Detailed Results for Flexibility
| Sub-characteristic | Evaluated? | Measure or survey item | Result (value) | Threshold or interpretation | Passed? | Method and tools | Audit trail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Adaptability** | Indirect | Q14 (operated smoothly across personal phones) | Q14: 100.0% fav (mean = 4.76) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Scalability** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No multi-user load testing performed | None; NOT EVALUATED |
| **Installability** | Indirect | Open-ended feedback requesting Google Play release | NOT AVAILABLE (qualitative feedback) | Not applicable (no pre-set threshold) | Not applicable | User survey questionnaire | Survey data block ($n = 50$); qualitative analysis; REPRODUCED |
| **Replaceability** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No component substitution tests | None; NOT EVALUATED |

*Note on Table 3.8:* Users confirmed that the application functioned on their personal Android hardware. Formal tests for screen-size adaptability and dynamic font scaling were not conducted. Package installability was evaluated only informally through manual sideloading.

#### Table 3.9. Detailed Results for Safety
| Sub-characteristic | Evaluated? | Measure or survey item | Result (value) | Threshold or interpretation | Passed? | Method and tools | Audit trail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Operational constraint** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No operational boundary tests performed | None; NOT EVALUATED |
| **Risk identification** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No formal hazard hazard analysis performed | None; NOT EVALUATED |
| **Fail safe** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No sensor failure fallback tests performed | None; NOT EVALUATED |
| **Hazard warning** | Indirect | Q6 (allergy and health warnings matched profile) | Q6: 100.0% fav (mean = 4.64) | Not applicable (no pre-set threshold); Very High | Not applicable | User survey questionnaire | Survey data block ($n = 50$); `breakdown_check.py` (`46aaf4c2`); REPRODUCED |
| **Safe integration** | No | NOT AVAILABLE | NOT AVAILABLE | NOT AVAILABLE | NOT APPLICABLE | No third-party sandboxing tests performed | None; NOT EVALUATED |

*Note on Table 3.9:* Respondents confirmed that displayed allergy and health warnings aligned with their entered health profiles. However, false-negative rate and clinical guidance hazards were not formally audited. Fail-safe degradation for corrupt barcodes was not verified.

---

## Section 4. Items Not Evaluated

Table 4 enumerates every sub-characteristic that was not evaluated or not tested, documenting the factual reason and suggested future method.

#### Table 4. Sub-characteristics Not Evaluated or Not Tested
| Characteristic | Sub-characteristic | Reason not evaluated | Suggested future method |
| :--- | :--- | :--- | :--- |
| **Compatibility** | Co-existence | No physical or virtual device was attached during automated execution. | Connect physical devices across D1, D2, and D3 tiers to test concurrent sensor contention. |
| **Compatibility** | Interoperability (valid exchange) | Dedicated non-production test credentials were not provisioned. | Provision sandbox credentials for Firebase, Gemini proxy, and Cloudinary. |
| **Performance Efficiency** | Capacity | Multi-user load generation tools were not integrated into the client test suite. | Execute load scripts (e.g. Locust) against backend proxies. |
| **Interaction Capability** | Appropriateness recognizability | No pre-task cognitive walkthrough was scheduled in the survey protocol. | Conduct pre-use walkthroughs assessing initial comprehension of icons and text. |
| **Interaction Capability** | User error protection | Input boundary validation tests were not instrumented. | Test invalid inputs, malformed barcodes, and camera occlusion errors. |
| **Reliability** | Fault tolerance | Network fault injection mechanisms were not included in automated tests. | Execute chaos tests by disconnecting network during active scan and OCR flows. |
| **Reliability** | Recoverability | Crash recovery hooks were not benchmarked. | Terminate process abruptly and verify state restoration from local storage. |
| **Security** | Integrity | Data tampering and storage encryption tests were not configured. | Validate SQLite/Hive encryption and test Firestore rule integrity in emulator. |
| **Security** | Non-repudiation | Digital transaction signing was outside application scope. | Verify signed request logs for critical profile updates. |
| **Security** | Accountability | User security event logging was not audited. | Inspect audit trail logging for authentication attempts. |
| **Security** | Authenticity | Certificate pinning and OAuth token exchange were not verified. | Instrument network proxy to test SSL pinning and token expiration. |
| **Security** | Resistance | Penetration testing and fuzzing tools were not executed. | Run automated SAST and dynamic mobile security testing tools (e.g. MobSF). |
| **Flexibility** | Scalability | Client-side evaluation did not measure concurrent tenant scaling. | Measure cloud worker latency under simulated traffic surges. |
| **Flexibility** | Replaceability | Component decoupling did not include hot-swappable service interfaces. | Define abstract adapters and test swapping OCR backend providers. |
| **Safety** | Operational constraint | Clinical limits and dosage boundary checks were not modeled. | Evaluate allergen threshold alerts against clinical dietary reference datasets. |
| **Safety** | Risk identification | Formal dietary advisory risk assessments were not conducted. | Perform FMEA (Failure Mode and Effects Analysis) on nutrition advisory logic. |
| **Safety** | Fail safe | Fallback logic for unclassified ingredients was not benchmarked. | Verify that unreadable product labels trigger conservative warning alerts. |
| **Safety** | Safe integration | Third-party AI model safety sandboxing was not audited. | Verify input/output sanitization on prompt inputs sent to the Gemini proxy. |

*Note on Table 4:* Resource constraints, credential omissions, and client-focused test boundaries prevented execution of these 18 sub-characteristic checks. Factual reasons and established engineering methods are documented for future evaluation cycles.

---

## Section 5. User Perception Survey Results

The user survey evaluated subjective impressions from 50 participants who completed test tasks with the mobile application.

#### Table 5. Likert Item Responses and Descriptive Scores ($n = 50$)
| Item | Short statement | Sub-characteristic mapped | n | Counts (1 to 5) | Favorable % (4 or 5) | Mean | Descriptive interpretation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Q5** | Recognized cans and noodles correctly | Functional Correctness | 50 | [0, 0, 0, 25, 25] | 100.00% | 4.50 | Very High |
| **Q6** | Health and allergy warnings matched profile | Functional Correctness, Hazard Warning | 50 | [0, 0, 0, 18, 32] | 100.00% | 4.64 | Very High |
| **Q7** | Healthier suggestions and comparisons were relevant | Functional Appropriateness | 50 | [0, 0, 0, 11, 39] | 100.00% | 4.78 | Very High |
| **Q8** | Results appeared quickly | Performance Time Behaviour | 50 | [0, 0, 0, 21, 29] | 100.00% | 4.58 | Very High |
| **Q9** | Scanner did not lag or slow my phone | Performance Time Behaviour, Resource Utilization | 50 | [0, 0, 0, 21, 29] | 100.00% | 4.58 | Very High |
| **Q10** | Text, buttons, colors, layout clear and readable | Operability, Inclusivity, Self-descriptiveness | 50 | [0, 0, 0, 12, 38] | 100.00% | 4.76 | Very High |
| **Q12** | App did not crash; data always available | Faultlessness, Availability | 50 | [0, 0, 0, 15, 35] | 100.00% | 4.70 | Very High |
| **Q13** | Confident health data and login are safe | Confidentiality | 50 | [0, 0, 0, 11, 39] | 100.00% | 4.78 | Very High |
| **Q14** | App looked good and worked well on phone | Operability, Engagement, Adaptability | 50 | [0, 0, 0, 12, 38] | 100.00% | 4.76 | Very High |

*Note on Table 5:* All Likert items produced mean scores within the Very High band (4.21–5.00). No ratings of 1, 2, or 3 were recorded, demonstrating a pronounced ceiling effect. Survey items measure user perception rather than technical quality.

#### Table 6. Respondent Demographic and Health Profile ($n = 50$)
| Demographic or health category | Bracket or condition | Count ($n = 50$) | Percentage | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Age bracket** | 18–24 years | 30 | 60.0% | Brackets reported exactly as collected |
| **Age bracket** | 23–34 years | 4 | 8.0% | Overlaps with 18–24 bracket |
| **Age bracket** | 35–40 years | 16 | 32.0% | Non-overlapping bracket |
| **Health condition (Multi-select)** | Hypertension | 8 | 16.0% | Multiple selections allowed |
| **Health condition (Multi-select)** | Diabetes | 4 | 8.0% | Multiple selections allowed |
| **Health condition (Multi-select)** | Heart condition | 2 | 4.0% | Multiple selections allowed |
| **Health condition (Multi-select)** | Food allergy | 4 | 8.0% | Multiple selections allowed |
| **Health condition (Multi-select)** | Low vision | 19 | 38.0% | Relevant to UI contrast and voice assistant |
| **Health condition (Multi-select)** | None reported | 24 | 48.0% | 24 respondents reported no conditions |

*Note on Table 6:* Overlapping age brackets (18–24 and 23–34) reflect the original survey collection instrument. Nineteen respondents (38.0%) reported low vision, supporting evaluation of accessibility features. Total health condition mentions sum to 61 across 50 respondents.

#### Table 7. Categorical Items and Qualitative Themes
| Item / Source | Recorded response or qualitative theme | Sub-characteristic mapped | Distribution or observation |
| :--- | :--- | :--- | :--- |
| **Q11 (Voice Assistant)** | Usability of voice interaction feature | User Assistance, Inclusivity | Yes: 44 (88.0%); No: 0 (0.0%); Not used: 6 (12.0%) |
| **Q15 (Task Completion)** | Level of independence during evaluation | Learnability, Operability | Alone: 42 (84.0%); With help: 8 (16.0%); Could not: 0 (0.0%) |
| **Open-ended Theme 1** | Distribution via Google Play Store | Installability | Users requested standard app store installation over sideloaded APKs |
| **Open-ended Theme 2** | Expanded local product database | Functional Completeness | Users requested partnerships with local grocery stores to expand coverage |
| **Open-ended Theme 3** | Offline scanning functionality | Availability, Fault Tolerance | Users requested scanning without active internet connectivity |
| **Open-ended Theme 4** | Camera scanner lag on select phones | Performance Time Behaviour | Minor frame stutter observed on lower-tier hardware |

*Note on Table 7:* Categorical responses show high task success, with 16.0% requiring assistance. Qualitative themes highlight user demand for offline scanning, wider barcode databases, and formal app store delivery.

---

## Section 6. Technical Results and Audit Trail

Technical results reflect automated evaluation commands and custom Python and Bash scripts.

#### Table 8. Technical Evaluation Results and Threshold Outcomes
| Test | Command or script | Evidence file | Measured value | Locked threshold | Result | Confidence |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Co-existence conflict rate** | `adb devices -l && flutter devices` | `evidence/run1/device_detection.txt` | 0 devices attached | $X = 0$ conflicts | NOT TESTED | NOT TESTED |
| **Schema contract rate (Mock)** | Automated model tests | `evidence/run1/mock_contract_tests.txt` | $X_{\text{mock}} = 18 / 18$ ($100.0\%$) | $X_{\text{mock}} = 1.0$ ($100\%$) | PASS | REPRODUCED |
| **Endpoint reachability (Live)** | `live_interop_probe.py` | `evidence/run1/live_interop_checks.txt` | $X_{\text{reach}} = 3 / 3$ ($100.0\%$) | $X_{\text{reach}} = 1.0$ ($100\%$) | PASS | REPRODUCED |
| **Valid authenticated exchange** | Authenticated network probe | `evidence/run1_verification/a4_live_interop_labeling.txt` | No test credentials | $X_{\text{live}} = 1.0$ ($100\%$) | NOT TESTED | NOT TESTED |
| **Layer dependency violations** | `modularity_analysis.py` | `evidence/run1_verification/a6_layer_matrix_reconciliation.txt` | 15 violations, 3 cycles | 0 violations, 0 cycles | FAIL | PARTIALLY VERIFIED |
| **File size concentration** | `modularity_analysis.py` | `evidence/run1/modularity_analysis.txt` | 34 / 128 files ($26.56\%$) | $X \le 0.15$ ($15.0\%$) | FAIL | REPRODUCED |
| **Shared component reusability** | `reusability_analysis.py` | `evidence/run1/reusability_analysis.txt` | 33 / 68 components ($48.53\%$) | $X \ge 0.30$ ($30.0\%$) | PASS | REPRODUCED |
| **Static diagnostic density** | `flutter analyze` | `evidence/run1/analyze_output.txt` | 0 err, 0 warn, 0 info (8 ignores) | 0 err, 0 warn, <1.0 info/KLOC | PASS | REPRODUCED |
| **Regression defect rate** | `modifiability_eval.sh` | `evidence/run1_verification/a5_modifiability_exact.txt` | 5 files broken, 20/32 suites failed | $X = 0$ ($0\%$) | FAIL | REPRODUCED |
| **Net automated line coverage** | `coverage_audit.py` | `evidence/run1_verification/item2_real_lf_measurement.txt` | 3,024 / 19,884 lines ($15.21\%$) | $X \ge 70.0\%$ (LOCKED) | FAIL | REPRODUCED |

*Note on Table 8:* Ten technical measures were evaluated under locked thresholds. Four measures passed, four failed, and two were not tested due to missing devices or test account credentials.

#### Table 9. Reproducible Script Catalog and Cryptographic Hashes
| Script Name | Purpose | SHA-256 Digest | Evidence Artifact Produced |
| :--- | :--- | :--- | :--- |
| `coverage_audit.py` | Calculates gross, net, and complete coverage across 128 non-generated files | `de9bbe4993cee139fb7c48bf5e5883ab2250caf21fa615d137c5edd98608717f` | `evidence/run1_verification/item2_real_lf_measurement.txt` |
| `live_interop_probe.py` | Diagnostic HTTP probes with hostname masking | `2cecf06888fd8881d04932d1df1b24e3e0cb6e2cfd7e5955f430fd6b34b3f763` | `evidence/run1/live_interop_checks.txt` |
| `modifiability_eval.sh` | Automates throwaway branch creation, enum mutation, test execution, and rollback | `9d00bf4fe8d427d3d8010853324687fbd3e19d818cc6cf0a572cabfc3bbca239` | `evidence/run1_verification/a5_modifiability_exact.txt` |
| `modularity_analysis.py` | Computes layer import matrix, violations, cycles (Tarjan), and 500-LOC proxy | `718c0224cc6dbedff2d60553a869ac5eddfdc37fbbf1b58075a220db37d02a1b` | `evidence/run1_verification/a6_layer_matrix_reconciliation.txt` |
| `privacy_reaudit.sh` | Scans working tree and git history for sensitive keys, tokens, and URLs | `7004838b5581303ab6aa1e19dd010ec5b176170917d1c6793ae7abdf4b250544` | `evidence/run1_verification/a7_privacy_reaudit.txt` |
| `reusability_analysis.py` | Computes shared component multi-module utilization ratio | `34200d5a77a330c7715d2143f2d85e4f40fbf03050dba0561c3671e58bc696eb` | `evidence/run1/reusability_analysis.txt` |
| `breakdown_check.py` | Verifies numbers, percentages, table sums, and SHA-256 hashes | `46aaf4c205f0d1f836b62a738349065cc74eb375eaa36d1f269efcd8ba47509a` | Script execution output |

*Note on Table 9:* All scripts are committed under `evidence/scripts/`. Every script hash matches the entry recorded in `evidence/MANIFEST.sha256`.

#### Table 10. Audit Reconciliation of Pre-Evaluation Discrepancies
| Item | v1 Initial Report Claim | Corrected / Measured Value | Methodological Reason |
| :--- | :--- | :--- | :--- |
| **A1. Baseline Test Count** | 87 tests / 10.67% coverage referenced in earlier test plan | 160 tests across 32 test files (0 tests added post-lock) | 87 tests reflected historical commit `385be19`. Pre-evaluation commits expanded the suite to 160 tests before the threshold lock. |
| **A2. Net Line Coverage** | 15.89% (3,024 / 19,029 lines in lcov); v1.1 estimated 14.46% | 15.21% (3,024 / 19,884 lines across all 128 non-gen files) | Replaced heuristic 1,881-line estimate with exact measurement (855 lines found) via temporary test harness on a throwaway branch. |
| **A3. Analyzer Suppressions** | 0 diagnostics found without caveats | 0 diagnostics reported, with 8 ignore comments active | AST audit revealed 6 ignores in generated code and 2 in hand-written files (`nutri_score_calculator.dart`, `voice_assistant_service.dart`). |
| **A4. Live Interoperability** | "External service live exchange rate: 3/3 PASS" | "Endpoint reachability: 3/3 PASS"; Valid exchange NOT TESTED | HTTP 405, 400, and 404 prove network connectivity, not authenticated transactions. Marked valid exchange as NOT TESTED. |
| **A5. Modifiability Counts** | ">100 tests failed" | 5 broken files, 20 failed suites out of 32, 113 blocked tests | Dart 3 exhaustive enum pattern matching caused compile failures in 5 consumer files. Zero tests failed assertions. |
| **A6. Layer Violations** | 12 layer violations reported | 15 layer violations (12 SERVICES->SCREENS + 3 DATA->SERVICES) | Included 3 upward imports from `product_repository.dart` and `backend_locator.dart` into services. |
| **A7. Privacy Masking** | Unmasked worker hostname printed | Masked placeholders used throughout reports | Frozen Run 1 raw log retains unmasked host per immutability rule. Reports use masked placeholders. |

*Note on Table 10:* Discrepancies between initial plans and final evaluation logs were corrected following dual-method audits. Locked thresholds and Run 1 evidence were not altered.

---

## Section 7. Overall Findings

Table 11 summarizes outcomes for all ten technical measures. Table 12 examines concordances and discrepancies between survey ratings and technical findings.

#### Table 11. Technical Evaluation Outcome Totals
| Outcome Status | Count | Percentage of Evaluated Measures | Measures Included |
| :--- | :--- | :--- | :--- |
| **PASS** | 4 | 40.0% | Mock Contract Conformance, Endpoint Reachability, Shared Component Reusability, Static Diagnostic Density |
| **FAIL** | 4 | 40.0% | Layer Dependency Violations, File Size Concentration (>500 LOC), Regression Defect Rate, Net Line Coverage |
| **NOT TESTED** | 2 | 20.0% | Hardware Co-existence Conflict Rate, Valid Authenticated Live Data Exchange |
| **TOTAL** | **10** | **100.0%** | **All locked technical evaluation measures** |

*Note on Table 11:* Four measures passed and four failed under locked thresholds. Two measures could not be tested due to missing devices and credentials.

#### Table 12. Triangulation of Survey Perception vs. Technical Findings
| Evaluation Area | User Perception (Survey, $n = 50$) | Technical Finding (Run 1) | Agreement or Gap |
| :--- | :--- | :--- | :--- |
| **Performance & Responsiveness** | Mean = 4.58 (Very High); users reported fast scanning and zero phone slowdown | Static analysis passed; however, execution latency and thread usage were not instrumented | Partial agreement; user satisfaction is high, but technical profiling is absent |
| **Reliability & Stability** | Mean = 4.70 (Very High); zero reported crashes during test sessions | Automated test suite passed 160/160 tests; however, line coverage is 15.21% | Perceptual-technical gap; absence of crashes in basic tasks does not guarantee reliability in edge cases |
| **Security & Privacy** | Mean = 4.78 (Very High); users felt confident in data and login safety | Zero private keys or passwords leaked in evidence; live authenticated exchange unverified | Perceptual-technical gap; user confidence is high, but formal penetration testing was not conducted |
| **Maintainability & Modularity** | Not directly perceivable by end users; users completed tasks with 84% independence | 15 architectural layer violations, 3 circular cycles, 34 files over 500 LOC, cascading build breaks | Critical divergence; internal architectural decay is invisible to users until regression defects manifest |

The locked layering rules in `evidence/thresholds_locked.md` specify that the presentation layer may depend on services, data, and models. The service layer must not depend on screens. The data and domain layer must not depend on screens or services. The AST analysis identified 15 layer violations. Twelve violations occur within a single file, `lib/services/voice_command_router.dart`, which imports 12 separate screen widgets. These imports create an 11-file circular dependency cycle. The remaining three violations stem from `lib/data/repositories/product_repository.dart` and `lib/data/services/backend_locator.dart` importing application services.

Live interoperability testing demonstrated endpoint reachability. All three backend targets responded with standard HTTP status codes. The Gemini proxy returned HTTP 405 (Method Not Allowed for GET). The Cloudinary API returned HTTP 400 (Bad Request for missing parameters). The Firebase Identity Toolkit returned HTTP 404 (Not Found for root path). These responses confirm DNS resolution, network routing, and server availability. They do not demonstrate valid authenticated transactions.

Modifiability testing revealed significant compile-time coupling. Adding the `sesame` allergen case to the `HealthProfile` enum caused compilation errors in five consumer files across three layers. The build failure blocked 20 out of 32 test suites from compiling. Exactly 113 unit tests were compile-blocked, 47 tests passed in unaffected suites, and zero tests failed assertions. Dart 3's exhaustive switch pattern matching safely detected unhandled cases at build time. However, under the locked evaluation threshold ($X = 0$), cascading compile breakage outside the modified file constitutes an evaluation failure.

Line coverage across the application was 15.21%. The 160 automated tests executed 3,024 lines out of 19,884 total executable lines across 128 non-generated source files. Nine source files were completely un-imported by tests, representing 855 uninstrumented executable lines. Coverage remains well below the locked 70.0% threshold.

Commit history analysis confirmed that unit tests expanded from 87 to 160 tests between commit `385be19` (2026-09-22) and commit `b843690` (2026-10-23). The evaluation thresholds were locked in commit `9a35196` on 2026-10-26. Zero tests were added after the lock commit.

---

## Section 8. Limitations and Threats to Validity

Table 13 outlines the methodological and empirical limitations of the Run 1 evaluation.

#### Table 13. Limitations and Threats to Validity
| Limitation | Description | Effect on Evaluation Results |
| :--- | :--- | :--- |
| **Self-testing by development team** | Tests and scripts were executed by the development team using an AI assistant. | Increases risk of evaluator bias; no independent verification lab confirmed the results. |
| **Absence of physical device matrix** | Testing was performed without attached physical Android phones or virtual emulators. | Native sensor locks, camera concurrency, and background low-memory kills remain unverified. |
| **Proxy measures for maintainability** | Single-responsibility concentration was evaluated using a 500-LOC file threshold. | Lines of code do not directly measure cognitive complexity, cyclomatic complexity, or Halstead volume. |
| **Unratified team-defined thresholds** | Evaluation thresholds were defined by the development team pending academic adviser approval. | Thresholds may require revision if advisers mandate stricter or standardized metrics. |
| **Subjective perception in survey data** | Survey responses measure user impressions rather than technical benchmarks. | High survey satisfaction may mask underlying security, stability, or concurrency defects. |
| **Survey ceiling effect** | All Likert responses scored 4 or 5; no responses scored 1, 2, or 3. | Lack of variance restricts discriminatory power across sub-characteristics. |
| **Small survey sample size** | The survey sample was limited to 50 participants from a single institution. | Limits statistical generalizability across broader user populations. |
| **Double-barreled survey items** | Items Q10, Q12, and Q14 combined multiple attributes (e.g., text, colors, layout). | Prevents attributing ratings to specific design elements or sub-characteristics. |
| **Absence of authenticated exchange check** | Live interoperability only verified endpoint reachability via HTTP response codes. | End-to-end data serialization and authentication token refresh remain unverified. |
| **Unavailable ISO/IEC 25023 official text** | Specific measurement formulas were adapted from 25010 sub-characteristics. | Prevents claiming formal compliance with ISO/IEC 25023 measurement standards. |

*Note on Table 13:* Methodological limitations reflect early developer-side evaluation constraints. Identified threats will be addressed during subsequent evaluation cycles.

---

## Section 9. Recommendations

Table 14 lists prioritized architectural and testing recommendations derived from Run 1 findings.

#### Table 14. Prioritized Recommendations for Application Remediation
| Priority | Recommendation | Specific Technical Finding Addressed | Target Sub-characteristic |
| :--- | :--- | :--- | :--- |
| **R1** | Refactor `VoiceCommandRouter` to eliminate screen imports | 12 layer violations where a service directly imports and instantiates UI screens | Maintainability: Modularity |
| **R2** | Decompose oversized UI screens exceeding 1,000 LOC | 34 files exceed 500 LOC, led by `product_detail_screen.dart` at 4,154 LOC | Maintainability: Modularity |
| **R3** | Expand automated test suite to un-imported screens and services | 9 non-generated files have 0% test coverage; overall net coverage is 15.21% | Maintainability: Testability |
| **R4** | Introduce domain mapping abstraction for enum switch statements | Schema mutation broke compilation in 5 consumer files and 20 test suites | Maintainability: Modifiability |
| **R5** | Provision dedicated test credentials for live authenticated exchanges | Live interoperability tested only HTTP reachability; exchange was NOT TESTED | Compatibility: Interoperability |
| **R6** | Establish physical device test matrix for camera and audio contention | Co-existence was marked NOT TESTED due to 0 attached hardware devices | Compatibility: Co-existence |

*Note on Table 14:* Recommendations address root causes of evaluation failures. Remediation will be executed on a dedicated branch during Part D.

---

## Appendix A. Numerical Traceability Table

Table A.1 traces all computed figures, sample counts, and percentages to their source evidence files and calculation scripts.

#### Table A.1. Numerical Traceability and Verification Matrix
| Metric or Value | Where Used in Document | Primary Source File | Derivation or Computation Method |
| :--- | :--- | :--- | :--- |
| **$n = 50$ respondents** | Section 1, Section 5, Tables 5, 6 | Survey raw data block | Total validated survey respondents |
| **40 sub-characteristics** | Section 2, Table 2 | ISO/IEC 25010:2023 text | Sum of sub-characteristics across all 9 quality characteristics |
| **9 direct, 14 indirect, 17 not evaluated** | Section 2, Table 2 | `evidence/scripts/breakdown_check.py` | Automated aggregation of mapping categories |
| **160 automated tests** | Section 1, Section 6, Table 8 | `evidence/run1/test_run.txt` | `flutter test` execution log (`+160: All tests passed!`) |
| **15.21% net line coverage** | Section 3, Section 6, Table 8 | `item2_real_lf_measurement.txt` | $3,024 \text{ LH} / 19,884 \text{ LF}$ across 128 non-generated files |
| **15.89% lcov coverage** | Section 3, Section 6, Table 8 | `evidence/run1/coverage_analysis.txt` | $3,024 \text{ LH} / 19,029 \text{ LF}$ across 119 files in `lcov.info` |
| **855 uninstrumented lines** | Section 3, Section 6, Table 10 | `item2_real_lf_measurement.txt` | Sum of LF across 9 un-imported files via throwaway test harness |
| **128 non-generated source files** | Section 3, Section 6, Table 8 | `item1_non_generated_files.txt` | Count of `.dart` files excluding `.g.dart`, `/generated/`, and `firebase_options.dart` |
| **34 files > 500 LOC (26.56%)** | Section 3, Section 6, Table 8 | `evidence/run1/modularity_analysis.txt` | $34 / 128 = 26.56\%$ ($34 / 129 = 26.36\%$ if including `firebase_options.dart`) |
| **15 layer violations** | Section 3, Section 6, Table 8 | `a6_layer_matrix_reconciliation.txt` | 12 `SERVICES->SCREENS` + 3 `DATA->SERVICES` import edges |
| **3 circular cycles** | Section 3, Section 6, Table 8 | `evidence/run1/modularity_analysis.txt` | Tarjan's Strongly Connected Components algorithm (cycles of size 2, 3, and 11) |
| **33 / 68 reused components (48.53%)** | Section 3, Section 6, Table 8 | `evidence/run1/reusability_analysis.txt` | Components imported by $\ge 2$ distinct feature modules |
| **8 analyzer ignore directives** | Section 3, Section 6, Table 10 | `item4_ignore_comments.txt` | 6 in generated files, 2 in hand-written files |
| **20 of 32 failed test suites** | Section 6, Section 7, Table 8 | `a5_modifiability_exact.txt` | Test suites failing compilation following `HealthProfile` enum mutation |
| **113 blocked tests, 47 passed** | Section 6, Section 7, Table 8 | `a5_modifiability_exact.txt` | Breakdown of 160 total tests during modifiability evaluation |
| **3 / 3 reachable endpoints** | Section 3, Section 6, Table 8 | `evidence/run1/live_interop_checks.txt` | HTTP status codes 405, 400, and 404 from external backends |
| **Survey Mean = 4.50 to 4.78** | Section 5, Table 5 | `evidence/scripts/breakdown_check.py` | Weighted arithmetic mean: $\sum (i \times \text{count}_i) / 50$ |
| **10 technical measures (4 PASS, 4 FAIL, 2 NOT TESTED)** | Section 7, Table 11 | `evidence/scripts/breakdown_check.py` | Sum of outcomes across locked evaluation measures |

---

## Appendix B. Survey Item to Sub-Characteristic Mapping Justifications

Table B.1 details the rationale for mapping survey items to ISO/IEC 25010:2023 sub-characteristics.

#### Table B.1. Mapping Rationales for Survey Questionnaire Items
| Survey Item | Questionnaire Text | Mapped Sub-characteristic | Methodological Justification |
| :--- | :--- | :--- | :--- |
| **Q5** | Recognized cans and noodles correctly | Functional Correctness | Direct user assessment of whether product detection matched real-world items. |
| **Q6** | Health and allergy warnings matched profile | Functional Correctness, Hazard Warning | Direct assessment of warning accuracy and safety hazard notification for user allergies. |
| **Q7** | Healthier suggestions and comparisons were relevant | Functional Appropriateness | Evaluates whether dietary recommendations appropriately addressed user health goals. |
| **Q8** | Results appeared quickly | Performance Time Behaviour | Captures subjective user perception of scanning and processing latency. |
| **Q9** | Scanner did not lag or slow my phone | Performance Time Behaviour, Resource Utilization | Assesses both interface frame rate and perceived device resource strain. |
| **Q10** | Text, buttons, colors, layout clear and readable | Operability, Inclusivity, Self-descriptiveness | Evaluates UI legibility, component clarity, and accessibility for low-vision users. |
| **Q11** | Voice assistant easy to understand and use | User Assistance, Inclusivity | Evaluates voice guidance as an assistive technology for hands-free and low-vision operation. |
| **Q12** | App did not crash; profile, favorites, past scans always available | Faultlessness, Availability | Captures user-perceived operational stability and persistent access to cached health records. |
| **Q13** | Confident health data and login are safe and private | Security Confidentiality | Measures subjective user trust regarding personal medical profile data protection. |
| **Q14** | App looked good and worked well on my phone | Operability, User Engagement, Flexibility Adaptability | Evaluates visual satisfaction, general ease of use, and device-level operational fitness. |
| **Q15** | Completed the tasks (Alone / With help / Could not) | Learnability, Operability | Task completion autonomy serves as an empirical indicator of application learnability. |
