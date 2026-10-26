#!/usr/bin/env python3
"""
modularity_analysis.py - Evaluates architectural layer dependency violations,
circular dependencies (Tarjan's strongly connected components), and LOC size proxy.
Standard baseline: Adapted from ISO/IEC 25010:2023 Modularity sub-characteristic.
"""
import os
import re
import glob
from collections import defaultdict

def main():
    lib_files = sorted(glob.glob('lib/**/*.dart', recursive=True))
    # Exclude generated localization files (*.g.dart, /generated/) and FlutterFire CLI options
    generated_markers = ['.g.dart', '/generated/', 'firebase_options.dart']
    non_generated = [f for f in lib_files if not any(m in f for m in generated_markers)]
    
    print(f"Total non-generated files evaluated (excl. generated & firebase_options): {len(non_generated)}")

    # 1. Size proxy (> 500 LOC)
    over_500 = []
    loc_dict = {}
    for f in non_generated:
        with open(f, 'r', errors='ignore') as fp:
            lines = len(fp.readlines())
            loc_dict[f] = lines
            if lines > 500:
                over_500.append((f, lines))

    print(f"\n=== SIZE PROXY: FILES > 500 LOC ===")
    print(f"Files > 500 LOC: {len(over_500)} / {len(non_generated)} ({len(over_500)/len(non_generated)*100:.2f}%)")
    over_500.sort(key=lambda x: x[1], reverse=True)
    for f, count in over_500[:10]:
        print(f"   {count:4d} LOC - {f}")

    # 2. Architectural Layer Classification per thresholds_locked.md
    def get_layer(path):
        if path.startswith('lib/screens/') or path.startswith('lib/widgets/'):
            return 'UI'
        elif path.startswith('lib/services/'):
            return 'SERVICES'
        elif path.startswith('lib/data/') or path.startswith('lib/models/') or path.startswith('lib/core/'):
            return 'DATA_DOMAIN'
        return 'OTHER'

    pkg_import_regex = re.compile(r"^\s*import\s+['\"]package:claro/([^'\"]+)['\"]")
    rel_import_regex = re.compile(r"^\s*import\s+['\"](\.[^'\"]+)['\"]")

    graph = defaultdict(set)
    violations = []
    matrix = defaultdict(lambda: defaultdict(int))

    for src in non_generated:
        src_layer = get_layer(src)
        src_dir = os.path.dirname(src)
        with open(src, 'r', errors='ignore') as fp:
            for line_no, line in enumerate(fp, 1):
                target_rel = None
                m1 = pkg_import_regex.match(line)
                if m1:
                    target_rel = os.path.normpath('lib/' + m1.group(1))
                else:
                    m2 = rel_import_regex.match(line)
                    if m2:
                        target_rel = os.path.normpath(os.path.join(src_dir, m2.group(1)))

                if target_rel and target_rel in non_generated:
                    target_layer = get_layer(target_rel)
                    graph[src].add(target_rel)
                    matrix[src_layer][target_layer] += 1

                    # Check architectural violations:
                    # - Service layer must not depend on UI (lib/screens/ or lib/widgets/)
                    # - Data/Domain layer must not depend on UI or Services
                    if src_layer == 'SERVICES' and (target_layer == 'UI' or target_rel.startswith('lib/screens/')):
                        violations.append((src, line_no, target_rel, 'SERVICES imports SCREENS/UI'))
                    elif src_layer == 'DATA_DOMAIN' and target_layer == 'UI':
                        violations.append((src, line_no, target_rel, 'DATA_DOMAIN imports UI'))
                    elif src_layer == 'DATA_DOMAIN' and target_layer == 'SERVICES':
                        violations.append((src, line_no, target_rel, 'DATA_DOMAIN imports SERVICES'))

    print("\n=== LAYER DEPENDENCY MATRIX (Source Layer -> Target Layer Imports) ===")
    layers = ['UI', 'SERVICES', 'DATA_DOMAIN', 'OTHER']
    col_name = 'Source \\ Target'
    header = f"{col_name:<16} | " + " | ".join(f"{l:<12}" for l in layers)
    print(header)
    print("-" * len(header))
    for sl in layers:
        row = f"{sl:<16} | " + " | ".join(f"{matrix[sl][tl]:<12}" for tl in layers)
        print(row)

    print(f"\n=== ARCHITECTURAL LAYER VIOLATIONS ===")
    print(f"Total layer violations: {len(violations)}")
    for src, line_no, target_rel, reason in violations:
        print(f"  [VIOLATION] {reason}: {src}:{line_no} -> {target_rel}")

    # 3. Cycle Detection using Tarjan's Strongly Connected Components
    index = 0
    indices = {}
    lowlinks = {}
    stack = []
    on_stack = set()
    sccs = []

    def strongconnect(v):
        nonlocal index
        indices[v] = index
        lowlinks[v] = index
        index += 1
        stack.append(v)
        on_stack.add(v)

        for w in graph.get(v, []):
            if w not in indices:
                strongconnect(w)
                lowlinks[v] = min(lowlinks[v], lowlinks[w])
            elif w in on_stack:
                lowlinks[v] = min(lowlinks[v], indices[w])

        if lowlinks[v] == indices[v]:
            scc = []
            while True:
                w = stack.pop()
                on_stack.remove(w)
                scc.append(w)
                if w == v:
                    break
            if len(scc) > 1:
                sccs.append(scc)

    for node in non_generated:
        if node not in indices:
            strongconnect(node)

    print(f"\n=== CIRCULAR DEPENDENCIES (SCCs > 1) ===")
    print(f"Total circular dependency cycles: {len(sccs)}")
    for i, scc in enumerate(sccs, 1):
        print(f"  Cycle {i} ({len(scc)} files):")
        for f in scc:
            print(f"    - {f}")

if __name__ == '__main__':
    main()
