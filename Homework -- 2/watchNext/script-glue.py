###### TEDx-Load-Aggregate-Model
import sys
import json
import pyspark
from pyspark.sql.functions import col, collect_list, array_join, struct
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

##### FROM FILES
tedx_dataset_path = "s3://tedx-2026-data-em/final_list.csv"

###### READ PARAMETERS
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

##### START JOB CONTEXT AND JOB
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

#### READ MAIN DATASET
tedx_dataset = spark.read \
    .option("header","true") \
    .option("quote", "\"") \
    .option("escape", "\"") \
    .csv(tedx_dataset_path)

tedx_dataset.printSchema()

#### FILTER ITEMS WITH NULL POSTING KEY
count_items = tedx_dataset.count()
count_items_null = tedx_dataset.filter("id is not null").count()
print(f"Number of items from RAW DATA {count_items}")
print(f"Number of items from RAW DATA with NOT NULL KEY {count_items_null}")

## READ THE DETAILS
details_dataset_path = "s3://tedx-2026-data-em/details.csv"
details_dataset_full = spark.read \
    .option("header","true") \
    .option("quote", "\"") \
    .option("escape", "\"") \
    .csv(details_dataset_path)

details_dataset = details_dataset_full.select(
    col("id").alias("id_ref"),
    col("description"),
    col("duration"),
    col("publishedAt"))

# JOIN WITH THE MAIN TABLE
tedx_dataset_main = tedx_dataset.join(
        details_dataset,
        tedx_dataset.id == details_dataset.id_ref,
        "left") \
    .drop("id_ref")

tedx_dataset_main.printSchema()

## READ TAGS DATASET
tags_dataset_path = "s3://tedx-2026-data-em/tags.csv"
tags_dataset = spark.read.option("header","true").csv(tags_dataset_path)

tags_dataset_agg = tags_dataset.groupBy(col("id").alias("id_ref")) \
    .agg(collect_list("tag").alias("tags"))

tedx_dataset_agg = tedx_dataset_main.join(
        tags_dataset_agg,
        tedx_dataset_main.id == tags_dataset_agg.id_ref,
        "left") \
    .drop("id_ref")

## WATCH_NEXT

watch_next_dataset_path = "s3://tedx-2026-data-em/related_videos.csv"
watch_next_dataset = spark.read \   
    .option("header","true") \
    .option("quote", "\"") \
    .option("escape", "\"") \
    .csv(watch_next_dataset_path)

# Mappiamo gli id interni con gli id pubblici
internal_to_id = details_dataset_full.select(
    col("interalId").alias("wn_internalId"),
    col("id").alias("wn_public_id")
)

watch_next_resolved = watch_next_dataset.join(
        internal_to_id,
        watch_next_dataset.related_id == internal_to_id.wn_internalId,  
        "left"
    ) \
    .select(
        col("id").alias("id_ref"),
        col("wn_public_id").alias("related_public_id")
    ) \
    .filter(col("related_public_id").isNotNull())

watch_next_agg = watch_next_resolved.groupBy("id_ref") \
    .agg(collect_list("related_public_id").alias("watch_next"))

tedx_dataset_agg = tedx_dataset_agg.join(
        watch_next_agg,
        tedx_dataset_agg.id == watch_next_agg.id_ref,
        "left") \
    .drop("id_ref")

# Rinominiamo id in _id per MongoDB
tedx_dataset_agg = tedx_dataset_agg \
    .select(col("id").alias("_id"), col("*")) \
    .drop("id")

tedx_dataset_agg.printSchema()

write_mongo_options = {
    "connectionName": "TEDX",
    "database": "unibg_tedx_2026",
    "collection": "tedx_data",
    "ssl": "true",
    "ssl.domain_match": "false"}

from awsglue.dynamicframe import DynamicFrame
tedx_dataset_dynamic_frame = DynamicFrame.fromDF(tedx_dataset_agg, glueContext, "nested")

glueContext.write_dynamic_frame.from_options(
    tedx_dataset_dynamic_frame,
    connection_type="mongodb",
    connection_options=write_mongo_options)

job.commit()