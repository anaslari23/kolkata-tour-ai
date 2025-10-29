import os
import json
import numpy as np
from pathlib import Path
from typing import List, Dict

import faiss  # type: ignore
from sentence_transformers import SentenceTransformer

DATA_JSON = os.path.join(os.path.dirname(__file__), '..', 'data', 'kolkata_places.json')
INDEX_DIR = os.path.join(os.path.dirname(__file__), '..', 'data', 'faiss_index')
MODEL_NAME = os.getenv('MODEL_NAME', 'sentence-transformers/all-MiniLM-L6-v2')


def load_items(path: str) -> List[Dict]:
    with open(path, 'r', encoding='utf-8') as f:
        items = json.load(f)
    # ensure fields exist
    for it in items:
        it.setdefault('city', 'Kolkata')
        it.setdefault('type', 'place')
        it.setdefault('story', it.get('description', ''))
        imgs = it.get('images')
        if isinstance(imgs, list) and len(imgs) > 0:
            primary = imgs[0]
        else:
            primary = None
        it.setdefault('image', primary)
    return items


def text_for_embedding(it: Dict) -> str:
    parts = [
        it.get('name', ''),
        it.get('category', ''),
        it.get('description', ''),
        it.get('story', ''),
        ' '.join(it.get('tags', [])),
        it.get('city', ''),
        it.get('type', ''),
    ]
    return '. '.join([p for p in parts if p])


def main():
    items = load_items(os.path.abspath(DATA_JSON))
    model = SentenceTransformer(MODEL_NAME)
    texts = [text_for_embedding(it) for it in items]
    print(f'Encoding {len(texts)} items with {MODEL_NAME}...')
    X = model.encode(texts, convert_to_numpy=True, normalize_embeddings=True)

    dim = X.shape[1]
    index = faiss.IndexFlatIP(dim)
    index.add(X)

    Path(INDEX_DIR).mkdir(parents=True, exist_ok=True)
    faiss.write_index(index, os.path.join(INDEX_DIR, 'index.faiss'))
    np.save(os.path.join(INDEX_DIR, 'vectors.npy'), X)
    with open(os.path.join(INDEX_DIR, 'meta.json'), 'w', encoding='utf-8') as f:
        json.dump(items, f, ensure_ascii=False)
    print('Index built at', INDEX_DIR)


if __name__ == '__main__':
    main()
