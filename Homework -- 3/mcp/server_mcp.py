"""
TEDx MCP Server
A simple MCP server exposing TEDx talks stored in MongoDB Atlas.
University lesson demo - unibg_tedx_2026
"""

import httpx
from mcp.server.fastmcp import FastMCP
from motor.motor_asyncio import AsyncIOMotorClient
from mcp.server.transport_security import TransportSecuritySettings

# --- MongoDB Atlas connection ---
MONGO_URI = (
    "mongodb+srv://unibg2026:unibg2026"
    "@cluster0.nzhyx3r.mongodb.net/"
)

# --- AWS Lambda endpoint ---
LAMBDA_URL = "https://65le9pogng.execute-api.us-east-1.amazonaws.com/default/chromadb-query"
LAMBDA_HEADERS = {"Content-Type": "application/json"}

client = AsyncIOMotorClient(MONGO_URI)
db = client["unibg_tedx_2026"]
collection = db["tedx_data"]

# --- MCP server ---
mcp = FastMCP(
    "tedx-server",
    host="0.0.0.0",
    port=8443,
    transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False),
)


# ============================================================
# TOOLS
# ============================================================

@mcp.tool()
async def search_by_tag(tag: str, limit: int = 5) -> list[dict]:
    """Search TEDx talks that contain a given tag (e.g. 'culture', 'media')."""
    cursor = collection.find(
        {"tags": tag.lower()},
        {"_id": 0, "title": 1, "speakers": 1, "url": 1, "tags": 1, "duration": 1},
    ).limit(limit)
    return await cursor.to_list(length=limit)


@mcp.tool()
async def search_by_speaker(speaker: str, limit: int = 5) -> list[dict]:
    """Find talks by speaker name (case-insensitive partial match)."""
    cursor = collection.find(
        {"speakers": {"$regex": speaker, "$options": "i"}},
        {"_id": 0, "title": 1, "speakers": 1, "url": 1, "publishedAt": 1},
    ).limit(limit)
    return await cursor.to_list(length=limit)


@mcp.tool()
async def search_by_keyword(keyword: str, limit: int = 5) -> list[dict]:
    """Search talks by keyword in title or description."""
    cursor = collection.find(
        {
            "$or": [
                {"title": {"$regex": keyword, "$options": "i"}},
                {"description": {"$regex": keyword, "$options": "i"}},
            ]
        },
        {"_id": 0, "title": 1, "speakers": 1, "url": 1, "description": 1},
    ).limit(limit)
    return await cursor.to_list(length=limit)


@mcp.tool()
async def get_talk(slug: str) -> dict:
    """Get full details for a single talk by its slug."""
    talk = await collection.find_one({"slug": slug}, {"_id": 0})
    return talk or {"error": f"No talk found with slug '{slug}'"}


@mcp.tool()
async def top_tags(limit: int = 10) -> list[dict]:
    """Return the most common tags across all talks."""
    pipeline = [
        {"$unwind": "$tags"},
        {"$group": {"_id": "$tags", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
        {"$limit": limit},
        {"$project": {"_id": 0, "tag": "$_id", "count": 1}},
    ]
    return await collection.aggregate(pipeline).to_list(length=limit)

@mcp.tool()
async def semantic_search(query: str, n_results: int = 5) -> list[dict]:
    """
    Cerca TEDx talks per similarità semantica nelle trascrizioni.
    Usa questa funzione quando si cerca per concetti, temi o frasi
    (es. 'talks about overcoming fear', 'artificial intelligence and society').
    Restituisce titolo, speaker, URL e l'estratto della trascrizione più rilevante.
    """

    # 1. Call Lambda
    async with httpx.AsyncClient(timeout=15.0) as http:
        resp = await http.post(
            LAMBDA_URL,
            headers=LAMBDA_HEADERS,
            json={"query": query, "n_results": n_results},
        )
        resp.raise_for_status()
        data = resp.json()

    hits = data.get("results", [])
    if not hits:
        return []

    # 2. Deduplicate by talk_id keeping best score (lowest distance)
    best: dict[str, dict] = {}

    for h in hits:
        talk = h.get("talk", {})
        tid = talk.get("id")

        if not tid:
            continue

        if tid not in best or h["distance"] < best[tid]["distance"]:
            best[tid] = h

    # 3. Build final response
    results = []

    for tid, hit in best.items():
        talk = hit.get("talk", {})

        results.append({
            "talk_id": tid,
            "score": round(1 - hit.get("distance", 1), 4),
            "timestamp": hit.get("timestamp"),
            "excerpt": hit.get("document"),

            # enriched fields directly from Lambda
            "title": talk.get("title"),
            "speakers": talk.get("speaker"),
            "url": talk.get("url"),
            "description": talk.get("description"),
            "duration": talk.get("duration"),
            "publishedAt": talk.get("publishedAt"),
            "tags": talk.get("tags", []),
        })

    # sort by relevance
    results.sort(key=lambda x: x["score"], reverse=True)

    return results


# ============================================================
# RESOURCES
# ============================================================

@mcp.resource("tedx://schema")
async def get_schema() -> str:
    """Expose the TEDx collection schema as a resource."""
    return """
    Collection: unibg_tedx_2026.tedx_data
    Fields:
      - _id: string
      - slug: string           (unique identifier of the talk)
      - speakers: string       (speaker name)
      - title: string          (talk title)
      - url: string            (TED.com URL)
      - description: string    (full description)
      - duration: string       (length in seconds)
      - publishedAt: string    (ISO date)
      - tags: array[string]    (topic tags)
    """


@mcp.resource("tedx://stats")
async def get_stats() -> str:
    """Basic stats about the TEDx dataset."""
    total = await collection.count_documents({})
    return f"Total talks in dataset: {total}"


# ============================================================
# PROMPTS
# ============================================================

@mcp.prompt()
def recommend_prompt(topic: str) -> str:
    """Template prompt to recommend talks on a given topic."""
    return (
        f"Use the `search_by_tag` or `search_by_keyword` tool to find TEDx talks "
        f"about '{topic}'. Then summarize the 3 most relevant ones, including "
        f"speaker, title and a one-line takeaway. Provide the URLs at the end."
    )


@mcp.prompt()
def speaker_profile_prompt(speaker: str) -> str:
    """Template prompt to build a profile of a speaker from their talks."""
    return (
        f"Use `search_by_speaker` to retrieve all talks by '{speaker}'. "
        f"Then describe their main themes, style and recurring ideas."
    )


@mcp.prompt()
def semantic_search_prompt(concept: str) -> str:
    """Prompt per ricerca semantica sulle trascrizioni."""
    return (
        f"Usa `semantic_search` per trovare TEDx talks le cui trascrizioni parlano di '{concept}'. "
        f"Per ogni risultato, mostra titolo, speaker, score di similarità e un breve estratto. "
        f"Alla fine fornisci i link URL."
    )


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        mcp.streamable_http_app(),
        host="0.0.0.0",
        port=8443,
        ssl_keyfile="key.pem",
        ssl_certfile="cert.pem",
    )
