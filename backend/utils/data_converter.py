import pandas as pd
import json
import re
from pathlib import Path

# Convert Excel -> JSON with a fixed schema used by the app/backend
# Expected columns (case-insensitive):
# id, name, category, description, images (comma-separated), tags (comma-separated), lat, lng, distance_km or distanceKm,
# optional: city, type, story


def _split_list(cell):
  if cell is None or (isinstance(cell, float) and pd.isna(cell)):
    return []
  # allow comma or semicolon separated
  text = str(cell)
  parts = [p.strip() for p in re.split(r'[;,]', text) if p and str(p).strip()]
  return parts


def excel_to_json(src_xlsx: str, dst_json: str, sheet: str | int | None = None) -> None:
  # CSV support: if file ends with .csv, read via read_csv and ignore sheet.
  src_lower = src_xlsx.lower()
  if src_lower.endswith('.csv'):
    df = pd.read_csv(src_xlsx)
  else:
    # Excel path
    sheet_arg = 0 if sheet is None else sheet
    df = pd.read_excel(src_xlsx, sheet_name=sheet_arg)
    if isinstance(df, dict):
      # User may have passed an invalid sheet; pick the first available.
      first_key = next(iter(df))
      df = df[first_key]
  # Normalize columns to lower for safe access
  df.columns = [str(c).strip() for c in df.columns]
  lower_map = {c.lower(): c for c in df.columns}

  def col(name: str):
    return lower_map.get(name.lower())

  # (re already imported at top)

  records = []
  for _, r in df.iterrows():
    name_val = r.get(col('name')) if col('name') else ''
    name_val = '' if (isinstance(name_val, float) and pd.isna(name_val)) else str(name_val).strip()
    if not name_val:
      # skip blank rows
      continue

    images_raw = r.get(col('images')) if col('images') else None
    tags_raw = r.get(col('tags')) if col('tags') else None
    lat_raw = r.get(col('lat')) if col('lat') else 0
    lng_raw = r.get(col('lng')) if col('lng') else 0
    dist_raw = r.get(col('distance_km')) if col('distance_km') else r.get(col('distanceKm')) if col('distanceKm') else 0

    # Defaults: city=Kolkata, type=place if missing/blank
    city_val = str(r.get(col('city')) or '').strip() if col('city') else 'Kolkata'
    if not city_val:
      city_val = 'Kolkata'
    type_val = str(r.get(col('type')) or '').strip() if col('type') else 'place'
    if not type_val:
      type_val = 'place'

    rec = {
      'id': '' if not col('id') else str(r.get(col('id')) or '').strip(),
      'name': name_val,
      'category': '' if not col('category') else str(r.get(col('category')) or '').strip(),
      'description': '' if not col('description') else str(r.get(col('description')) or '').strip(),
      'images': _split_list(images_raw),
      'tags': _split_list(tags_raw),
      'lat': float(lat_raw or 0),
      'lng': float(lng_raw or 0),
      'distanceKm': float(dist_raw or 0),
      'city': city_val,
      'type': type_val,
      'story': None if not col('story') else str(r.get(col('story')) or '').strip(),
    }
    records.append(rec)

  Path(dst_json).parent.mkdir(parents=True, exist_ok=True)
  with open(dst_json, 'w', encoding='utf-8') as f:
    json.dump(records, f, ensure_ascii=False, indent=2)


if __name__ == '__main__':
  import argparse
  p = argparse.ArgumentParser()
  p.add_argument('--src', required=True, help='Path to Excel file')
  p.add_argument('--dst', required=True, help='Path to output JSON')
  p.add_argument('--sheet', help='Sheet name or index (default: first)')
  args = p.parse_args()
  sheet = None
  if args.sheet is not None:
    # try int index, else pass name
    try:
      sheet = int(args.sheet)
    except ValueError:
      sheet = args.sheet
  excel_to_json(args.src, args.dst, sheet=sheet)
