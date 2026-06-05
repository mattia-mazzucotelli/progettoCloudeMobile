import json
import os
import chromadb
from pymongo import MongoClient

# =========================
# CONFIG / CLIENT GLOBALI
# =========================

os.environ["CHROMA_CACHE_DIR"] = "/tmp/chroma"

CHROMA_HOST = os.environ.get("CHROMA_HOST", "localhost")
CHROMA_PORT = int(os.environ.get("CHROMA_PORT", "8000"))

MONGO_URI = os.environ.get("MONGO_URI")

# client riutilizzati tra invocazioni Lambda (IMPORTANTISSIMO)
chromadb_client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
collection = chromadb_client.get_collection(name="tedx_transcripts")

mongo_client = MongoClient(MONGO_URI)
db = mongo_client["unibg_tedx_2026"]
talks_collection = db["tedx_data"]

def lambda_handler(event, context):
    try:

        # -------------------------
        # PARSE BODY
        # -------------------------
        body = event
        if "body" in event:
            body = json.loads(event["body"]) if isinstance(event["body"], str) else event["body"]

        query_text = body.get("query")
        if not query_text:
            return _response(400, {"error": "Campo 'query' obbligatorio"})

        n_results = int(body.get("n_results", 5))

        results = collection.query(
            query_texts=[query_text],
            n_results=n_results,
        )

        ids = results.get("ids", [[]])[0]
        documents = results.get("documents", [[]])[0]
        metadatas = results.get("metadatas", [[]])[0]
        distances = results.get("distances", [[]])[0]

        talk_ids = list({
            m["talk_id"]
            for m in metadatas
            if "talk_id" in m
        })

        talks_cursor = talks_collection.find({
            "_id": {"$in": talk_ids}
        })

        talks_map = {
            t["_id"]: t
            for t in talks_cursor
        }

        # -------------------------
        # BUILD RESPONSE
        # -------------------------
        hits = []

        for i, doc_id in enumerate(ids):

            metadata = metadatas[i] if i < len(metadatas) else {}
            talk_id = metadata.get("talk_id")

            talk = talks_map.get(talk_id, {})

            hits.append({
                "id": doc_id,
                "document": documents[i] if i < len(documents) else None,
                "distance": distances[i] if i < len(distances) else None,

                "timestamp": metadata.get("timestamp"),

                "talk": {
                    "id": talk.get("_id"),
                    "title": talk.get("title"),
                    "speaker": talk.get("speakers"),
                    "url": talk.get("url"),
                    "description": talk.get("description"),
                    "duration": talk.get("duration"),
                    "publishedAt": talk.get("publishedAt"),
                    "tags": talk.get("tags", []),
                    "watch_next": talk.get("watch_next", [])
                }
            })

        return _response(200, {"results": hits})

    except Exception as e:
        return _response(500, {"error": str(e)})


# =========================
# RESPONSE HELPER
# =========================

def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body, ensure_ascii=False),
    }