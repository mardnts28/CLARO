#!/usr/bin/env python3
"""
breakdown_check.py - Computes and verifies all numerical values, percentages,
means, sub-characteristic counts, and technical metrics for RESULTS_BREAKDOWN.md.
"""
import os
import hashlib

def interpret(mean):
    if 1.00 <= mean <= 1.80:
        return 'Very Low'
    elif 1.81 <= mean <= 2.60:
        return 'Low'
    elif 2.61 <= mean <= 3.40:
        return 'Moderate'
    elif 3.41 <= mean <= 4.20:
        return 'High'
    elif 4.21 <= mean <= 5.00:
        return 'Very High'
    return 'Undefined'

def compute_survey():
    survey_data = {
        'Q5': ('Recognized cans and noodles correctly', [0, 0, 0, 25, 25], 'Functional Suitability: Correctness'),
        'Q6': ('Health and allergy warnings matched my profile', [0, 0, 0, 18, 32], 'Functional Suitability: Correctness; Safety: Hazard warning'),
        'Q7': ('Healthier suggestions and comparisons were relevant', [0, 0, 0, 11, 39], 'Functional Suitability: Appropriateness'),
        'Q8': ('Results appeared quickly', [0, 0, 0, 21, 29], 'Performance Efficiency: Time behaviour'),
        'Q9': ('Scanner did not lag or slow my phone', [0, 0, 0, 21, 29], 'Performance Efficiency: Time behaviour, Resource utilization'),
        'Q10': ('Text, buttons, colors, layout clear and readable', [0, 0, 0, 12, 38], 'Interaction Capability: Operability, Inclusivity, Self-descriptiveness'),
        'Q12': ('App did not crash; profile, favorites, past scans always available', [0, 0, 0, 15, 35], 'Reliability: Faultlessness, Availability'),
        'Q13': ('Confident my health data and login are safe and private', [0, 0, 0, 11, 39], 'Security: Confidentiality'),
        'Q14': ('App looked good and worked well on my phone', [0, 0, 0, 12, 38], 'Interaction Capability: Operability, User engagement; Flexibility: Adaptability'),
    }

    print("=== 1. SURVEY LIKERT ITEMS (n = 50) ===")
    results = {}
    for q_id, (statement, counts, mapped) in survey_data.items():
        n = sum(counts)
        assert n == 50, f"Error: {q_id} total count is {n}, expected 50"
        fav_n = counts[3] + counts[4]
        fav_pct = (fav_n / n) * 100.0
        mean = sum((i + 1) * count for i, count in enumerate(counts)) / n
        desc = interpret(mean)
        results[q_id] = {
            'statement': statement,
            'counts': counts,
            'n': n,
            'fav_n': fav_n,
            'fav_pct': fav_pct,
            'mean': mean,
            'desc': desc,
            'mapped': mapped
        }
        print(f"{q_id:<4} | n={n} | Counts={counts} | Fav={fav_n} ({fav_pct:.2f}%) | Mean={mean:.2f} | {desc:<10} | {statement}")

    print("\n=== 2. SURVEY CATEGORICAL / DICHOTOMOUS ITEMS (n = 50) ===")
    # Q11
    q11_n = 50
    q11_yes = 44
    q11_no = 0
    q11_not_used = 6
    assert q11_yes + q11_no + q11_not_used == q11_n
    print(f"Q11 Voice assistant: Yes={q11_yes} ({q11_yes/q11_n*100:.1f}%), No={q11_no} ({q11_no/q11_n*100:.1f}%), Not used={q11_not_used} ({q11_not_used/q11_n*100:.1f}%)")

    # Q15
    q15_n = 50
    q15_alone = 42
    q15_help = 8
    q15_could_not = 0
    assert q15_alone + q15_help + q15_could_not == q15_n
    print(f"Q15 Task completion: Alone={q15_alone} ({q15_alone/q15_n*100:.1f}%), With help={q15_help} ({q15_help/q15_n*100:.1f}%), Could not={q15_could_not} ({q15_could_not/q15_n*100:.1f}%)")

    print("\n=== 3. RESPONDENT DEMOGRAPHICS (n = 50) ===")
    ages = [('18-24', 30), ('23-34', 4), ('35-40', 16)]
    assert sum(c for _, c in ages) == 50
    for bracket, count in ages:
        print(f"Age bracket {bracket:<6}: {count:2d} ({count/50*100:.1f}%)")

    conditions = [
        ('Hypertension', 8),
        ('Diabetes', 4),
        ('Heart condition', 2),
        ('Food allergy', 4),
        ('Low vision', 19),
        ('None', 24)
    ]
    total_cond_mentions = sum(c for _, c in conditions)
    for cond, count in conditions:
        print(f"Health condition {cond:<16}: {count:2d} ({count/50*100:.1f}%)")
    print(f"Total condition mentions (multi-select): {total_cond_mentions} across 50 respondents")

    return results

