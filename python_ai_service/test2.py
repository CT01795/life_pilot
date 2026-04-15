import torch
import torch.nn as nn
import torch.nn.functional as F
import json
import sentencepiece as spm

# ====== 載入 BPE ======
sp = spm.SentencePieceProcessor()
sp.load("bpe.model")

VOCAB_SIZE = sp.get_piece_size()

encode = lambda s: sp.encode(s, out_type=int)
decode = lambda l: sp.decode(l)

# ====== 載入資料 ======
with open("chat.json", "r", encoding="utf-8") as f:
    dataset = json.load(f)

text = ""
for item in dataset:
    text += f"User: {item['user']}\n"
    text += f"Assistant: {item['assistant']}<END>\n\n"

data = torch.tensor(encode(text), dtype=torch.long)

# ====== 超參數 ======
block_size = 64
batch_size = 4
device = "cuda" if torch.cuda.is_available() else "cpu"

# ====== 取 batch ======
def get_batch():
    ix = torch.randint(len(data) - block_size, (batch_size,))

    x, y, mask = [], [], []

    assistant_tokens = torch.tensor(encode("Assistant:"))

    for i in ix:
        chunk = data[i:i+block_size+1]

        xi = chunk[:-1]
        yi = chunk[1:]

        mi = torch.zeros(block_size, dtype=torch.float32)

        # 找 Assistant 開始
        for t in range(block_size - len(assistant_tokens)):
            if torch.equal(xi[t:t+len(assistant_tokens)], assistant_tokens):
                mi[t:] = 1
                break

        # fallback（避免全 0）
        if mi.sum() == 0:
            mi[:] = 1

        x.append(xi)
        y.append(yi)
        mask.append(mi)

    return (
        torch.stack(x).to(device),
        torch.stack(y).to(device),
        torch.stack(mask).to(device)
    )

# ====== Transformer ======
class Head(nn.Module):
    def __init__(self, n_embd, head_size):
        super().__init__()
        self.key = nn.Linear(n_embd, head_size, bias=False)
        self.query = nn.Linear(n_embd, head_size, bias=False)
        self.value = nn.Linear(n_embd, head_size, bias=False)

        self.register_buffer("tril", torch.tril(torch.ones(block_size, block_size)))

    def forward(self, x):
        B, T, C = x.shape

        k = self.key(x)
        q = self.query(x)

        wei = q @ k.transpose(-2, -1) * (C ** -0.5)
        wei = wei.masked_fill(self.tril[:T, :T] == 0, float("-inf"))
        wei = F.softmax(wei, dim=-1)

        v = self.value(x)
        return wei @ v


class MultiHead(nn.Module):
    def __init__(self, n_embd, n_heads):
        super().__init__()
        head_size = n_embd // n_heads
        self.heads = nn.ModuleList(
            [Head(n_embd, head_size) for _ in range(n_heads)]
        )
        self.proj = nn.Linear(n_embd, n_embd)

    def forward(self, x):
        out = torch.cat([h(x) for h in self.heads], dim=-1)
        return self.proj(out)


class Block(nn.Module):
    def __init__(self, n_embd, n_heads):
        super().__init__()
        self.sa = MultiHead(n_embd, n_heads)
        self.ff = nn.Sequential(
            nn.Linear(n_embd, 4 * n_embd),
            nn.ReLU(),
            nn.Linear(4 * n_embd, n_embd),
        )
        self.ln1 = nn.LayerNorm(n_embd)
        self.ln2 = nn.LayerNorm(n_embd)

    def forward(self, x):
        x = x + self.sa(self.ln1(x))
        x = x + self.ff(self.ln2(x))
        return x


class GPT(nn.Module):
    def __init__(self):
        super().__init__()

        n_embd = 64
        n_heads = 4

        self.token_emb = nn.Embedding(VOCAB_SIZE, n_embd)
        self.pos_emb = nn.Embedding(block_size, n_embd)

        self.blocks = nn.Sequential(
            Block(n_embd, n_heads),
            Block(n_embd, n_heads),
        )

        self.ln = nn.LayerNorm(n_embd)
        self.head = nn.Linear(n_embd, VOCAB_SIZE)

    def forward(self, idx, targets=None):
        B, T = idx.shape

        tok = self.token_emb(idx)
        pos = self.pos_emb(torch.arange(T, device=idx.device))

        x = tok + pos
        x = self.blocks(x)
        x = self.ln(x)
        logits = self.head(x)

        if targets is None:
            return logits, None

        loss = F.cross_entropy(
            logits.view(-1, VOCAB_SIZE),
            targets.view(-1)
        )
        return logits, loss


# ====== Masked Loss ======
def masked_loss(logits, targets, mask):
    loss = F.cross_entropy(
        logits.view(-1, VOCAB_SIZE),
        targets.view(-1),
        reduction="none",
    )

    loss = loss.view(mask.shape)
    loss = loss * mask

    return loss.sum() / mask.sum()


# ====== Chat ======
def chat(model, prompt, max_new_tokens=100):
    model.eval()

    idx = torch.tensor([encode(prompt)], dtype=torch.long).to(device)
    end_token = sp.encode("<END>", out_type=int)
    end_tensor = torch.tensor(end_token, device=device)

    for _ in range(max_new_tokens):
        idx_cond = idx[:, -block_size:]

        logits, _ = model(idx_cond)
        logits = logits[:, -1, :]

        probs = torch.softmax(logits, dim=-1)
        next_token = torch.multinomial(probs, 1)

        idx = torch.cat([idx, next_token], dim=1)

        # stop
        if idx.shape[1] >= len(end_token):
            if torch.equal(idx[0, -len(end_token):], end_tensor):
                break

    return decode(idx[0].tolist())


# ====== Train ======
model = GPT().to(device)
optimizer = torch.optim.AdamW(model.parameters(), lr=3e-4)

for step in range(1000):
    xb, yb, mb = get_batch()

    logits, _ = model(xb)
    loss = masked_loss(logits, yb, mb)

    optimizer.zero_grad()
    loss.backward()
    optimizer.step()

    if step % 100 == 0:
        print(step, loss.item())


# ====== 測試 ======
print(chat(model, "User: 你好\nAssistant: "))


# ====== 多輪對話 ======
history = ""

while True:
    user_input = input("You: ")
    if user_input == "exit":
        break

    history += f"User: {user_input}\nAssistant: "

    output = chat(model, history)

    # 擷取最後回答
    answer = output.split("<END>")[0]
    answer = answer.split("Assistant:")[-1]

    print("Bot:", answer.strip())

    history += answer + "<END>\n"