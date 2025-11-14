# kolkata_tour_ai

Monorepo for Kolkata Tour AI.

## Repository Structure

```
backend/
  app.py                     # Flask server for AI and data retrieval
  data/
    kolkata_places.json      # Main database (converted from Excel)
    faiss_index/             # Vector index (optional, placeholder)
  models/                    # LLM or embedding models (placeholder)
  utils/
    rag_pipeline.py          # Retrieval + generation logic (keyword fallback)
    data_converter.py        # Excel → JSON converter
    personalize.py           # User preference handling
  requirements.txt           # Python deps

frontend/
  pubspec.yaml               # Flutter deps
  lib/
    main.dart                # Frontend entry
    screens/
      home_screen.dart
      chat_screen.dart
    widgets/
      place_card.dart
      chat_bubble.dart

php_api/
  config.php                 # DB credentials for MySQL
  lib.php                    # Helpers (DB, JSON formatting, utils)
  schema.sql                 # MySQL schema for places and images
  places.php                 # GET /places with pagination/filters
  search.php                 # POST /search keyword search
  recommend.php              # POST /recommend location-aware
  admin_ingest_json.php      # Optional JSON → DB one-time ingest

data_collection/
  kolkata_places.xlsx        # Original Excel source (add yours)
  sample_template.xlsx       # Template columns
  notes/                     # Field collection notes
```

Note: The original Flutter app remains under the root `lib/` for now. We will migrate fully into `frontend/` once confirmed. There is also a stray `frontend/screens/` from an earlier step; prefer `frontend/lib/screens/`.

## Quick Start

### Backend (Option A: PHP + MySQL with XAMPP)
1. Ensure MySQL + Apache are running (XAMPP/MAMP/etc.).
2. Copy `php_api/` into your web root as `htdocs/api` (so endpoints are at `http://localhost/api/*.php`).
3. Edit `php_api/config.php` with your DB creds (default XAMPP: user `root`, empty password) and database `kolkata_ai`.
4. Create schema and indexes in MySQL:
   - In phpMyAdmin: import `php_api/schema.sql` into the `kolkata_ai` database.
5. Seed data (either):
   - Import your SQL dump with initial rows (e.g., places 1–21) into `kolkata_ai.places`.
   - Or run `php_api/admin_ingest_json.php` once (if served under Apache: open `http://localhost/api/admin_ingest_json.php`).
6. Test endpoints in a browser:
   - `http://localhost/api/places.php?page=1&page_size=12`
   - `http://localhost/api/search.php` (POST JSON: `{ "query": "museum" }`)
   - `http://localhost/api/recommend.php` (POST JSON: `{ "lat": 22.57, "lng": 88.35 }`)

Notes:
- Android emulator must call host at `http://10.0.2.2/api` instead of `http://localhost/api`.
- Pagination params: `page`, `page_size` (default 20, max 100).

### Backend (Option B: Python Flask)
1. Create a venv and install deps:
   ```bash
   python -m venv .venv && source .venv/bin/activate
   pip install -r backend/requirements.txt
   ```
2. Run the Flask API:
   ```bash
   python backend/app.py
   ```
   Health check: http://localhost:5001/health

### Frontend
1. Install Flutter dependencies:
   ```bash
   cd frontend
   flutter pub get
   ```
2. Run against the PHP API
   - iOS/simulator/macOS/web:
     ```bash
     flutter run --dart-define=BACKEND_BASE_URL=http://localhost/api
     ```
   - Android emulator:
     ```bash
     flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2/api
     ```

   For web explicitly:
   ```bash
   flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://localhost/api
   ```

## Data Conversion
Convert Excel to JSON used by the backend:
```bash
python backend/utils/data_converter.py --src data_collection/kolkata_places.xlsx --dst backend/data/kolkata_places.json
```

## Next Steps
- Replace mock "map" with a real map package.
- Wire frontend chat to backend `/chat` and `/search` endpoints.
- Decide on final folder (root lib vs frontend/lib) and remove duplicates.

## API Reference (PHP)
- GET `/api/places.php`
  - Query: `page`, `page_size`, optional `type` (aka category), `subcategory`
  - Response: `{ results: [...], page, page_size, total }`
- POST `/api/search.php`
  - Body: `{ query: string, category?: string, k?: number }`
- POST `/api/recommend.php`
  - Body: `{ lat: number, lng: number, tags?: string[], category?: string, k?: number }`

Compatibility: the API accepts `sentiment_tags` as JSON array or comma-separated string and derives `image` from `place_images` or `image_urls`.