def compute_subcharacteristics():
    print("\n=== 4. ISO/IEC 25010:2023 SUB-CHARACTERISTIC COVERAGE ===")
    structure = {
        'Functional Suitability': {
            'total': 3,
            'sub': ['completeness', 'correctness', 'appropriateness'],
            'direct': 2, # correctness, appropriateness
            'indirect': 1, # completeness
            'not_tested': 0,
            'not_eval': 0,
            'status': 'Partly',
            'methods': 'Survey (perception)'
        },
        'Performance Efficiency': {
            'total': 3,
            'sub': ['time behaviour', 'resource utilization', 'capacity'],
            'direct': 1, # time behaviour (survey)
            'indirect': 1, # resource utilization (survey)
            'not_tested': 0,
            'not_eval': 1, # capacity
            'status': 'Partly',
            'methods': 'Survey (perception)'
        },
        'Compatibility': {
            'total': 2,
            'sub': ['co-existence', 'interoperability'],
            'direct': 1, # interoperability (technical)
            'indirect': 0,
            'not_tested': 1, # co-existence
            'not_eval': 0,
            'status': 'Partly',
            'methods': 'Automated tests, HTTP probe'
        },
        'Interaction Capability': {
            'total': 8,
            'sub': ['appropriateness recognizability', 'learnability', 'operability',
                    'user error protection', 'user engagement', 'inclusivity',
                    'user assistance', 'self-descriptiveness'],
            'direct': 0,
            'indirect': 6, # learnability, operability, user engagement, inclusivity, user assistance, self-descriptiveness
            'not_tested': 0,
            'not_eval': 2, # appropriateness recognizability, user error protection
            'status': 'Indirect only',
            'methods': 'Survey (perception)'
        },
        'Reliability': {
            'total': 4,
            'sub': ['faultlessness', 'availability', 'fault tolerance', 'recoverability'],
            'direct': 0,
            'indirect': 2, # faultlessness, availability
            'not_tested': 0,
            'not_eval': 2, # fault tolerance, recoverability
            'status': 'Indirect only',
            'methods': 'Survey (perception)'
        },
        'Security': {
            'total': 6,
            'sub': ['confidentiality', 'integrity', 'non-repudiation',
                    'accountability', 'authenticity', 'resistance'],
            'direct': 0,
            'indirect': 1, # confidentiality
            'not_tested': 0,
            'not_eval': 5, # integrity, non-repudiation, accountability, authenticity, resistance
            'status': 'Indirect only',
            'methods': 'Survey (perception)'
        },
        'Maintainability': {
            'total': 5,
            'sub': ['modularity', 'reusability', 'analysability', 'modifiability', 'testability'],
            'direct': 5,
            'indirect': 0,
            'not_tested': 0,
            'not_eval': 0,
            'status': 'Fully',
            'methods': 'AST scripts, analyzer, test runner, lcov'
        },
        'Flexibility': {
            'total': 4,
            'sub': ['adaptability', 'scalability', 'installability', 'replaceability'],
            'direct': 0,
            'indirect': 2, # adaptability, installability
            'not_tested': 0,
            'not_eval': 2, # scalability, replaceability
            'status': 'Indirect only',
            'methods': 'Survey (perception)'
        },
        'Safety': {
            'total': 5,
            'sub': ['operational constraint', 'risk identification', 'fail safe',
                    'hazard warning', 'safe integration'],
            'direct': 0,
            'indirect': 1, # hazard warning
            'not_tested': 0,
            'not_eval': 4, # operational constraint, risk identification, fail safe, safe integration
            'status': 'Indirect only',
            'methods': 'Survey (perception)'
        }
    }

    total_sub = sum(c['total'] for c in structure.values())
    total_direct = sum(c['direct'] for c in structure.values())
    total_indirect = sum(c['indirect'] for c in structure.values())
    total_not_tested = sum(c['not_tested'] for c in structure.values())
    total_not_eval = sum(c['not_eval'] for c in structure.values())

    print(f"Total Characteristics: {len(structure)}")
    print(f"Total Sub-characteristics: {total_sub} (Expected: 40)")
    assert total_sub == 40, f"Expected 40, got {total_sub}"
    print(f"Directly evaluated: {total_direct}")
    print(f"Indirectly evaluated: {total_indirect}")
    print(f"Not tested: {total_not_tested}")
    print(f"Not evaluated: {total_not_eval}")
    assert total_direct + total_indirect + total_not_tested + total_not_eval == 40

    for char_name, c in structure.items():
        print(f"  {char_name:<24} | Total={c['total']} | Direct={c['direct']} | Indirect={c['indirect']} | NotTested={c['not_tested']} | NotEval={c['not_eval']} | Status={c['status']}")

    return structure

