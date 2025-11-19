import sys
import os
import json

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))

from backend.utils.rag_pipeline import RAGPipeline

def verify():
    print("Initializing RAG Pipeline...")
    data_path = os.path.join(os.path.dirname(__file__), '../../backend/data/kolkata_places.json')
    # We don't need the index dir for this test as we are testing the data loading and fallback logic mostly
    # or we can point to the existing one
    index_dir = os.path.join(os.path.dirname(__file__), '../../backend/data/faiss_index')
    
    rag = RAGPipeline(data_path, index_dir)
    
    print(f"Loaded {len(rag.items)} items.")
    
    # Test 1: Check data loading
    print("\n--- Test 1: Data Loading ---")
    victoria = next((it for it in rag.items if "Victoria" in it['name']), None)
    if victoria:
        print(f"Found: {victoria['name']}")
        print(f"History: {victoria.get('history')[:50]}...")
        print(f"Tips: {victoria.get('personal_tips')[:50]}...")
        
        if victoria.get('history') and victoria.get('personal_tips'):
            print("SUCCESS: History and Tips loaded.")
        else:
            print("FAILURE: Missing History or Tips.")
    else:
        print("FAILURE: Victoria Memorial not found.")

    # Test 2: Context Generation
    print("\n--- Test 2: Context Generation ---")
    context_str = rag._context_lines([victoria])
    print(f"Context:\n{context_str}")
    if "History:" in context_str and "Tip:" in context_str:
        print("SUCCESS: Context contains History and Tips.")
    else:
        print("FAILURE: Context missing new fields.")

    # Test 3: Answer Generation (Fallback)
    # We force fallback by not having requests/ollama running or just checking the fallback method directly
    print("\n--- Test 3: Fallback Answer ---")
    user_pref = {'mood': 'calm', 'interests': ['history'], 'time_preference': 'morning'}
    answer = rag._fallback_answer("Tell me about it", [victoria], user_pref, hour=10)
    print(f"Answer: {answer}")
    
    if "Insider tip:" in answer or "Did you know?" in answer:
        print("SUCCESS: Answer uses new fields.")
    else:
        print("FAILURE: Answer does not use new fields.")

if __name__ == "__main__":
    verify()
