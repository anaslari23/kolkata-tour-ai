import os
import json
from typing import List, Dict
from sqlalchemy.orm import Session
from sqlalchemy import text

from ..db import SessionLocal, engine, enable_db
from ..models import Place, PlaceImage, Base

DATA_PATH = os.path.join(os.path.dirname(__file__), '..', 'data', 'kolkata_places.json')
DATA_PATH = os.path.abspath(DATA_PATH)


def normalize_item(it: Dict) -> Dict:
    # Map fields from JSON to DB columns
    images = it.get('images') or []
    if isinstance(images, str):
        images = [u.strip() for u in images.split(',') if u.strip()]
    tags = it.get('tags') or it.get('Sentiment Tags') or []
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(',') if t.strip()]

    return {
        'id': str(it.get('id') or it.get('ID') or ''),
        'name': it.get('name') or it.get('Name') or '',
        'category': it.get('category') or it.get('Category') or it.get('Category & Subcategory') or '',
        'subcategory': it.get('subcategory') or None,
        'description': it.get('description') or it.get('Description') or '',
        'history': it.get('history') or it.get('History') or '',
        'nearby_recommendations': it.get('nearby_recommendations') or it.get('Nearby Recommendations') or [],
        'personal_tips': it.get('personal_tips') or it.get('Personal Tips') or '',
        'lat': float(it.get('lat') or it.get('Latitude') or 0.0),
        'lng': float(it.get('lng') or it.get('Longitude') or 0.0),
        'opening_hours': it.get('opening_hours') or it.get('Opening Hours') or None,
        'price': it.get('price') or it.get('Price') or None,
        'best_time': it.get('best_time') or it.get('Best Time') or None,
        'past_events': it.get('past_events') or it.get('Past Events') or None,
        'sentiment_tags': tags,
        'source_url': it.get('source_url') or it.get('Source URL') or None,
        'image': (images[0] if images else None),
        'images': images,
    }


def upsert_place(db: Session, data: Dict):
    p = db.get(Place, data['id'])
    if not p:
        p = Place(id=data['id'])
        db.add(p)
    p.name = data['name']
    p.category = data['category'] or 'Unknown'
    p.subcategory = data['subcategory']
    p.description = data['description']
    p.history = data['history']
    p.nearby_recommendations = data['nearby_recommendations'] or []
    p.personal_tips = data['personal_tips']
    p.lat = data['lat']
    p.lng = data['lng']
    p.opening_hours = data['opening_hours']
    p.price = data['price']
    p.best_time = data['best_time']
    p.past_events = data['past_events']
    p.sentiment_tags = data['sentiment_tags'] or []
    p.source_url = data['source_url']
    p.image = data['image']

    # Replace images
    p.images.clear()
    for i, url in enumerate(data['images'] or []):
        p.images.append(PlaceImage(url=url, sort_order=i))


def main():
    if not enable_db:
        raise SystemExit("DATABASE_URL not set. Export DATABASE_URL and try again.")

    # Ensure tables exist (for quick bootstrap; prefer Alembic in real use)
    Base.metadata.create_all(bind=engine)

    with open(DATA_PATH, 'r', encoding='utf-8') as f:
        items: List[Dict] = json.load(f)

    with SessionLocal() as db:
        for it in items:
            data = normalize_item(it)
            if not data['id']:
                # enforce '21...' if missing id
                data['id'] = '21' + data['name'].replace(' ', '').lower()[:20]
            if not data['id'].startswith('21'):
                data['id'] = '21' + data['id']
            upsert_place(db, data)
        db.commit()
    print(f"Ingested {len(items)} items into the database.")


if __name__ == '__main__':
    main()
