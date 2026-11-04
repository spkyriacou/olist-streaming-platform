from contextlib import closing
import csv
import os

import boto3
import psycopg
from psycopg import sql


FILES = {
    "geolocation": "olist_geolocation_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "product_category_translation": "product_category_name_translation.csv",
}


def main():
    s3 = boto3.client(
        "s3",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "eu-west-2"),
    )
    bucket = os.environ["S3_BUCKET"]
    prefix = os.environ.get("S3_PREFIX", "raw/olist/")

    # This connection context commits only if every table loads successfully.
    with psycopg.connect(
        host=os.environ.get("PGHOST", "postgres"),
        dbname=os.environ.get("PGDATABASE", "olist"),
        user=os.environ.get("PGUSER", "olist_admin"),
        password=os.environ["PGPASSWORD"],
        connect_timeout=15,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SET LOCAL lock_timeout = '15s'")

            tables = sql.SQL(", ").join(
                sql.Identifier("source", table) for table in FILES
            )
            cursor.execute(
                sql.SQL("LOCK TABLE {} IN EXCLUSIVE MODE").format(tables)
            )

            # Initial-load safety: refuse to append to populated tables.
            for table in FILES:
                cursor.execute(
                    sql.SQL("SELECT EXISTS (SELECT 1 FROM {})").format(
                        sql.Identifier("source", table)
                    )
                )
                if cursor.fetchone()[0]:
                    raise RuntimeError(
                        f"source.{table} already contains data. "
                        "Initial load cancelled to avoid duplicates."
                    )

            for table, filename in FILES.items():
                key = prefix + filename
                print(f"Loading s3://{bucket}/{key} -> source.{table}")

                response = s3.get_object(Bucket=bucket, Key=key)

                with closing(response["Body"]) as body:
                    first_chunk = body.read(65536)
                    if first_chunk.startswith(b"\xef\xbb\xbf"):
                        first_chunk = first_chunk[3:]

                    header, separator, _ = first_chunk.partition(b"\n")
                    if not separator:
                        raise RuntimeError(f"Missing CSV header: {filename}")

                    columns = next(csv.reader([header.decode("utf-8")]))

                    cursor.execute(
                        """
                        SELECT column_name
                        FROM information_schema.columns
                        WHERE table_schema = 'source'
                          AND table_name = %s
                          AND is_identity = 'NO'
                        ORDER BY ordinal_position
                        """,
                        (table,),
                    )
                    expected = [row[0] for row in cursor.fetchall()]

                    if columns != expected:
                        raise RuntimeError(
                            f"Header mismatch for {filename}: "
                            f"expected {expected}, got {columns}"
                        )

                    statement = sql.SQL(
                        "COPY {} ({}) FROM STDIN "
                        "WITH (FORMAT CSV, HEADER TRUE)"
                    ).format(
                        sql.Identifier("source", table),
                        sql.SQL(", ").join(map(sql.Identifier, columns)),
                    )

                    with cursor.copy(statement) as copy:
                        copy.write(first_chunk)
                        while chunk := body.read(1024 * 1024):
                            copy.write(chunk)

                cursor.execute(
                    sql.SQL("SELECT count(*) FROM {}").format(
                        sql.Identifier("source", table)
                    )
                )
                print(f"  {cursor.fetchone()[0]:,} rows loaded; awaiting commit")

    print("Success: all four reference tables committed.")


if __name__ == "__main__":
    main()