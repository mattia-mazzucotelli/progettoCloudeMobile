import json
import os
from pymongo import MongoClient

MONGO_URI = os.environ["MONGO_URI"]
DB_NAME = os.environ["DB_NAME"]
COLLECTION_NAME = os.environ["COLLECTION_NAME"]

client = MongoClient(MONGO_URI)

db = client[DB_NAME]
collection = db[COLLECTION_NAME]


def lambda_handler(event, context):
    try:
        video_id = event.get("video_id")
        n = int(event.get("n", 5))

        if not video_id:
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "error": "video_id mancante"
                })
            }

        # Cerca il documento
        video = collection.find_one(
            {"_id": video_id},
            {"watch_next": 1}
        )

        if not video:
            return {
                "statusCode": 404,
                "body": json.dumps({
                    "error": "video non trovato"
                })
            }

        watch_next = video.get("watch_next", [])

        # primi n
        result = watch_next[:n]

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
            "body": json.dumps({
                "error": str(e)
            })
        }