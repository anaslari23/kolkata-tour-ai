import os
import argparse
import subprocess


def main():
    p = argparse.ArgumentParser(description='Convert a CSV/Excel into backend JSON and rebuild FAISS index.')
    p.add_argument('--src', required=True, help='Path to CSV/XLSX of places')
    p.add_argument('--dst', default=os.path.join(os.path.dirname(__file__), '..', 'data', 'kolkata_places.json'))
    args = p.parse_args()

    root = os.path.dirname(__file__)
    converter = os.path.join(root, 'data_converter.py')
    build = os.path.join(root, 'build_index.py')

    print('[ingest] Converting to JSON...')
    subprocess.check_call(['python', converter, '--src', args.src, '--dst', args.dst])
    print('[ingest] Rebuilding FAISS index...')
    try:
        subprocess.check_call(['python', build])
    except Exception as e:
        print('[ingest] Skipped FAISS build:', e)
    print('[ingest] Done. JSON at', os.path.abspath(args.dst))


if __name__ == '__main__':
    main()


