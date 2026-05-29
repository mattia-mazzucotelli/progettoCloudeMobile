###### TEDx-Load-Transcriptions-To-Chroma
import sys
import json
import boto3
import requests
from pyspark.sql.functions import col
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

##### FROM FILES
trascrizioni_dataset_path = "s3://tedx-2026-data-em/trascrizioni.csv"

##### CONFIG
CHROMA_HOST = "107.23.168.198"
CHROMA_PORT = 8000
CHROMA_TENANT = "default_tenant"
CHROMA_DATABASE = "default_database"
CHROMA_COLLECTION = "tedx_transcripts"
BEDROCK_REGION = "us-east-1"
BEDROCK_MODEL_ID = "amazon.titan-embed-text-v2:0"
BATCH_SIZE = 100

CHROMA_BASE_URL = f"http://{CHROMA_HOST}:{CHROMA_PORT}/api/v2/tenants/{CHROMA_TENANT}/databases/{CHROMA_DATABASE}"

###### READ PARAMETERS
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

##### START JOB CONTEXT
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

#### READ TRANSCRIPTIONS
trascrizioni_dataset = spark.read \
    .option("header","true") \
    .option("quote", "\"") \
    .option("escape", "\"") \
    .csv(trascrizioni_dataset_path)

trascrizioni_dataset.printSchema()
print(f"Number of sentences: {trascrizioni_dataset.count()}")

rows = trascrizioni_dataset.select("id", "timestamp", "sentence") \
    .filter(col("sentence").isNotNull()) \
    .collect()

# ============================================================
# BEDROCK CLIENT
# ============================================================
bedrock = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)

def embed(text):
    resp = bedrock.invoke_model(
        modelId=BEDROCK_MODEL_ID,
        body=json.dumps({"inputText": text})
    )
    return json.loads(resp["body"].read())["embedding"]

# ============================================================
# CHROMA
# ============================================================
r = requests.get(f"{CHROMA_BASE_URL}/collections")
r.raise_for_status()
collections = r.json()
existing = {c["name"]: c["id"] for c in collections}

if CHROMA_COLLECTION in existing:
    collection_id = existing[CHROMA_COLLECTION]
    print(f"Found existing collection {CHROMA_COLLECTION} (id={collection_id})")
else:
    r = requests.post(
        f"{CHROMA_BASE_URL}/collections",
        json={"name": CHROMA_COLLECTION, "metadata": {"hnsw:space": "cosine"}}
    )
    r.raise_for_status()
    collection_id = r.json()["id"]
    print(f"Created collection {CHROMA_COLLECTION} (id={collection_id})")

# ============================================================
# COSTRUZIONE E UPSERT A BATCH (API v2)
# ============================================================
def flush_batch(ids, docs, embs, metas):
    if not ids:
        return
    resp = requests.post(
        f"{CHROMA_BASE_URL}/collections/{collection_id}/upsert",
        json={
            "ids": ids,
            "documents": docs,
            "embeddings": embs,
            "metadatas": metas
        }
    )
    resp.raise_for_status()

batch_ids, batch_docs, batch_embs, batch_metas = [], [], [], []

for i, r in enumerate(rows):
    batch_ids.append(f"{r['id']}_{i}")
    batch_docs.append(r["sentence"])
    batch_embs.append(embed(r["sentence"]))
    batch_metas.append({"talk_id": r["id"], "timestamp": r["timestamp"]})

    if len(batch_ids) >= BATCH_SIZE:
        flush_batch(batch_ids, batch_docs, batch_embs, batch_metas)
        print(f"Upserted batch ending at {i+1}/{len(rows)}")
        batch_ids, batch_docs, batch_embs, batch_metas = [], [], [], []

flush_batch(batch_ids, batch_docs, batch_embs, batch_metas)
print("Done. Chroma collection updated.")

job.commit()