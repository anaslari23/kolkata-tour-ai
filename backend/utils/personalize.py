from typing import Dict, Any, List
from collections import defaultdict, Counter

DEFAULT_PREFS = {
    'likes': [],
    'last_queries': [],
    'tag_counts': {},
    'intent_counts': {},
    'mood': None,
    'interests': [],
    'time_preference': None,
}


class PreferenceStore:
    def __init__(self):
        self._store: Dict[str, Dict[str, Any]] = defaultdict(lambda: dict(DEFAULT_PREFS))

    def get(self, user_id: str) -> Dict[str, Any]:
        return self._store[user_id]

    def update_explicit(self, user_id: str, prefs: Dict[str, Any]) -> Dict[str, Any]:
        s = self._store[user_id]
        if 'mood' in prefs:
            s['mood'] = prefs.get('mood')
        if 'interests' in prefs and isinstance(prefs.get('interests'), list):
            s['interests'] = [str(x).strip() for x in prefs['interests'] if str(x).strip()]
        if 'time_preference' in prefs:
            s['time_preference'] = prefs.get('time_preference')
        if 'dietary' in prefs and isinstance(prefs.get('dietary'), dict):
            s['dietary'] = prefs['dietary']
        if 'companion' in prefs:
            s['companion'] = prefs['companion']
        return s

    def update_from_interaction(self, user_id: str, query: str, answer: str) -> None:
        s = self._store[user_id]
        s.setdefault('last_queries', [])
        s['last_queries'].append(query)
        text = (str(query) + ' ' + str(answer)).lower()
        for kw in ['historical', 'food', 'religious', 'art', 'parks', 'landmark']:
            if kw in text:
                s.setdefault('likes', [])
                if kw not in s['likes']:
                    s['likes'].append(kw)
        s.setdefault('tag_counts', {})
        tag_counter = Counter(s['tag_counts'])
        tag_map = {
            'quiet': ['quiet', 'calm', 'peaceful', 'serene'],
            'night view': ['night', 'late', 'evening lights'],
            'historic': ['historic', 'heritage', 'museum', 'history'],
            'riverside': ['river', 'ghat', 'waterfront'],
            'tea': ['tea', 'cha', 'chai', 'stall'],
            'cafe': ['cafe', 'coffee'],
            'street-food': ['street food', 'kathi roll', 'phuchka', 'puchka', 'chaat'],
            'family': ['family', 'kids'],
        }
        for tag, keys in tag_map.items():
            if any(k in text for k in keys):
                tag_counter[tag] += 1
        s['tag_counts'] = dict(tag_counter)
        s.setdefault('intent_counts', {})
        intent_counter = Counter(s['intent_counts'])
        intent_map = {
            'food': ['food', 'eat', 'tea', 'cafe', 'street food', 'restaurant'],
            'photography': ['photo', 'photography', 'iconic', 'view'],
            'history': ['history', 'historic', 'heritage', 'museum'],
            'quiet': ['quiet', 'calm', 'peaceful'],
            'explore': ['explore', 'walk', 'stroll', 'discover'],
        }
        for intent, keys in intent_map.items():
            if any(k in text for k in keys):
                intent_counter[intent] += 1
        s['intent_counts'] = dict(intent_counter)

    def interests_for(self, user_id: str) -> List[str]:
        s = self._store[user_id]
        return [str(x).lower() for x in (s.get('interests') or [])]

    def top_tags(self, user_id: str, k: int = 3) -> List[str]:
        s = self._store[user_id]
        counts = Counter(s.get('tag_counts') or {})
        return [t for t, _ in counts.most_common(k)]

    def top_intents(self, user_id: str, k: int = 2) -> List[str]:
        s = self._store[user_id]
        counts = Counter(s.get('intent_counts') or {})
        return [t for t, _ in counts.most_common(k)]
