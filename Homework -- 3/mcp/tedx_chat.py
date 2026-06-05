"""
TEDx Chat - Ollama + MCP / Groq + MCP
Configurazione tramite file .env:

    # Server MCP
    MCP_HOST=54.209.86.124
    MCP_PORT=8443
    MCP_SCHEME=https
    MCP_PATH=/mcp

    # Provider LLM: 'ollama' oppure 'groq'
    LLM_PROVIDER=groq

    # --- Se LLM_PROVIDER=ollama ---
    OLLAMA_MODEL=gemma4:latest

    # --- Se LLM_PROVIDER=groq ---
    GROQ_API_KEY=gsk_xxxxxxxxxxxx
    GROQ_MODEL=llama-3.3-70b-versatile
"""

import os
import json
import asyncio
import httpx
import ollama
from dotenv import load_dotenv

load_dotenv()

# --- Configurazione MCP ---
MCP_HOST   = os.getenv("MCP_HOST", "54.209.86.124")
MCP_PORT   = os.getenv("MCP_PORT", "8443")
MCP_SCHEME = os.getenv("MCP_SCHEME", "https")
MCP_PATH   = os.getenv("MCP_PATH", "/mcp")
MCP_URL    = f"{MCP_SCHEME}://{MCP_HOST}:{MCP_PORT}{MCP_PATH}"

# --- Configurazione LLM ---
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "ollama").lower()
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "gemma4:latest")
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL   = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")

print(f"🔗 Server MCP : {MCP_URL}")
print(f"🤖 Provider   : {LLM_PROVIDER.upper()}", end="")
if LLM_PROVIDER == "ollama":
    print(f" ({OLLAMA_MODEL})")
else:
    print(f" ({GROQ_MODEL})")
print("-" * 50)


def llm_chat(messages: list, tools: list) -> object:
    """Chiama il LLM configurato (Ollama o Groq) e restituisce la risposta."""
    if LLM_PROVIDER == "groq":
        from groq import Groq
        client = Groq(api_key=GROQ_API_KEY)
        # Converti tools nel formato OpenAI/Groq
        groq_tools = [
            {
                "type": "function",
                "function": {
                    "name": t["function"]["name"],
                    "description": t["function"]["description"],
                    "parameters": t["function"]["parameters"],
                },
            }
            for t in tools
        ] if tools else None

        # Converti messaggi: rimuovi campi non supportati da Groq
        groq_messages = []
        for m in messages:
            if isinstance(m, dict):
                groq_messages.append(m)
            else:
                # Oggetto message di Ollama → dizionario
                msg = {"role": m.role, "content": m.content or ""}
                if hasattr(m, "tool_calls") and m.tool_calls:
                    msg["tool_calls"] = [
                        {
                            "id": f"call_{i}",
                            "type": "function",
                            "function": {
                                "name": tc.function.name,
                                "arguments": json.dumps(tc.function.arguments),
                            },
                        }
                        for i, tc in enumerate(m.tool_calls)
                    ]
                groq_messages.append(msg)

        # FIX: non passare tools/tool_choice se la lista è vuota,
        # altrimenti Groq restituisce 400 Bad Request
        kwargs = dict(model=GROQ_MODEL, messages=groq_messages)
        if groq_tools:
            kwargs["tools"] = groq_tools
            kwargs["tool_choice"] = "auto"

        resp = client.chat.completions.create(**kwargs)
        return resp.choices[0].message

    else:  # ollama
        resp = ollama.chat(model=OLLAMA_MODEL, messages=messages, tools=tools)
        return resp.message


def get_tool_calls(message) -> list:
    """Estrae i tool calls dal messaggio, compatibile con Ollama e Groq."""
    if LLM_PROVIDER == "groq":
        return message.tool_calls or []
    else:
        return message.tool_calls or []


def get_tool_call_info(tool_call) -> tuple[str, dict]:
    """Restituisce (nome, argomenti) del tool call, compatibile con entrambi i provider."""
    if LLM_PROVIDER == "groq":
        name = tool_call.function.name
        args = json.loads(tool_call.function.arguments)
    else:
        name = tool_call.function.name
        args = tool_call.function.arguments
    return name, args