def compute_technical():
    print("\n=== 5. TECHNICAL MEASURE OUTCOMES (Run 1) ===")
    measures = [
        ('Compatibility', 'Co-existence', 'Co-existence conflict rate', 'NOT TESTED'),
        ('Compatibility', 'Interoperability', 'Schema contract rate (Mock)', 'PASS'),
        ('Compatibility', 'Interoperability', 'Endpoint reachability (Live)', 'PASS'),
        ('Compatibility', 'Interoperability', 'Valid authenticated exchange', 'NOT TESTED'),
        ('Maintainability', 'Modularity', 'Layer dependency violation count', 'FAIL'),
        ('Maintainability', 'Modularity', 'File size concentration (>500 LOC)', 'FAIL'),
        ('Maintainability', 'Reusability', 'Shared component utilization ratio', 'PASS'),
        ('Maintainability', 'Analysability', 'Static diagnostic density', 'PASS'),
        ('Maintainability', 'Modifiability', 'Regression defect rate upon mutation', 'FAIL'),
        ('Maintainability', 'Testability', 'Net automated line coverage', 'FAIL'),
    ]

    pass_count = sum(1 for m in measures if m[3] == 'PASS')
    fail_count = sum(1 for m in measures if m[3] == 'FAIL')
    not_tested_count = sum(1 for m in measures if m[3] == 'NOT TESTED')

    print(f"Total Technical Measures: {len(measures)}")
    print(f"  PASS: {pass_count}")
    print(f"  FAIL: {fail_count}")
    print(f"  NOT TESTED: {not_tested_count}")
    assert pass_count + fail_count + not_tested_count == len(measures)

    return measures

def verify_manifest():
    print("\n=== 6. MANIFEST & EVIDENCE VERIFICATION ===")
    manifest_path = 'evidence/MANIFEST.sha256'
    with open(manifest_path) as fp:
        lines = [l.strip() for l in fp if l.strip()]

    all_ok = True
    for line in lines:
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            expected_hash, rel_path = parts
            if not os.path.exists(rel_path):
                print(f"MISSING: {rel_path}")
                all_ok = False
            else:
                hasher = hashlib.sha256()
                with open(rel_path, 'rb') as f:
                    while chunk := f.read(8192):
                        hasher.update(chunk)
                actual_hash = hasher.hexdigest()
                if actual_hash != expected_hash:
                    print(f"HASH MISMATCH: {rel_path} (expected {expected_hash}, got {actual_hash})")
                    all_ok = False
    if all_ok:
        print(f"All {len(lines)} evidence files verified successfully against {manifest_path}.")
    else:
        print("Some evidence files failed verification.")

if __name__ == '__main__':
    compute_survey()
    compute_subcharacteristics()
    compute_technical()
    verify_manifest()
