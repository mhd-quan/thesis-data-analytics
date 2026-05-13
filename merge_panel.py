"""
Merge T1_raw.csv and T2_raw.csv into a panel dataset.
Match: T1_raw.N1 <-> T2_raw.A1 (case-insensitive)
Output: simulated_panel.dta (Stata format) + simulated_panel.csv
"""

import pandas as pd
import sys

# ── 1. Load raw files ──────────────────────────────────────────────────
t1 = pd.read_csv("T1_raw.csv")
t2 = pd.read_csv("T2_raw.csv")

print(f"T1_raw: {t1.shape[0]} rows, {t1.shape[1]} columns")
print(f"T2_raw: {t2.shape[0]} rows, {t2.shape[1]} columns")

# ── 2. Create case-insensitive merge keys ──────────────────────────────
# Strip whitespace and convert to uppercase for matching
t1["_merge_key"] = t1["N1"].astype(str).str.strip().str.upper()
t2["_merge_key"] = t2["A1"].astype(str).str.strip().str.upper()

# ── 3. Diagnostics before merge ───────────────────────────────────────
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
    print(f"\n  IDs in T2 not found in T1: {sorted(t2_only)}")

# ── 4. Check for duplicate merge keys ─────────────────────────────────
t1_dups = t1[t1.duplicated(subset="_merge_key", keep=False)]
t2_dups = t2[t2.duplicated(subset="_merge_key", keep=False)]

if len(t1_dups) > 0:
    dup_keys = t1_dups["_merge_key"].unique()
    print(f"\n⚠ WARNING: {len(dup_keys)} duplicate N1 values in T1_raw:")
    for k in dup_keys:
        rows = t1[t1["_merge_key"] == k]
        print(f"  '{k}': {len(rows)} rows (lines {rows.index.tolist()})")
    print("  → Keeping ALL rows (1:1 and 1:many merges will be preserved)")

if len(t2_dups) > 0:
    dup_keys = t2_dups["_merge_key"].unique()
    print(f"\n⚠ WARNING: {len(dup_keys)} duplicate A1 values in T2_raw:")
    for k in dup_keys:
        rows = t2[t2["_merge_key"] == k]
        print(f"  '{k}': {len(rows)} rows")

# ── 5. Perform inner merge (keep only matched pairs) ──────────────────
# Rename T2's A1 to avoid collision with T1's A1 (age column in T1)
# T2 columns A1, A2, A3 refer to different things than T1's A1
# T2.A1 = respondent ID (same as T1.N1), T2.A2, T2.A3 = other demographic vars
# To avoid confusion, we keep T2.A1 as the merge key only

panel = pd.merge(
    t1,
    t2,
    on="_merge_key",
    how="inner",
    suffixes=("", "_T2_dup")  # T2's A1 will become A1_T2_dup
)

# Drop the temporary merge key and the duplicate A1 from T2
panel.drop(columns=["_merge_key", "A1_T2_dup"], inplace=True, errors="ignore")

print(f"\n── Merged Panel ──")
print(f"Rows:    {panel.shape[0]}")
print(f"Columns: {panel.shape[1]}")

# ── 6. Rename columns to match Stata conventions ──────────────────────
# The .do file expects certain variable names. Let's map T1 columns
# to match the actual survey instrument:
#   A1 -> age, N2 -> gender, C3 -> education, C4 -> occupation,
#   C5 -> income, C7 -> relationship
rename_map = {
    "A1": "age",
    "N2": "gender",
    "C3": "education",
    "C4": "occupation",
    "C5": "income",
    "C7": "relationship",
    # T2 columns A2, A3 from the merge
    "A2": "A2_T2",
    "A3": "A3_T2",
}

# Only rename if columns exist and won't conflict
for old, new in rename_map.items():
    if old in panel.columns and new not in panel.columns:
        panel.rename(columns={old: new}, inplace=True)

# ── 6b. Add sequential panel ID ──────────────────────────────────────
panel.insert(0, "id", range(1, len(panel) + 1))

# ── 7. Convert numeric columns ───────────────────────────────────────
# Force numeric conversion for all survey items (they may have been read as strings)
skip_cols = {"source", "N1", "_merge_key", "id"}
for col in panel.columns:
    if col not in skip_cols:
        panel[col] = pd.to_numeric(panel[col], errors="coerce")

# ── 8. Save outputs ──────────────────────────────────────────────────
# CSV for inspection
panel.to_csv("simulated_panel.csv", index=False)
print(f"\n✓ Saved: simulated_panel.csv")

# Stata .dta format
try:
    # Stata variable names: max 32 chars, no spaces, must start with letter/underscore
    # Clean column names for Stata compatibility
    stata_panel = panel.copy()
    stata_panel.columns = [
        c.replace(" ", "_").replace("-", "_")[:32] for c in stata_panel.columns
    ]
    
    # Drop string columns that Stata might struggle with (keep N1 as ID)
    # Convert N1 to string explicitly for Stata
    if "N1" in stata_panel.columns:
        stata_panel["N1"] = stata_panel["N1"].astype(str)
    
    stata_panel.to_stata("simulated_panel.dta", write_index=False, version=118)
    print(f"✓ Saved: simulated_panel.dta")
except Exception as e:
    print(f"⚠ Could not save .dta: {e}")
    print("  The .csv file can be imported into Stata with: import delimited")

# ── 9. Summary ────────────────────────────────────────────────────────
print(f"\n── Column List ({panel.shape[1]} columns) ──")
for i, col in enumerate(panel.columns, 1):
    print(f"  {i:3d}. {col}")

print(f"\n── First 5 rows (ID + key columns) ──")
show_cols = [c for c in ["id", "N1", "source", "gender", "age", "education",
                          "occupation", "income", "relationship",
                          "EXP1", "IBT1", "SC1", "IPB1",
                          "EXP1_T2", "PS1_T2", "IPB1_T2"] if c in panel.columns]
print(panel[show_cols].head().to_string(index=False))

print("\n✅ Panel merge complete!")
