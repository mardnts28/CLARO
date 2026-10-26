#!/usr/bin/env python3
"""
coverage_audit.py - Recomputes gross and net line coverage completeness across all non-generated files.
Standard baseline: Adapted from ISO/IEC 25010:2023 Testability sub-characteristic.
"""
import os

def parse_lcov(filepath):
    files = {}
    current_file = None
    lf = 0
    lh = 0
    for line in open(filepath):
        line = line.strip()
        if line.startswith('SF:'):
            current_file = line[3:]
            lf = 0
            lh = 0
        elif line.startswith('LF:'):
            lf = int(line[3:])
        elif line.startswith('LH:'):
            lh = int(line[3:])
        elif line == 'end_of_record':
            if current_file:
                files[current_file] = {'lf': lf, 'lh': lh}
    return files

def main():
    lcov_path = 'evidence/run1/lcov.info'
    if not os.path.exists(lcov_path):
        print(f"Error: {lcov_path} not found.")
        return

    lcov_data = parse_lcov(lcov_path)
    
    # 1. Gross Coverage (all instrumented files in lcov.info)
    gross_lh = sum(v['lh'] for v in lcov_data.values())
    gross_lf = sum(v['lf'] for v in lcov_data.values())
    gross_cov = (gross_lh / gross_lf) * 100 if gross_lf else 0

    print("=== GROSS COVERAGE (Without Exclusions) ===")
    print(f"Total instrumented files in lcov: {len(lcov_data)}")
    print(f"Lines Hit (LH): {gross_lh}")
    print(f"Lines Found (LF): {gross_lf}")
    print(f"Gross Coverage: {gross_cov:.2f}%\n")

    # 2. Net Coverage (applying locked exclusions: *.g.dart, lib/generated/**, firebase_options.dart)
    exclusions = ['.g.dart', 'lib/generated/', 'firebase_options.dart']
    net_data = {
        f: v for f, v in lcov_data.items()
        if not any(ex in f for ex in exclusions)
    }
    net_lh = sum(v['lh'] for v in net_data.values())
    net_lf = sum(v['lf'] for v in net_data.values())
    net_cov = (net_lh / net_lf) * 100 if net_lf else 0

    print("=== RUN 1 NET COVERAGE (Exclusions Applied: 119 lcov files) ===")
    print(f"Total evaluated files in lcov: {len(net_data)}")
    print(f"Lines Hit (LH): {net_lh}")
    print(f"Lines Found (LF): {net_lf}")
    print(f"Run 1 Net Coverage: {net_cov:.2f}%\n")

    # 3. Measured LF for the 9 un-imported non-generated files (Measurement Aid on throwaway branch)
    # Note: lib/services/yolo_recognition_service.dart contains only library exports and 0 executable lines.
    measured_missing = {
        'lib/main.dart': 159,
        'lib/screens/get_started_screen.dart': 203,
        'lib/screens/select_language_screen.dart': 292,
        'lib/screens/splash_screen.dart': 56,
        'lib/services/get_started_service.dart': 9,
        'lib/services/yolo_recognition_service.dart': 0,
        'lib/services/yolo_recognition_service_web.dart': 19,
        'lib/widgets/dome_clipper.dart': 33,
        'lib/widgets/dome_page_route.dart': 84,
    }

    missing_lf_total = sum(measured_missing.values())
    print("=== MEASURED LF FOR 9 UN-IMPORTED FILES (Measurement Aid) ===")
    for f, lf in sorted(measured_missing.items()):
        print(f"  {f:<45}: {lf:4d} lines")
    print(f"Total measured LF for missing files: {missing_lf_total} lines\n")

    # 4. Corrected Net Coverage across all 128 non-generated hand-written files
    corrected_files_count = len(net_data) + len(measured_missing)
    corrected_lf = net_lf + missing_lf_total
    corrected_cov = (net_lh / corrected_lf) * 100

    print("=== CORRECTED NET COVERAGE (All 128 Non-Generated Hand-Written Files) ===")
    print(f"Total Non-Generated Files: {corrected_files_count} files")
    print(f"Lines Found (LF): {net_lf} + {missing_lf_total} = {corrected_lf}")
    print(f"Lines Hit (LH): {net_lh}")
    print(f"Corrected Net Coverage: {net_lh} / {corrected_lf} = {corrected_cov:.2f}%")
    print(f"Locked Threshold: >= 70.0%")
    print(f"Result: {'PASS' if corrected_cov >= 70.0 else 'FAIL'}")

if __name__ == '__main__':
    main()
