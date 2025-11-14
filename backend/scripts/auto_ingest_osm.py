import os
import sys
import json
import time
from typing import Dict, List, Tuple
import requests

from ..db import enable_db, SessionLocal, engine
from ..models import Base, Place, PlaceImage

# Default Kolkata bbox: south,west,north,east (lat,lon)
DEFAULT_BBOX = (22.45, 88.20, 22.75, 88.50)

OSM_TIMEOUT = 180
OVERPASS_URL = os.getenv("OVERPASS_URL", "https://overpass-api.de/api/interpreter")

CATEGORIES = [
    # (key=value, category, subcategory)
    ("tourism=attraction", "Attraction", None),
    ("historic=*", "Historic", None),
    ("amenity=cafe", "Food & Drink", "Cafe"),
    ("amenity=restaurant", "Food & Drink", "Restaurant"),
    ("amenity=marketplace", "Market", None),
    ("leisure=park", "Park", None),
    ("natural=water", "Natural", "Water"),
    ("tourism=viewpoint", "Viewpoint", None),
    ("tourism=museum", "Museum", None),
    ("amenity=place_of_worship", "Temple", None),
    ("man_made=bridge", "Landmark", "Bridge"),
    ("water=lake", "Lake", None),
]


def _bbox_from_env() -> Tuple[float, float, float, float]:
    v = os.getenv("BBOX")
    if not v:
        return DEFAULT_BBOX
    parts = [p.strip() for p in v.split(',')]
    if len(parts) != 4:
        return DEFAULT_BBOX
    try:
        s, w, n, e = map(float, parts)
        return (s, w, n, e)
    except Exception:
        return DEFAULT_BBOX


def build_query(bbox: Tuple[float, float, float, float]) -> str:
    s, w, n, e = bbox
    lines = ["[out:json][timeout:%d];" % OSM_TIMEOUT, "("]
    for tag, _, _ in CATEGORIES:
        if tag.endswith("=*"):
            k = tag.split("=")[0]
            lines.append(f"  node[{k}]({s},{w},{n},{e});")
            lines.append(f"  way[{k}]({s},{w},{n},{e});")
            lines.append(f"  relation[{k}]({s},{w},{n},{e});")
        else:
            k, v = tag.split("=")
            lines.append(f"  node[{k}={v}]({s},{w},{n},{e});")
            lines.append(f"  way[{k}={v}]({s},{w},{n},{e});")
            lines.append(f"  relation[{k}={v}]({s},{w},{n},{e});")
    lines.append(");out center;")
    return "\n".join(lines)


def normalize_el(el: Dict) -> Dict:
    tags = el.get("tags", {}) or {}
    name = tags.get("name") or tags.get("name:en") or tags.get("brand") or ""
    lat = el.get("lat") or (el.get("center") or {}).get("lat")
    lon = el.get("lon") or (el.get("center") or {}).get("lon")

    # detect category/subcategory from matched tags
    cat = None
    sub = None
    for t, c, sc in CATEGORIES:
        if t.endswith("=*"):
            key = t.split("=")[0]
            if key in tags:
                cat = cat or c
                sub = sub or sc or tags.get(key)
        else:
            k, v = t.split("=")
            if tags.get(k) == v:
                cat = cat or c
                sub = sub or sc
    if not cat:
        cat = tags.get("tourism") or tags.get("amenity") or tags.get("historic") or tags.get("leisure") or tags.get("natural") or "place"

    sentiments: List[str] = []
    for k in ("scenic", "quiet", "view", "sunset", "photography", "family", "budget"):
        if k in tags or (isinstance(tags.get(k), str) and tags.get(k).lower() in ("yes","true","1")):
            sentiments.append(k)

    opening = tags.get("opening_hours")
    price = tags.get("fee") or tags.get("price")

    osm_type = el.get("type")
    osm_id = el.get("id")
    base_id = f"{osm_type}-{osm_id}"
    place_id = "21" + base_id

    return {
        "id": place_id,
        "name": name,
        "category": cat,
        "subcategory": sub,
        "description": tags.get("description") or "",
        "history": tags.get("wikidata") or "",
        "nearby_recommendations": [],
        "personal_tips": "",
        "lat": float(lat) if lat is not None else 0.0,
        "lng": float(lon) if lon is not None else 0.0,
        "opening_hours": {"raw": opening} if opening else None,
        "price": price,
        "best_time": None,
        "past_events": None,
        "sentiment_tags": sentiments,
        "source_url": f"https://www.openstreetmap.org/{osm_type}/{osm_id}",
        "image": None,
        "images": [],
    }


def upsert(db, data: Dict):
    p = db.get(Place, data["id"]) or Place(id=data["id"])
    for k in (
        "name","category","subcategory","description","history","nearby_recommendations",
        "personal_tips","lat","lng","opening_hours","price","best_time","past_events",
        "sentiment_tags","source_url","image",
    ):
        setattr(p, k, data.get(k))
    if not getattr(p, "id", None):
        p.id = data["id"]
    # replace images if provided
    p.images.clear()
    for i, url in enumerate(data.get("images") or []):
        p.images.append(PlaceImage(url=url, sort_order=i))
    db.add(p)


def fetch_and_ingest(bbox: Tuple[float,float,float,float]):
    if not enable_db:
        raise SystemExit("DATABASE_URL not set. Export DATABASE_URL and retry.")
    Base.metadata.create_all(bind=engine)

    query = build_query(bbox)
    resp = requests.post(OVERPASS_URL, data={"data": query}, timeout=OSM_TIMEOUT+10)
    resp.raise_for_status()
    data = resp.json()
    elements = data.get("elements", [])

    n = 0
    with SessionLocal() as db:
        for el in elements:
            try:
                row = normalize_el(el)
                if not row["name"] or not row["lat"] or not row["lng"]:
                    continue
                upsert(db, row)
                n += 1
            except Exception:
                continue
        db.commit()
    print(f"Auto-ingest OSM: upserted {n} places.")


def main():
    bbox = _bbox_from_env()
    fetch_and_ingest(bbox)


if __name__ == "__main__":
    main()
