"""
Merge T1_raw.csv and T2_raw.csv into a panel dataset.
Match: T1_raw.N1 <-> T2_raw.A1 (case-insensitive, 1:1)

Outputs:
  - merged_panel.dta / .csv   — matched T1-T2 panel (for main analysis)
  - t1_attrition.dta / .csv   — all unique T1 respondents with completed_t2 flag
"""

import pandas as pd

# ── 1. Load raw files ──────────────────────────────────────────────────
t1 = pd.read_csv("T1_raw.csv")
t2 = pd.read_csv("T2_raw.csv")

print(f"T1_raw: {t1.shape[0]} rows, {t1.shape[1]} columns")
print(f"T2_raw: {t2.shape[0]} rows, {t2.shape[1]} columns")

# ── 2. Create case-insensitive merge keys ──────────────────────────────
t1["_merge_key"] = t1["N1"].astype(str).str.strip().str.upper()
t2["_merge_key"] = t2["A1"].astype(str).str.strip().str.upper()

# ── 3. Deduplicate T1: keep one row per respondent ────────────────────
# Multiple T1 rows share the same N1 (e.g., source=0 and source=1).
# Strategy: prefer source=0 (original collection), then keep first occurrence.
t1_before = len(t1)
t1 = t1.sort_values(by=["_merge_key", "source"]).drop_duplicates(
    subset="_merge_key", keep="first"
)
t1_after = len(t1)
print(f"\n── T1 Deduplication ──")
print(f"Before: {t1_before} rows  →  After: {t1_after} unique respondents")
print(f"Dropped: {t1_before - t1_after} duplicate rows")

# ── 4. Diagnostics ────────────────────────────────────────────────────
t1_keys = set(t1["_merge_key"])
t2_keys = set(t2["_merge_key"])
matched_keys = t1_keys & t2_keys
t1_only = t1_keys - t2_keys
t2_only = t2_keys - t1_keys

print(f"\n── Merge Diagnostics ──")
print(f"Unique N1 in T1:  {len(t1_keys)}")
print(f"Unique A1 in T2:  {len(t2_keys)}")
print(f"Matched IDs:      {len(matched_keys)}")
print(f"T1-only (no T2):  {len(t1_only)}")
print(f"T2-only (no T1):  {len(t2_only)}")

if t2_only:
    print(f"  IDs in T2 not found in T1: {sorted(t2_only)}")

# ── 5. Merge T1 + T2 (inner join — matched pairs only) ───────────────
panel = pd.merge(
    t1, t2,
    on="_merge_key",
    how="inner",
    suffixes=("", "_T2_dup")
)
panel.drop(columns=["_merge_key", "A1_T2_dup"], inplace=True, errors="ignore")

print(f"\n── Merged Panel ──")
print(f"Rows:    {panel.shape[0]}  (should ≈ {len(matched_keys)} matched IDs)")
print(f"Columns: {panel.shape[1]}")

# ── 6. Rename columns to match survey instrument ─────────────────────
rename_map = {
    "A1": "age",
    "N2": "gender",
    "C3": "education",
    "C4": "occupation",
    "C5": "income",
    "C7": "relationship",
    "A2": "A2_T2",
    "A3": "A3_T2",
}

for old, new in rename_map.items():
    if old in panel.columns and new not in panel.columns:
        panel.rename(columns={old: new}, inplace=True)

# ── 6b. Add sequential panel ID ──────────────────────────────────────
panel.insert(0, "id", range(1, len(panel) + 1))

# ── 7. Convert numeric columns ───────────────────────────────────────
skip_cols = {"source", "N1", "id"}
for col in panel.columns:
    if col not in skip_cols:
        panel[col] = pd.to_numeric(panel[col], errors="coerce")

# ── 8. Save merged panel ─────────────────────────────────────────────
panel.to_csv("merged_panel.csv", index=False)
print(f"\n✓ Saved: merged_panel.csv")

try:
    sp = panel.copy()
    sp.columns = [c.replace(" ", "_").replace("-", "_")[:32] for c in sp.columns]
    if "N1" in sp.columns:
        sp["N1"] = sp["N1"].astype(str)
    sp.to_stata("merged_panel.dta", write_index=False, version=118)
    print(f"✓ Saved: merged_panel.dta")
except Exception as e:
    print(f"⚠ Could not save .dta: {e}")

# ══════════════════════════════════════════════════════════════════════
# ── 9. Create T1 attrition dataset ───────────────────────────────────
# All unique T1 respondents + flag whether they completed T2
# ══════════════════════════════════════════════════════════════════════
print(f"\n── Building T1 Attrition Dataset ──")

# Re-read T1 raw for the attrition file (need all columns, fresh copy)
t1_att = pd.read_csv("T1_raw.csv")
t1_att["_merge_key"] = t1_att["N1"].astype(str).str.strip().str.upper()

# Deduplicate same way as panel
t1_att = t1_att.sort_values(by=["_merge_key", "source"]).drop_duplicates(
    subset="_merge_key", keep="first"
)

# Flag: completed_t2 = 1 if respondent has a matching T2 record
t1_att["completed_t2"] = t1_att["_merge_key"].isin(t2_keys).astype(int)

# Apply same renames
for old, new in rename_map.items():
    if old in t1_att.columns and new not in t1_att.columns:
        t1_att.rename(columns={old: new}, inplace=True)

# Add sequential ID
t1_att.insert(0, "id", range(1, len(t1_att) + 1))

# Drop temp key
t1_att.drop(columns=["_merge_key"], inplace=True, errors="ignore")

# Convert numeric
for col in t1_att.columns:
    if col not in skip_cols:
        t1_att[col] = pd.to_numeric(t1_att[col], errors="coerce")

# Stats
n_completed = t1_att["completed_t2"].sum()
n_dropped = len(t1_att) - n_completed
print(f"Total T1 respondents: {len(t1_att)}")
print(f"Completed T2:         {n_completed}  ({100*n_completed/len(t1_att):.1f}%)")
print(f"Dropped out:          {n_dropped}  ({100*n_dropped/len(t1_att):.1f}%)")

# Save
t1_att.to_csv("t1_attrition.csv", index=False)
print(f"\n✓ Saved: t1_attrition.csv")

try:
    sa = t1_att.copy()
    sa.columns = [c.replace(" ", "_").replace("-", "_")[:32] for c in sa.columns]
    if "N1" in sa.columns:
        sa["N1"] = sa["N1"].astype(str)
    sa.to_stata("t1_attrition.dta", write_index=False, version=118)
    print(f"✓ Saved: t1_attrition.dta")
except Exception as e:
    print(f"⚠ Could not save .dta: {e}")

# ── 10. Summary ───────────────────────────────────────────────────────
print(f"\n── Panel columns ({panel.shape[1]}) ──")
for i, col in enumerate(panel.columns, 1):
    print(f"  {i:3d}. {col}")

print(f"\n── First 5 rows ──")
show_cols = [c for c in ["id", "N1", "source", "gender", "age", "education",
                          "occupation", "income", "relationship",
                          "EXP1", "IBT1", "SC1", "IPB1",
                          "EXP1_T2", "PS1_T2", "IPB1_T2"] if c in panel.columns]
print(panel[show_cols].head().to_string(index=False))

print("\n✅ All files generated!")