def message_to_dict(message) -> dict:
    """Converte un messaggio LLM in dizionario per la history."""
    if isinstance(message, dict):
        return message
    if LLM_PROVIDER == "groq":
        msg = {"role": message.role, "content": message.content or ""}
        if message.tool_calls:
            msg["tool_calls"] = [
                {
                    "id": tc.id,
                    "type": "function",
                    "function": {
                        "name": tc.function.name,
                        "arguments": tc.function.arguments,
                    },
                }
                for tc in message.tool_calls
            ]
        return msg
    else:
        return message


async def chat(user_query: str):
    """Esegue una domanda usando il LLM configurato + tool calling verso il server MCP."""
    from mcp import ClientSession
    from mcp.client.streamable_http import streamablehttp_client
    from mcp.client.sse import sse_client

    original_init = httpx.AsyncClient.__init__
    def patched_init(self, *args, **kwargs):
        kwargs["verify"] = False
        original_init(self, *args, **kwargs)
    httpx.AsyncClient.__init__ = patched_init

    try:
        cm = streamablehttp_client(MCP_URL) if MCP_PATH == "/mcp" else sse_client(MCP_URL)

        async with cm as streams:
            read, write = (streams[0], streams[1]) if len(streams) >= 2 else streams

            async with ClientSession(read, write) as session:
                await session.initialize()

                tools_result = await session.list_tools()
                ollama_tools = [
                    {
                        "type": "function",
                        "function": {
                            "name": t.name,
                            "description": t.description,
                            "parameters": t.inputSchema,
                        },
                    }
                    for t in tools_result.tools
                ]
                print(f"🛠️  Tool: {[t.name for t in tools_result.tools]}\n")

                messages = [{"role": "user", "content": user_query}]
                response = llm_chat(messages, ollama_tools)

                if get_tool_calls(response):
                    messages.append(message_to_dict(response))

                    for tool_call in get_tool_calls(response):
                        name, args = get_tool_call_info(tool_call)
                        print(f"⚙️  Tool: {name}({args})")

                        result = await session.call_tool(name, arguments=args)
                        content = result.content[0].text if result.content else ""
                        print(f"📦 Risultato: {content[:-1]}...\n")

                        # FIX: se il tool restituisce un errore (es. 502 Bad Gateway),
                        # segnalalo al modello invece di passare il testo d'errore grezzo
                        if content.startswith("Error executing tool"):
                            print(f"⚠️  Tool {name} ha restituito un errore, uso fallback.\n")
                            content = (
                                f"Il tool '{name}' non è disponibile al momento "
                                f"(errore 502 del server remoto). "
                                f"NON inventare risultati o video. "
                                f"Informa l'utente che il servizio di ricerca è temporaneamente "
                                f"non disponibile e suggeriscigli di riprovare tra qualche minuto."
                            )

                        if LLM_PROVIDER == "groq":
                            tc_id = tool_call.id if hasattr(tool_call, "id") else "call_0"
                            messages.append({"role": "tool", "tool_call_id": tc_id, "content": content})
                        else:
                            messages.append({"role": "tool", "content": content})

                    final = llm_chat(messages, [])
                    return final.content if LLM_PROVIDER == "groq" else final.content

                return response.content if LLM_PROVIDER == "groq" else response.content

    finally:
        httpx.AsyncClient.__init__ = original_init


async def main():
    print("🎤 TEDx Talk Finder - powered by MCP")
    print("   Digita 'exit' per uscire\n")

    while True:
        try:
            query = input("Tu: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nArrivederci!")
            break

        if query.lower() in ("exit", "quit", "esci"):
            print("Arrivederci!")
            break
        if not query:
            continue

        try:
            answer = await chat(query)
            print(f"\nAssistente: {answer}\n")
            print("-" * 50)
        except Exception as e:
            import traceback
            print(f"❌ Errore: {e}")
            traceback.print_exc()
            print()


if __name__ == "__main__":
    asyncio.run(main())