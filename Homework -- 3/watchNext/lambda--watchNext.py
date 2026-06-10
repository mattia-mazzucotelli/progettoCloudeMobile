import json
import os
from pymongo import MongoClient
from bson import ObjectId

MONGO_URI = os.environ["MONGO_URI"]
DB_NAME = os.environ["DB_NAME"]
COLLECTION_NAME = os.environ["COLLECTION_NAME"]

client = MongoClient(MONGO_URI)
db = client[DB_NAME]
collection = db[COLLECTION_NAME]


def format_talk(doc):
    """Converte un documento MongoDB nel formato atteso dal frontend Flutter."""
    return {
        "id":            str(doc.get("_id", "")),
        "title":         doc.get("title", ""),
        "speaker":       doc.get("speaker", ""),
        "description":   doc.get("description", ""),
        "topic":         doc.get("topic", ""),
        "duration":      doc.get("duration", ""),
        "thumbnail_url": doc.get("thumbnail_url", ""),
        "video_url":     doc.get("video_url", ""),
        "youtube_id":    doc.get("youtube_id", ""),
        "year":          doc.get("year", 0),
        "event":         doc.get("event", ""),
        "tags":          doc.get("tags", []),
    }


def lambda_handler(event, context):
    try:
        # API Gateway mette il body come stringa in event["body"]
        # Se invece è invocata direttamente, i dati sono in event
        if "body" in event and event["body"]:
            body = json.loads(event["body"]) if isinstance(event["body"], str) else event["body"]
        else:
            body = event

        video_id = body.get("video_id")
        n = int(body.get("n", 5))
        if not video_id:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "video_id mancante"})
            }

        # 1. Recupera la lista di ID suggeriti per questo video
        video = collection.find_one(
            {"_id": video_id},
            {"watch_next": 1}
        )

        if not video:
            return {
                "statusCode": 404,
                "body": json.dumps({"error": "video non trovato"})
            }

        watch_next_ids = video.get("watch_next", [])[:n]

        if not watch_next_ids:
            return {
                "statusCode": 200,
                "body": json.dumps({"video_id": video_id, "watch_next": []})
            }

        # 2. Recupera i dettagli completi di ogni talk suggerito
        #    Gli ID potrebbero essere stringhe semplici o ObjectId — gestiamo entrambi
        cursor = collection.find({"_id": {"$in": watch_next_ids}})
        docs_by_id = {str(doc["_id"]): doc for doc in cursor}

        # 3. Mantieni l'ordine originale della lista watch_next
        result = []
        for wid in watch_next_ids:
            doc = docs_by_id.get(str(wid))
            if doc:
                result.append(format_talk(doc))

        return {
            "statusCode": 200,
            "body": json.dumps({
                "video_id": video_id,
                "watch_next": result
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }