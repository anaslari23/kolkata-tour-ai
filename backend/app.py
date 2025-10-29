from flask import Flask, request, jsonify
from utils.rag_pipeline import RAGPipeline
from utils.personalize import PreferenceStore
import os, math, time
try:
    import requests  # optional for local LLM via Ollama
except Exception:
    requests = None

app = Flask(__name__)

# Lazy-init components
rag = RAGPipeline(
    data_path=os.path.join(os.path.dirname(__file__), 'data', 'kolkata_places.json'),
    index_dir=os.path.join(os.path.dirname(__file__), 'data', 'faiss_index')
)
prefs = PreferenceStore()

@app.get('/health')
def health():
    return {'status': 'ok'}

@app.post('/search')
def search():
    data = request.get_json(silent=True) or {}
    q = data.get('query', '')
    k = int(data.get('k', 8))
    city = data.get('city')
    typ = data.get('type')
    user_lat = data.get('user_lat')
    user_lng = data.get('user_lng')
    results = rag.search(q, k=k, city=city, typ=typ, user_lat=user_lat, user_lng=user_lng)
    return jsonify({'results': results})

@app.get('/places')
def places():
    city = request.args.get('city')
    typ = request.args.get('type')
    results = rag.search('', k=100, city=city, typ=typ)
    return jsonify({'results': results})

@app.get('/cities')
def cities():
    cities = sorted({(it.get('city') or 'Kolkata') for it in rag.items})
    return jsonify({'cities': cities})

@app.post('/chat')
def chat():
    data = request.get_json(silent=True) or {}
    user_msg = data.get('message', '')
    user_id = data.get('user_id', 'anon')
    city = data.get('city')
    user_lat = data.get('user_lat')
    user_lng = data.get('user_lng')
    hour = data.get('hour')
    # optional intent/pace/language
    intent = data.get('intent')
    pace = data.get('pace')
    language = data.get('language') or 'en'

    # Step 1: retrieve pool
    items = rag.search(user_msg, k=8, city=city, user_lat=user_lat, user_lng=user_lng)

    # Step 2: lightweight personalization/context scoring for chat
    user_pref = prefs.get(user_id)
    scored = []
    for it in items:
        psc = _personalization_score(it, user_pref)
        csc = _context_score(it, None, hour, None)
        isc = _intent_score(it, intent)
        total = 0.9*psc + 0.5*isc + 0.3*csc
        it2 = dict(it)
        it2['score'] = round(total, 3)
        scored.append(it2)
    scored.sort(key=lambda x: x.get('score', 0), reverse=True)
    top = scored[:4]

    # Step 3: generate conversational answer via LLM (Ollama) with graceful fallback
    try:
        answer = rag.generate_conversational_answer(user_msg, top, user_pref, hour=hour, language=language)
    except Exception:
        # final safety fallback
        answer = rag.generate_answer(user_msg, top)

    # Step 4: learn from interaction
    try:
        prefs.update_from_interaction(user_id, user_msg, answer)
    except Exception:
        pass

    # Backward compatible keys + future-friendly aliases
    return jsonify({
        'answer': answer,
        'context': top,
        'response': answer,
        'suggestions': top,
    })

@app.post('/prefs/update')
def prefs_update():
    data = request.get_json(silent=True) or {}
    user_id = data.get('user_id', 'anon')
    prefs.update_explicit(user_id, data.get('preferences') or {})
    return jsonify({'ok': True, 'prefs': prefs.get(user_id)})

def _deg2rad(d):
    return d * math.pi / 180.0

def _equirect_xy(lat, lng, lat0):
    x = _deg2rad(lng) * math.cos(_deg2rad(lat0))
    y = _deg2rad(lat)
    return x, y

def _point_segment_distance_km(a_lat, a_lng, b_lat, b_lng, p_lat, p_lng):
    lat0 = (a_lat + b_lat) / 2.0
    ax, ay = _equirect_xy(a_lat, a_lng, lat0)
    bx, by = _equirect_xy(b_lat, b_lng, lat0)
    px, py = _equirect_xy(p_lat, p_lng, lat0)
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    c1 = vx * wx + vy * wy
    c2 = vx * vx + vy * vy
    t = 0.0 if c2 == 0 else max(0.0, min(1.0, c1 / c2))
    sx, sy = ax + t * vx, ay + t * vy
    dx, dy = px - sx, py - sy
    r = 6371.0
    return math.hypot(dx, dy) * r

def _haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0
    dlat = _deg2rad(lat2 - lat1)
    dlon = _deg2rad(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def _personalization_score(it, user_pref):
    s = 0.0
    ints = [str(x).lower() for x in (user_pref.get('interests') or [])]
    tags = [str(x).lower() for x in (it.get('tags') or [])]
    for t in ints:
        if t in ' '.join(tags):
            s += 1.0
    tp = str(user_pref.get('time_preference') or '').lower()
    if tp:
        s += 0.2
    mood = str(user_pref.get('mood') or '').lower()
    if mood:
        s += 0.2
    # companion boosts
    comp = str((user_pref.get('companion') or '')).lower()
    if comp in ('family','kids') and any(x in tags for x in ['family','kids','educational']):
        s += 0.5
    if comp in ('couple','friends') and any(x in tags for x in ['romantic','nightlife','cafe']):
        s += 0.4
    # dietary
    dietary = user_pref.get('dietary') or {}
    veg_only = bool(dietary.get('veg_only'))
    if veg_only and 'non-veg' in ' '.join(tags):
        s -= 0.6
    if bool(dietary.get('street_food_ok')) and 'street-food' in ' '.join(tags):
        s += 0.3
    return s

def _context_score(it, weather, tm, temp_c):
    sc = 0.0
    tags = [str(x).lower() for x in (it.get('tags') or [])]
    w = (weather or '').lower()
    if 'rain' in w and any(k in tags for k in ['indoor','cafe','museum']):
        sc += 0.7
    if tm:
        hour = tm if isinstance(tm, int) else time.localtime().tm_hour
        if hour >= 20 or hour < 6:
            if 'open_late' in tags or 'tea stall' in ' '.join(tags):
                sc += 0.5
    try:
        t = float(temp_c) if temp_c is not None else None
    except Exception:
        t = None
    if t is not None and t > 35 and any(k in tags for k in ['waterfront','shade','indoor']):
        sc += 0.5
    return sc

def _intent_score(it, intent: str | None):
    if not intent:
        return 0.0
    intent = intent.lower()
    tags = [str(x).lower() for x in (it.get('tags') or [])]
    if intent == 'food':
        return 0.6 if any(x in ' '.join(tags) for x in ['street-food','cafe','tea','restaurant']) else 0.0
    if intent == 'photography':
        return 0.6 if any(x in tags for x in ['iconic','heritage','river-view','architecture']) else 0.0
    if intent == 'history':
        return 0.6 if any(x in tags for x in ['heritage','historical','museum']) else 0.0
    if intent == 'quiet':
        return 0.6 if any(x in tags for x in ['peaceful','quiet','park','open-space']) else 0.0
    return 0.0

def _llm_narration_ollama(top, user_pref, weather, hour, temp_c):
    if not requests:
        return None

def _llm_chat_ollama(user_msg: str, context_items, user_pref, hour):
    if not requests:
        return None
    try:
        ctx_lines = []
        for it in context_items[:4]:
            ctx_lines.append(f"- {it.get('name','Unknown')} — {it.get('category','')}: {it.get('description','')[:120]}...")
        prefs_text = f"mood={user_pref.get('mood')}, interests={user_pref.get('interests')}, time_pref={user_pref.get('time_preference')}"
        prompt = (
            "System: You are a friendly local Kolkata guide. Be concise (2-3 short sentences). Personalize using preferences and time.\n"
            f"User: {user_msg}\n"
            f"Preferences: {prefs_text}, hour={hour}\n"
            "Context candidates:\n" + "\n".join(ctx_lines) + "\n"
            "Assistant: Suggest 2-3 relevant places with a local tip. Avoid long lists and avoid markdown bullets."
        )
        resp = requests.post(
            'http://127.0.0.1:11434/api/generate',
            json={'model': 'tinyllama', 'prompt': prompt, 'stream': False},
            timeout=3.5
        )
        if resp.status_code == 200:
            data = resp.json()
            txt = (data.get('response') or '').strip()
            return txt or None
    except Exception:
        return None
    return None
    try:
        names = ', '.join([it.get('name','') for it in top[:3] if it.get('name')])
        tea_present = any('tea' in ' '.join([str(x).lower() for x in (it.get('tags') or [])]) for it in top)
        prefs_text = f"mood={user_pref.get('mood')}, interests={user_pref.get('interests')}, time_pref={user_pref.get('time_preference')}"
        ctx = f"weather={weather}, hour={hour}, temp_c={temp_c}"
        prompt = (
            "You are a seasoned Kolkata driver. Be concise, warm, and local. "
            "Suggest interesting stops on the way in 2 short sentences max. "
            f"Consider preferences: {prefs_text}. Context: {ctx}. "
            f"Candidate stops: {names}. "
            + ("If a tea stall is relevant, mention exactly one." if tea_present else "")
        )
        resp = requests.post(
            'http://127.0.0.1:11434/api/generate',
            json={'model': 'tinyllama', 'prompt': prompt, 'stream': False},
            timeout=3.5
        )
        if resp.status_code == 200:
            data = resp.json()
            txt = (data.get('response') or '').strip()
            return txt or None
    except Exception:
        return None
    return None

@app.post('/route_suggestions')
def route_suggestions():
    data = request.get_json(silent=True) or {}
    user_id = data.get('user_id', 'anon')
    a_lat = float(data.get('user_lat') or 0)
    a_lng = float(data.get('user_lng') or 0)
    b_lat = float(data.get('dest_lat') or 0)
    b_lng = float(data.get('dest_lng') or 0)
    weather = data.get('weather')
    tm = data.get('hour')
    temp_c = data.get('temp_c')
    transport = str(data.get('transport_mode') or 'car').lower()
    pace = str(data.get('pace') or 'normal').lower()
    avail_min = int(data.get('available_time_min') or 30)
    tolerance = (data.get('tolerance') or {})
    walk_km = float(tolerance.get('walking_distance_km') or 1.2)
    intent = data.get('intent')
    pool = rag.items
    near = []
    for it in pool:
        lat = float(it.get('lat') or 0)
        lng = float(it.get('lng') or 0)
        if lat == 0 and lng == 0:
            continue
        dseg = _point_segment_distance_km(a_lat, a_lng, b_lat, b_lng, lat, lng)
        if dseg <= float(data.get('threshold_km') or walk_km):
            near.append((dseg, it))
    user_pref = prefs.get(user_id)
    scored = []
    for dseg, it in near:
        detour = _haversine_km(a_lat, a_lng, float(it.get('lat') or 0), float(it.get('lng') or 0))
        psc = _personalization_score(it, user_pref)
        csc = _context_score(it, weather, tm, temp_c)
        isc = _intent_score(it, intent)
        # detour tolerance based on transport and available time
        detour_cap = 0.6 if transport in ('walk','scooter') else (1.2 if transport=='car' else 0.8)
        if avail_min < 20:
            detour_cap *= 0.7
        # crowd penalty if calm mood
        mood = str(user_pref.get('mood') or '').lower()
        tags = [str(x).lower() for x in (it.get('tags') or [])]
        crowd_pen = 0.5 if (mood=='calm' and any(x in tags for x in ['busy','crowd','nightlife'])) else 0.0

        detour_term = 0.6/(1.0+max(0.0, detour - detour_cap))
        total = 1.4/(1.0+dseg) + detour_term + 0.9*psc + 0.7*csc + 0.5*isc - crowd_pen
        it2 = dict(it)
        it2['route_distance_km'] = round(dseg, 2)
        it2['score'] = round(total, 3)
        scored.append(it2)
    scored.sort(key=lambda x: x.get('score', 0), reverse=True)
    top = scored[: int(data.get('k') or 5)]
    # Try local TinyLlama (Ollama) narration; fallback to template
    llm_text = _llm_narration_ollama(top, user_pref, weather, tm, temp_c)
    if not llm_text:
        narr = []
        for it in top[:2]:
            name = it.get('name','')
            tip = it.get('description','')[:80]
            narr.append(f"On your way you can stop by {name}. {tip}")
        llm_text = ' '.join(narr)
    return jsonify({'suggestions': top, 'narration': llm_text})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
