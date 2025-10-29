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

data_collection/
  kolkata_places.xlsx        # Original Excel source (add yours)
  sample_template.xlsx       # Template columns
  notes/                     # Field collection notes
```

Note: The original Flutter app remains under the root `lib/` for now. We will migrate fully into `frontend/` once confirmed. There is also a stray `frontend/screens/` from an earlier step; prefer `frontend/lib/screens/`.

## Quick Start

### Backend
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
2. Run:
   ```bash
   flutter run
   # or for web
   flutter run -d chrome
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
