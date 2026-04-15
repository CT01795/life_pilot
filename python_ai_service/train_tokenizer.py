import sentencepiece as spm
import json

with open("chat.json", "r", encoding="utf-8") as f:
    dataset = json.load(f)

with open("train.txt", "w", encoding="utf-8") as f:
    for item in dataset:
        f.write(f"User: {item['user']}\n")
        f.write(f"Assistant: {item['assistant']}<END>\n\n")

print("✅ train.txt 已產生")

spm.SentencePieceTrainer.train(
    input="train.txt",
    model_prefix="bpe",
    vocab_size=2000,
    model_type="bpe",
    character_coverage=0.9995
)