import json
import os
from typing import List, Dict, Optional
import os
try:
    import requests  # type: ignore
except Exception:
    requests = None  # type: ignore
from math import radians, sin, cos, asin, sqrt

try:
    import faiss  # type: ignore
    from sentence_transformers import SentenceTransformer  # type: ignore
    FAISS_AVAILABLE = True
except Exception:
    FAISS_AVAILABLE = False


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    return r * c


class RAGPipeline:
    def __init__(self, data_path: str, index_dir: str):
        self.data_path = data_path
        self.index_dir = index_dir
        self.items = self._load_data()
        self.index = None
        self.model: Optional[SentenceTransformer] = None
        self.meta: List[Dict] = []

        if FAISS_AVAILABLE and os.path.isdir(index_dir):
            try:
                self.index = faiss.read_index(os.path.join(index_dir, 'index.faiss'))
                # lazy load metadata
                meta_path = os.path.join(index_dir, 'meta.json')
                if os.path.exists(meta_path):
                    with open(meta_path, 'r', encoding='utf-8') as f:
                        self.meta = json.load(f)
                # lazy load model when first needed
            except Exception:
                self.index = None

    def _get_model(self) -> Optional[SentenceTransformer]:
        if not FAISS_AVAILABLE:
            return None
        if self.model is None:
            model_name = os.getenv('MODEL_NAME', 'sentence-transformers/all-MiniLM-L6-v2')
            try:
                self.model = SentenceTransformer(model_name)
            except Exception:
                self.model = None
        return self.model

    def _load_data(self) -> List[Dict]:
        if not os.path.exists(self.data_path):
            return []
        with open(self.data_path, 'r', encoding='utf-8') as f:
            items: List[Dict] = json.load(f)
        # Normalize keys so API always returns lowercase fields expected by frontend
        for it in items:
            # Prefer existing normalized keys, otherwise map from original dataset
            it.setdefault('id', str(it.get('id') or it.get('ID') or ''))
            it.setdefault('name', it.get('name') or it.get('Name') or '')
            it.setdefault('category', it.get('category') or it.get('Category & Subcategory') or '')
            it.setdefault('description', it.get('description') or it.get('Description') or '')

            # Images: try array, else split string field
            if 'images' not in it or not isinstance(it.get('images'), list):
                imgs = it.get('Image URLs') or it.get('images') or ''
                if isinstance(imgs, str):
                    it['images'] = [u.strip() for u in imgs.split(',') if u.strip()]
                elif isinstance(imgs, list):
                    it['images'] = imgs
                else:
                    it['images'] = []

            # Single primary image convenience
            it.setdefault('image', (it.get('images') or [None])[0])

            # Tags: split sentiment or tags list if present
            if 'tags' not in it or not isinstance(it.get('tags'), list):
                sent = it.get('Sentiment Tags') or ''
                if isinstance(sent, str):
                    it['tags'] = [t.strip() for t in sent.split(',') if t.strip()]
                else:
                    it['tags'] = []

            # Coordinates normalization
            if 'lat' not in it or not isinstance(it.get('lat'), (int, float)):
                v = it.get('Latitude') or it.get('latitude')
                try:
                    it['lat'] = float(v) if v is not None else 0.0
                except Exception:
                    it['lat'] = 0.0
            if 'lng' not in it or not isinstance(it.get('lng'), (int, float)):
                v = it.get('Longitude') or it.get('longitude') or it.get('lon') or it.get('long')
                try:
                    it['lng'] = float(v) if v is not None else 0.0
                except Exception:
                    it['lng'] = 0.0

            # Defaults
            it.setdefault('city', it.get('city') or 'Kolkata')
            it.setdefault('type', it.get('type') or 'place')
            it.setdefault('story', it.get('story') or it.get('description', ''))

            # Extended fields normalization for chat enrichment
            # nearby_tea_stalls: list of {name, distance_km, specialty}
            nts = it.get('nearby_tea_stalls') or it.get('Nearby Tea Stalls') or []
            norm_nts = []
            if isinstance(nts, list):
                for e in nts:
                    if isinstance(e, dict):
                        norm_nts.append({
                            'name': str(e.get('name') or e.get('Name') or '').strip() or None,
                            'distance_km': (float(e.get('distance_km')) if isinstance(e.get('distance_km'), (int,float,str)) and str(e.get('distance_km')).strip() else None),
                            'specialty': (str(e.get('specialty') or e.get('Specialty') or '').strip() or None),
                        })
                    elif isinstance(e, str):
                        norm_nts.append({'name': e.strip() or None, 'distance_km': None, 'specialty': None})
            it['nearby_tea_stalls'] = [x for x in norm_nts if (x.get('name') or x.get('specialty'))]

            # local history and visit info
            it.setdefault('local_history', it.get('local_history') or it.get('Local History') or '')
            it.setdefault('best_time', it.get('best_time') or it.get('Best Time') or '')
            it.setdefault('price', it.get('price') or it.get('Price') or '')
            it.setdefault('opening_hours', it.get('opening_hours') or it.get('Opening Hours') or '')
        return items

    def _filter_items(self, items: List[Dict], city: Optional[str], typ: Optional[str]) -> List[Dict]:
        def ok(it: Dict) -> bool:
            if city and str(it.get('city', '')).lower() != city.lower():
                return False
            if typ and str(it.get('type', '')).lower() != typ.lower():
                return False
            return True
        return [it for it in items if ok(it)]

    def search(self, query: str, k: int = 5, city: Optional[str] = None, typ: Optional[str] = None,
               user_lat: Optional[float] = None, user_lng: Optional[float] = None) -> List[Dict]:
        # Embedding search if index + model available
        if self.index is not None and self._get_model() is not None:
            vec = self.model.encode([query], normalize_embeddings=True)
            scores, idxs = self.index.search(vec, max(k*4, k))
            idx_list = idxs[0].tolist()
            results = []
            for i, score in zip(idx_list, scores[0].tolist()):
                if i < 0 or i >= len(self.meta):
                    continue
                item = dict(self.meta[i])
                # Enrich meta with normalized coordinates and other fields from source items
                try:
                    src = next((it for it in self.items if str(it.get('name','')).lower() == str(item.get('name','')).lower()), None)
                    if src:
                        for key in ('lat','lng','city','type','image'):
                            if key not in item or not item.get(key):
                                item[key] = src.get(key)
                        # Fill tags/images if missing
                        if not item.get('images'):
                            item['images'] = src.get('images', [])
                        if not item.get('category'):
                            item['category'] = src.get('category', '')
                        if not item.get('description'):
                            item['description'] = src.get('description', '')
                except Exception:
                    pass
                item['score'] = float(score)
                results.append(item)
            results = self._filter_items(results, city, typ)
        else:
            # keyword fallback
            q = (query or '').lower().strip()
            pool = self._filter_items(self.items, city, typ)
            if not q:
                results = pool[:k]
            else:
                scored = []
                for it in pool:
                    text = ' '.join([
                        it.get('name', ''),
                        it.get('category', ''),
                        it.get('description', ''),
                        it.get('story', ''),
                        ' '.join(it.get('tags', [])),
                    ]).lower()
                    score = sum(1 for token in q.split() if token in text)
                    if score > 0:
                        scored.append((score, it))
                scored.sort(key=lambda x: x[0], reverse=True)
                results = [it for _, it in scored]

        # Distance-aware re-ranking
        if user_lat is not None and user_lng is not None:
            for it in results:
                try:
                    d = haversine_km(float(it.get('lat', 0) or 0), float(it.get('lng', 0) or 0), user_lat, user_lng)
                except Exception:
                    d = 9999.0
                it['distance_km'] = round(d, 2)
            results.sort(key=lambda it: (it.get('distance_km', 9999.0)))

        return results[:k]

    def generate_answer(self, question: str, context_items: List[Dict]) -> str:
        if not context_items:
            return "I couldn't find anything relevant yet. Try another query about Kolkata."
        bullets = '\n'.join([
            f"• {it.get('name', 'Unknown')} — {it.get('category', '')}: {it.get('description', '')[:120]}..."
            for it in context_items
        ])
        return (
            f"Here are a few places I found for: '{question}'.\n{bullets}\n"
            "Would you like directions or similar recommendations?"
        )

    # --- Conversational answer helpers ---
    def _short(self, txt: str, n: int = 220) -> str:
        t = (txt or '').strip()
        return (t[: n].rstrip() + ('…' if len(t) > n else '')) if t else ''

    def _context_lines(self, items: List[Dict]) -> str:
        lines = []
        for it in items[:4]:
            name = it.get('name', 'Unknown')
            cat = it.get('category', '')
            desc = self._short(it.get('description', ''), 140)
            extra = []
            if it.get('best_time'):
                extra.append(f"best: {it.get('best_time')}")
            if it.get('price'):
                extra.append(f"price: {it.get('price')}")
            if it.get('opening_hours'):
                extra.append(f"hours: {it.get('opening_hours')}")
            if extra:
                desc = (desc + f" ({', '.join(extra)})").strip()
            lines.append(f"- {name} — {cat}: {desc}")
            nts = it.get('nearby_tea_stalls') or []
            if isinstance(nts, list) and nts:
                ts = nts[0]
                tname = ts.get('name') or 'tea stall'
                tdist = ts.get('distance_km')
                spec = ts.get('specialty')
                hint = f"  nearby: {tname}"
                if tdist is not None:
                    hint += f" (~{tdist} km)"
                if spec:
                    hint += f", famous for {spec}"
                lines.append(hint)
        return "\n".join(lines)

    def _ollama_answer(self, user_msg: str, items: List[Dict], user_pref: Dict, hour: Optional[int], language: str = 'en') -> Optional[str]:
        if requests is None:
            return None
        model = os.getenv('OLLAMA_MODEL', 'tinyllama')
        endpoint = os.getenv('OLLAMA_ENDPOINT', 'http://127.0.0.1:11434/api/generate')
        prefs_text = (
            f"mood={user_pref.get('mood')}, "
            f"interests={user_pref.get('interests')}, "
            f"time_pref={user_pref.get('time_preference')}"
        )
        sys = (
            "You are a friendly, concise Kolkata local guide. "
            "Reply in 2-3 short sentences, warm and human. "
            "Personalize using preferences and time. Avoid long lists."
        )
        if language != 'en':
            sys += f" Answer in {language}."
        prompt = (
            f"System: {sys}\n"
            f"User: {user_msg}\n"
            f"Preferences: {prefs_text}, hour={hour}\n"
            f"Context candidates:\n{self._context_lines(items)}\n"
            "Assistant:"
        )
        try:
            resp = requests.post(
                endpoint,
                json={'model': model, 'prompt': prompt, 'stream': False},
                timeout=float(os.getenv('OLLAMA_TIMEOUT_SEC', '4.0')),
            )
            if resp.status_code == 200:
                data = resp.json()
                txt = (data.get('response') or '').strip()
                return self._short(txt, 420) if txt else None
        except Exception:
            return None
        return None

    def _fallback_answer(self, user_msg: str, items: List[Dict], user_pref: Dict, hour: Optional[int], language: str = 'en') -> str:
        if not items:
            return "I couldn't find much yet. Try asking for tea stalls, heritage walks, or riverside spots in Kolkata."
        top = items[0]
        name = top.get('name', 'a spot')
        desc = self._short(top.get('description', ''), 120)
        mood = str(user_pref.get('mood') or '').lower()
        mood_hint = ''
        if mood in ('calm', 'relaxed', 'peaceful'):
            mood_hint = " It’s a peaceful choice; great for a relaxed stroll."
        tea_snip = ''
        nts = top.get('nearby_tea_stalls') or []
        if isinstance(nts, list) and nts:
            ts = nts[0]
            tname = ts.get('name') or 'a local tea stall'
            spec = ts.get('specialty')
            tdist = ts.get('distance_km')
            tea_snip = f" There’s a small tea place nearby called ‘{tname}’"
            if spec:
                tea_snip += f", known for {spec}"
            if tdist is not None:
                tea_snip += f" (~{tdist} km)."
            else:
                tea_snip += "."
        hist = self._short(top.get('local_history', '') or top.get('story', ''), 120)
        hist_snip = f" Local tip: {hist}" if hist else ''
        time_hint = ''
        if isinstance(hour, int):
            bt = str(top.get('best_time') or '').lower()
            if 17 <= hour <= 19 and ('sunset' in bt):
                time_hint = " Sunset is perfect here."
            elif hour >= 20:
                time_hint = " It’s quieter at night; check hours before you go."
        base = f"You might like {name}. {desc}{mood_hint}{tea_snip}{hist_snip}{time_hint}"
        if len(items) > 1 and items[1].get('name'):
            base += f" If you want another vibe, also consider {items[1].get('name')} nearby."
        return self._short(base, 420)

    def generate_conversational_answer(self, question: str, context_items: List[Dict], user_pref: Dict, hour: Optional[int] = None, language: str = 'en') -> str:
        # Try local Ollama; fallback to rule-based
        txt = self._ollama_answer(question, context_items, user_pref, hour, language)
        if txt:
            return txt
        return self._fallback_answer(question, context_items, user_pref, hour, language)

