from typing import List, Dict, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import select, func, or_, text
from .models import Place, PlaceImage
import math


def paginate(query, page: int, page_size: int):
    return query.offset((page - 1) * page_size).limit(page_size)


def place_to_dict(p: Place) -> Dict:
    return {
        'id': p.id,
        'name': p.name,
        'category': p.category,
        'subcategory': p.subcategory,
        'description': p.description,
        'history': p.history,
        'nearby_recommendations': p.nearby_recommendations or [],
        'personal_tips': p.personal_tips,
        'lat': float(p.lat) if p.lat is not None else 0.0,
        'lng': float(p.lng) if p.lng is not None else 0.0,
        'opening_hours': p.opening_hours,
        'price': p.price,
        'best_time': p.best_time,
        'past_events': p.past_events,
        'tags': p.sentiment_tags or [],
        'image': p.image,
        'images': [img.url for img in sorted(p.images, key=lambda i: i.sort_order or 0)],
        'source_url': p.source_url,
    }


def get_places(db: Session, category: Optional[str], subcategory: Optional[str], page: int, page_size: int) -> Tuple[List[Dict], int]:
    q = db.query(Place)
    if category:
        cat = category.strip()
        q = q.filter(
            or_(
                Place.category.ilike(f"%{cat}%"),
                Place.subcategory.ilike(f"%{cat}%"),
                func.array_to_string(Place.sentiment_tags, ',').ilike(f"%{cat}%"),
            )
        )
    if subcategory:
        q = q.filter(Place.subcategory.ilike(f"%{subcategory.strip()}%"))
    total = q.count()
    items = paginate(q.order_by(Place.name.asc()), page, page_size).all()
    return [place_to_dict(p) for p in items], total


def search_places(db: Session, query: str, k: int, category: Optional[str]) -> List[Dict]:
    qstr = query.strip()
    base = db.query(Place)
    if category:
        cat = category.strip()
        base = base.filter(
            or_(
                Place.category.ilike(f"%{cat}%"),
                Place.subcategory.ilike(f"%{cat}%"),
                func.array_to_string(Place.sentiment_tags, ',').ilike(f"%{cat}%"),
            )
        )
    if not qstr:
        items = base.order_by(Place.name.asc()).limit(k).all()
        return [place_to_dict(p) for p in items]


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dl/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c


def recommend_places(db: Session, user_lat: float, user_lng: float, k: int = 10,
                     include_tags: Optional[List[str]] = None,
                     category: Optional[str] = None) -> List[Dict]:
    q = db.query(Place)
    if category:
        cat = category.strip()
        q = q.filter(
            or_(
                Place.category.ilike(f"%{cat}%"),
                Place.subcategory.ilike(f"%{cat}%"),
                func.array_to_string(Place.sentiment_tags, ',').ilike(f"%{cat}%"),
            )
        )
    # Pull a reasonable pool; refine later with geo index
    pool: List[Place] = q.limit(500).all()

    tags_norm = [t.strip().lower() for t in (include_tags or []) if t]
    scored: List[Tuple[float, Place]] = []
    for p in pool:
        try:
            d = _haversine_km(float(p.lat or 0), float(p.lng or 0), user_lat, user_lng)
        except Exception:
            d = 9999.0
        # smaller distance -> higher score; basic transform
        dist_score = max(0.0, 1.0 - min(d, 20.0)/20.0)  # within 20km
        tag_score = 0.0
        if tags_norm and p.sentiment_tags:
            s = {str(t).lower() for t in p.sentiment_tags}
            tag_score = 0.3 * sum(1 for t in tags_norm if t in s)
        total = dist_score + tag_score
        scored.append((total, p))

    scored.sort(key=lambda x: x[0], reverse=True)
    top = [place_to_dict(p) for _, p in scored[:k]]
    # Attach distance for client sorting/debug
    for it in top:
        try:
            it['distance_km'] = round(_haversine_km(it.get('lat', 0), it.get('lng', 0), user_lat, user_lng), 2)
        except Exception:
            it['distance_km'] = None
    return top

    # Search across name, description, category, subcategory, tags
    items = (
        base
        .filter(
            or_(
                Place.name.ilike(f"%{qstr}%"),
                Place.description.ilike(f"%{qstr}%"),
                Place.category.ilike(f"%{qstr}%"),
                Place.subcategory.ilike(f"%{qstr}%"),
                func.array_to_string(Place.sentiment_tags, ',').ilike(f"%{qstr}%"),
            )
        )
        .order_by(Place.name.asc())
        .limit(k)
        .all()
    )
    return [place_to_dict(p) for p in items]
