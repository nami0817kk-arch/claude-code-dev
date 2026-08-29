import sys
from pathlib import Path

# `from src.analysis...` の形でインポートできるよう、PJT ルートを通す
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
