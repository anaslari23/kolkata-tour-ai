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
        
        # Data is now standardized in snake_case, just ensure defaults
        for it in items:
            it.setdefault('id', str(it.get('id', '')))
            it.setdefault('name', it.get('name', ''))
            it.setdefault('category', it.get('category', ''))
            it.setdefault('description', it.get('description', ''))
            it.setdefault('history', it.get('history', ''))
            it.setdefault('personal_tips', it.get('personal_tips', ''))
            it.setdefault('sentiment_tags', it.get('sentiment_tags', []))
            
            # Ensure images is a list
            if 'image_urls' in it:
                it['images'] = it['image_urls']
            elif 'images' not in it:
                it['images'] = []
            
            # Primary image
            it.setdefault('image', (it.get('images') or [None])[0])
            
            # Tags alias
            it.setdefault('tags', it.get('sentiment_tags', []))

            # Coordinates
            it.setdefault('lat', float(it.get('lat', 0.0)))
            it.setdefault('lng', float(it.get('lng', 0.0)))

            # Defaults
            it.setdefault('city', 'Kolkata')
            it.setdefault('type', 'place')
            it.setdefault('story', it.get('history', '')) # Alias history to story for backward compat

            # Tea stalls normalization (if present in new data, otherwise empty)
            # The new data schema didn't explicitly include 'nearby_tea_stalls' as a complex object list
            # but 'nearby_recommendations' as a string list. 
            # We keep this for backward compatibility if we add it back later.
            it.setdefault('nearby_tea_stalls', [])

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
                        for key in ('lat','lng','city','type','image','history','personal_tips','sentiment_tags'):
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
                        it.get('history', ''),
                        it.get('personal_tips', ''),
                        ' '.join(it.get('sentiment_tags', [])),
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
            hist = self._short(it.get('history', ''), 100)
            tips = self._short(it.get('personal_tips', ''), 100)
            
            extra = []
            if it.get('best_time'):
                extra.append(f"best: {it.get('best_time')}")
            if it.get('price'):
                extra.append(f"price: {it.get('price')}")
            if it.get('opening_hours'):
                extra.append(f"hours: {it.get('opening_hours')}")
            
            info_block = desc
            if hist:
                info_block += f" History: {hist}"
            if tips:
                info_block += f" Tip: {tips}"
            if extra:
                info_block += f" ({', '.join(extra)})"

            lines.append(f"- {name} ({cat}): {info_block}")
            
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
            "You are a knowledgeable Kolkata local guide. "
            "Reply in 2-3 sentences. "
            "Use the provided History and Personal Tips in the context to make your answer unique and valuable. "
            "Don't just list facts, weave them into a suggestion."
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
                timeout=float(os.getenv('OLLAMA_TIMEOUT_SEC', '6.0')), # Increased timeout slightly
            )
            if resp.status_code == 200:
                data = resp.json()
                txt = (data.get('response') or '').strip()
                return self._short(txt, 500) if txt else None
        except Exception:
            return None
        return None

    def _fallback_answer(self, user_msg: str, items: List[Dict], user_pref: Dict, hour: Optional[int], language: str = 'en') -> str:
        if not items:
            return "I couldn't find much yet. Try asking for tea stalls, heritage walks, or riverside spots in Kolkata."
        top = items[0]
        name = top.get('name', 'a spot')
        desc = self._short(top.get('description', ''), 120)
        
        # Use new fields if available
        tips = top.get('personal_tips', '')
        hist = top.get('history', '')
        
        mood = str(user_pref.get('mood') or '').lower()
        mood_hint = ''
        if mood in ('calm', 'relaxed', 'peaceful'):
            mood_hint = " It’s a peaceful choice."
        
        tip_snip = f" Insider tip: {tips}" if tips else ""
        hist_snip = f" Did you know? {hist}" if hist else ""
        
        base = f"You might like {name}. {desc}{hist_snip}{tip_snip}"
        if len(items) > 1 and items[1].get('name'):
            base += f" You could also check out {items[1].get('name')} nearby."
        return self._short(base, 450)

    def generate_conversational_answer(self, question: str, context_items: List[Dict], user_pref: Dict, hour: Optional[int] = None, language: str = 'en') -> str:
        # Try local Ollama; fallback to rule-based
        txt = self._ollama_answer(question, context_items, user_pref, hour, language)
        if txt:
            return txt
        return self._fallback_answer(question, context_items, user_pref, hour, language)

    # --- Similar items ---
    def similar(self, item_id: str, k: int = 8) -> List[Dict]:
        """Return items similar to the given item id using FAISS if available, otherwise keyword overlap."""
        base = next((it for it in self.items if str(it.get('id')) == str(item_id)), None)
        if not base:
            return []
        # Prefer FAISS + model when possible by embedding the base item's combined text
        if self._get_model() is not None and self.index is not None:
            text = ' '.join([
                str(base.get('name','')),
                str(base.get('category','')),
                str(base.get('description','')),
                str(base.get('history','')),
                str(base.get('personal_tips','')),
                ' '.join([str(x) for x in (base.get('sentiment_tags') or [])]),
            ])
            vec = self.model.encode([text], normalize_embeddings=True)
            scores, idxs = self.index.search(vec, max(k*3, k))
            out: List[Dict] = []
            for i, score in zip(idxs[0].tolist(), scores[0].tolist()):
                if i < 0 or i >= len(self.meta):
                    continue
                cand = dict(self.meta[i])
                if str(cand.get('id')) == str(item_id):
                    continue
                cand['score'] = float(score)
                out.append(cand)
            out.sort(key=lambda x: x.get('score', 0), reverse=True)
            return out[:k]
        # Fallback: simple tag/name overlap
        btags = set([str(x).lower() for x in (base.get('sentiment_tags') or [])])
        scored: List[Dict] = []
        for it in self.items:
            if str(it.get('id')) == str(item_id):
                continue
            overlap = len(btags.intersection([str(x).lower() for x in (it.get('sentiment_tags') or [])]))
            if base.get('category') and it.get('category') and str(base['category']).split(':')[0] == str(it['category']).split(':')[0]:
                overlap += 1
            if str(base.get('city','')).lower() == str(it.get('city','')).lower():
                overlap += 0.5
            it2 = dict(it)
            it2['score'] = float(overlap)
            scored.append(it2)
        scored.sort(key=lambda x: x.get('score', 0), reverse=True)
        return scored[:k]

