#!/usr/bin/env python3
"""
reusability_analysis.py - Evaluates shared component utilization ratio across modules.
Standard baseline: Adapted from ISO/IEC 25010:2023 Reusability sub-characteristic.
"""
import os
import re
import glob
from collections import defaultdict

def main():
    target_folders = ['lib/widgets/', 'lib/services/', 'lib/core/']
    lib_files = glob.glob('lib/**/*.dart', recursive=True)
    generated_markers = ['.g.dart', '/generated/', 'firebase_options.dart']
    non_generated = [f for f in lib_files if not any(m in f for m in generated_markers)]

    components = [f for f in non_generated if any(f.startswith(prefix) for prefix in target_folders)]

    pkg_import_regex = re.compile(r"^\s*import\s+['\"]package:claro/([^'\"]+)['\"]")
    rel_import_regex = re.compile(r"^\s*import\s+['\"](\.[^'\"]+)['\"]")

    imported_by = defaultdict(set)

    for src in non_generated:
        src_dir = os.path.dirname(src)
        with open(src, 'r', errors='ignore') as fp:
            for line in fp:
                target_rel = None
                m1 = pkg_import_regex.match(line)
                if m1:
                    target_rel = os.path.normpath('lib/' + m1.group(1))
                else:
                    m2 = rel_import_regex.match(line)
                    if m2:
                        target_rel = os.path.normpath(os.path.join(src_dir, m2.group(1)))

                if target_rel and target_rel in components and target_rel != src:
                    if src.startswith('lib/screens/'):
                        feature = os.path.basename(src).replace('.dart', '')
                    else:
                        feature = os.path.dirname(src)
                    imported_by[target_rel].add(feature)

    reused = [c for c in components if len(imported_by[c]) >= 2]
    reusability_ratio = len(reused) / len(components) if components else 0

    print("=== REUSABILITY HEURISTIC ANALYSIS ===")
    print(f"Target shared components in lib/widgets, lib/services, lib/core: {len(components)}")
    print(f"Components imported by >= 2 distinct feature modules: {len(reused)} ({reusability_ratio*100:.2f}%)")
    print(f"Reusability ratio (X): {len(reused)} / {len(components)} = {reusability_ratio:.4f}")
    print(f"Locked Threshold: X >= 0.30 (30.0%)")
    print(f"Result: {'PASS' if reusability_ratio >= 0.30 else 'FAIL'}")

if __name__ == '__main__':
    main()
