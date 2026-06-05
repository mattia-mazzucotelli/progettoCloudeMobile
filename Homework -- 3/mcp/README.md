# 🎤 TEDx Talk Finder — Ollama + MCP

Client conversazionale per cercare TEDx talks tramite ricerca semantica,
usando un LLM locale (Ollama) collegato a un server MCP su AWS.

---

## Architettura

```
IL TUO PC                          AWS
┌─────────────────────┐            ┌─────────────────────┐
│  tedx_chat.py       │──HTTPS────▶│  server_mcp.py      │
│  (orchestratore)    │◀───────────│  (porta 8443)       │
│                     │            │                     │
│  Ollama (LLM)       │            │  MongoDB Atlas      │
│  gemma4 / llama3    │            │  Lambda (embeddings)│
└─────────────────────┘            └─────────────────────┘
```

- **Il tuo PC** esegue `tedx_chat.py` e Ollama (il modello AI gira in locale)
- **AWS** espone il server MCP con i tool di ricerca semantica

---

## Prerequisiti

- [Ollama](https://ollama.com/download) installato e in esecuzione
- Python 3.10+ con virtualenv
- Il server MCP su AWS attivo e raggiungibile

---

## Installazione

```bash
# Crea e attiva il virtualenv
python -m venv .venv
.venv\Scripts\activate        # Windows
# source .venv/bin/activate   # Mac/Linux

# Installa le dipendenze
pip install ollama mcp python-dotenv
```

Scarica il modello LLM (una volta sola):

```bash
ollama pull gemma4:latest
```

---

## Configurazione

Crea un file `.env` nella stessa cartella di `tedx_chat.py`:

```dotenv
# Indirizzo del server MCP su AWS
MCP_HOST=<IP-del-server-AWS>
MCP_PORT=8443
MCP_SCHEME=https
MCP_PATH=/sse

# Modello Ollama da usare
OLLAMA_MODEL=gemma4:latest
```

> Sostituisci `<IP-del-server-AWS>` con l'IP pubblico della tua istanza EC2.

---

## Avvio

Assicurati che Ollama sia in esecuzione, poi:

```bash
python tedx_chat.py
```

Output atteso:

```
🔗 Server MCP : https://localhost:8443/mcp
🤖 Modello    : gemma4:latest
--------------------------------------------------
TeddyFind - Chat con il server MCP di TEDx...

Tu: 
```

---

## Utilizzo

Scrivi la tua domanda in linguaggio naturale, in italiano o inglese:

```
Tu: Cerca talk sull'intelligenza artificiale nella società
Tu: Find talks about overcoming fear
Tu: Quali sono i migliori talk sulla creatività?
Tu: exit
```

Il sistema:
1. Invia la domanda a Ollama (locale)
2. Ollama chiama il tool `semantic_search` sul server MCP (AWS)
3. Il server cerca nei TEDx talks tramite embeddings vettoriali
4. Ollama riceve i risultati e formula una risposta in linguaggio naturale

---

## Variabili d'ambiente

| Variabile | Default | Descrizione |
|---|---|---|
| `MCP_HOST` | `44.201.141.192` | IP o hostname del server MCP |
| `MCP_PORT` | `8443` | Porta del server MCP |
| `MCP_SCHEME` | `https` | Protocollo (`http` o `https`) |
| `MCP_PATH` | `/sse` | Path endpoint (`/sse` o `/mcp`) |
| `OLLAMA_MODEL` | `gemma4:latest` | Modello Ollama da usare |

### Quando usare `/sse` vs `/mcp`

| Scenario | `MCP_PATH` |
|---|---|
| Server remoto AWS (fastmcp legacy) | `/sse` |
| Server locale fastmcp 3.x | `/mcp` |

---

## Modelli consigliati

I modelli devono supportare il **tool calling**:

| Modello | Dimensione | Qualità tool calling |
|---|---|---|
| `gemma4:latest` | ~9GB | ✅ Ottima |
| `llama3.2:latest` | ~2GB | ✅ Buona |
| `mistral:latest` | ~4GB | ✅ Buona |
| `qwen2.5:latest` | ~4GB | ✅ Ottima |

---

## Troubleshooting

**Errore: `connection refused`**
→ Il server MCP su AWS non è raggiungibile. Verifica che l'istanza EC2 sia avviata e che la porta 8443 sia aperta nel Security Group.

**Errore: `404 Not Found` su `/sse`**
→ Il server usa fastmcp 3.x. Cambia `MCP_PATH=/mcp` nel `.env`.

**Errore: `SSL certificate verify failed`**
→ Il certificato è self-signed, il client lo bypassa automaticamente con `verify=False`.

**Il modello non chiama i tool**
→ Prova un modello diverso (es. `llama3.2` o `qwen2.5`). Non tutti i modelli supportano il tool calling.

**Ollama non risponde**
→ Verifica che Ollama Desktop sia aperto oppure lancia `ollama serve` da terminale.
