#!/usr/bin/env python3
"""Stack every session's CSV tables into one file per table.

Usage:
    python3 tools/aggregate_study_data.py <study_data_dir> [output_dir]

<study_data_dir> is the folder holding one subfolder per session (named like
P<code>_visit<N>_<date>_<time>). In an exported build it sits next to the
game executable; when running from the Godot editor on macOS it is
  ~/Library/Application Support/Godot/app_userdata/PlazaPalabra/study_data
(on Linux: ~/.local/share/godot/app_userdata/PlazaPalabra/study_data).

Output (default: <study_data_dir>/combined/): events.csv, word_stats.csv,
recall_quiz.csv, survey_pre.csv, survey_post.csv, survey_followup.csv,
recap_assignment.csv, spell_progress.csv, session.csv. Every row already
carries session_id, participant_code and visit, so the stacked files can be
filtered/joined directly in Excel, LibreOffice, pandas or R.

Standard library only.
"""
import csv
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    root = Path(sys.argv[1]).expanduser()
    out_dir = Path(sys.argv[2]).expanduser() if len(sys.argv) > 2 else root / "combined"
    sessions = sorted(p for p in root.iterdir() if p.is_dir() and p.name != out_dir.name)
    if not sessions:
        print(f"No session folders found in {root}")
        return 1
    tables: dict[str, dict] = {}
    for session in sessions:
        for csv_path in sorted(session.glob("*.csv")):
            with csv_path.open(newline="", encoding="utf-8") as f:
                reader = csv.reader(f)
                header = next(reader, None)
                if header is None:
                    continue
                table = tables.setdefault(csv_path.name, {"header": header, "rows": []})
                if header != table["header"]:
                    print(f"  skipping {csv_path} (columns differ from earlier sessions)")
                    continue
                table["rows"].extend(reader)
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, table in sorted(tables.items()):
        with (out_dir / name).open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(table["header"])
            writer.writerows(table["rows"])
        print(f"{name}: {len(table['rows'])} rows from {len(sessions)} sessions")
    print(f"Wrote {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
