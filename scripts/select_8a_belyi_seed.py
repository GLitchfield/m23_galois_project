#!/usr/bin/env python3
"""Apply the predeclared joint Tutte/circle-packing chart selection rule."""
from __future__ import annotations

import argparse
import csv
import hashlib
import math
from pathlib import Path
import subprocess


METRICS = (
    ('relative_residual', False),
    ('equilibrated_jacobian_condition', False),
    ('normalized_root_separation', True),
)
CIRCLE_RESIDUAL_MAX = 0.5
CIRCLE_CONDITION_MAX = 1e14
CIRCLE_SEPARATION_MIN = 1e-8


def rows(path: Path) -> list[dict[str, str]]:
    return list(csv.DictReader(
        (line for line in path.read_text().splitlines()
         if not line.startswith('#')), delimiter='\t'))


def key(row: dict[str, str]) -> tuple[int, str]:
    return int(row['rotation']), row['normalization']


def ranked(records: list[dict[str, str]], field: str,
           reverse: bool) -> dict[tuple[int, str], int]:
    def order(row: dict[str, str]) -> tuple[float, int, str]:
        value = float(row[field])
        return (-value if reverse else value, *key(row))
    return {key(row): rank for rank, row in
            enumerate(sorted(records, key=order), 1)}


def dominates(left: dict[str, str], right: dict[str, str]) -> bool:
    comparisons = []
    for prefix in ('tutte_', 'circle_'):
        comparisons.extend((
            float(left[prefix+'relative_residual']) <=
            float(right[prefix+'relative_residual']),
            float(left[prefix+'equilibrated_jacobian_condition']) <=
            float(right[prefix+'equilibrated_jacobian_condition']),
            float(left[prefix+'normalized_root_separation']) >=
            float(right[prefix+'normalized_root_separation']),
        ))
    if not all(comparisons):
        return False
    return any(
        float(left[prefix+field]) != float(right[prefix+field])
        for prefix in ('tutte_', 'circle_') for field, _ in METRICS)


def select(tutte: list[dict[str, str]], circle: list[dict[str, str]],
           class_id: int = 22) -> dict[str, object]:
    selected_tutte = [row for row in tutte if int(row['class_id']) == class_id]
    selected_circle = [row for row in circle if int(row['class_id']) == class_id]
    if len(selected_tutte) != 18 or len(selected_circle) != 18:
        raise ValueError('selection requires exactly 18 rows per seed method')
    if {key(row) for row in selected_tutte} != {key(row) for row in selected_circle}:
        raise ValueError('Tutte and circle-packing chart keys differ')
    ranks = {}
    for prefix, records in (('tutte', selected_tutte), ('circle', selected_circle)):
        for field, reverse in METRICS:
            ranks[(prefix, field)] = ranked(records, field, reverse)
    by_tutte = {key(row): row for row in selected_tutte}
    by_circle = {key(row): row for row in selected_circle}
    combined = []
    for chart in sorted(by_tutte):
        row: dict[str, object] = {
            'class_id': class_id,
            'rotation': chart[0],
            'normalization': chart[1],
        }
        chart_ranks = []
        for prefix, source in (('tutte', by_tutte), ('circle', by_circle)):
            for field, _ in METRICS:
                row[prefix+'_'+field] = float(source[chart][field])
                rank = ranks[(prefix, field)][chart]
                row[prefix+'_'+field+'_rank'] = rank
                chart_ranks.append(rank)
        row['worst_ordinal_rank'] = max(chart_ranks)
        row['ordinal_rank_sum'] = sum(chart_ranks)
        combined.append(row)
    combined.sort(key=lambda row: (
        row['worst_ordinal_rank'], row['ordinal_rank_sum'],
        row['tutte_relative_residual_rank']+row['circle_relative_residual_rank'],
        row['tutte_equilibrated_jacobian_condition_rank']+
        row['circle_equilibrated_jacobian_condition_rank'],
        row['rotation'], row['normalization']))
    choice = combined[0]
    choice['joint_pareto'] = not any(
        dominates(row, choice) for row in combined[1:])
    circle_values = [choice['circle_'+field] for field, _ in METRICS]
    choice['finite_metrics'] = all(math.isfinite(value) for value in circle_values)
    choice['circle_residual_gate'] = (
        choice['circle_relative_residual'] <= CIRCLE_RESIDUAL_MAX)
    choice['circle_condition_gate'] = (
        choice['circle_equilibrated_jacobian_condition'] <= CIRCLE_CONDITION_MAX)
    choice['circle_separation_gate'] = (
        choice['circle_normalized_root_separation'] >= CIRCLE_SEPARATION_MIN)
    choice['admissible'] = all((
        choice['joint_pareto'], choice['finite_metrics'],
        choice['circle_residual_gate'], choice['circle_condition_gate'],
        choice['circle_separation_gate']))
    failed = [name for name in (
        'joint_pareto', 'finite_metrics', 'circle_residual_gate',
        'circle_condition_gate', 'circle_separation_gate') if not choice[name]]
    choice['failed_gates'] = ','.join(failed) if failed else 'none'
    return choice


def revision(root: Path) -> str:
    return subprocess.run(
        ['git', 'rev-parse', 'HEAD'], cwd=root, check=True,
        text=True, capture_output=True).stdout.strip()


def render(choice: dict[str, object], tutte_path: Path | None = None,
           circle_path: Path | None = None) -> str:
    headers = []
    if tutte_path is not None and circle_path is not None:
        root = Path(__file__).resolve().parents[1]
        headers = [
            '# generated_by\tscripts/select_8a_belyi_seed.py',
            f'# code_revision\t{revision(root)}',
            f'# tutte_input\t{tutte_path}',
            f'# tutte_sha256\t{hashlib.sha256(tutte_path.read_bytes()).hexdigest()}',
            f'# circle_input\t{circle_path}',
            f'# circle_sha256\t{hashlib.sha256(circle_path.read_bytes()).hexdigest()}',
            '# rule\tdocs/8a-seed-selection-rule.md',
            '# interpretation\tpredeclared seed admissibility decision; not a Belyi map',
        ]
    fields = list(choice)
    values = []
    for field in fields:
        value = choice[field]
        if isinstance(value, bool):
            values.append(str(value).lower())
        elif isinstance(value, float):
            values.append(format(value, '.17g'))
        else:
            values.append(str(value))
    table = '\t'.join(fields)+'\n'+'\t'.join(values)+'\n'
    return ('\n'.join(headers)+'\n' if headers else '')+table


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('tutte_tsv', type=Path)
    parser.add_argument('circle_tsv', type=Path)
    parser.add_argument('--class-id', type=int, default=22)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        choice = select(rows(args.tutte_tsv), rows(args.circle_tsv), args.class_id)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    output = render(choice, args.tutte_tsv, args.circle_tsv)
    if args.output:
        args.output.write_text(output)
    else:
        print(output, end='')


if __name__ == '__main__':
    main()
