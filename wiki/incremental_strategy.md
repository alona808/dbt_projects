### ***Incremental Model Strategies***

One-line summary under the table:

##### **Rule of thumb:**

- `append` = cheapest, but no protection against duplicates or updates
- `merge` = default upsert choice when keys are reliable
- `delete+insert` = safer fallback when `merge` is unsupported or problematic
- `insert_overwrite` = best for partitioned tables
- `microbatch` = best for very large time-series/event workloads

##### **A cleaner “Action” wording version:**

- append → insert only
- delete+insert → replace matched rows
- merge → upsert matched rows
- insert_overwrite → replace partitions. Much more efficient then merge on ***BigQuery***.
- microbatch → process incrementally in batches

##### **Short comparison of Incremental Model Strategies:**

| Strategy             | Action               | Table scan?                                 | Check duplicates?       | Updates existing rows?  | Best for                                    | Compute costs |
| -------------------- | -------------------- | ------------------------------------------- | ----------------------- | ----------------------- | ------------------------------------------- | ------------- |
| `append`           | Insert only          | New rows only; no target match              | No                      | No                      | Append-only data                            | Low           |
| `delete+insert`    | Replace matched rows | Incremental batch + matching target rows    | Yes, via `unique_key` | Yes                     | Mutable rows when `merge` is not suitable | Medium-High   |
| `merge`            | Upsert matched rows  | Compares source to target on `unique_key` | Yes                     | Yes                     | Standard upsert workloads                   | Medium-High   |
| `insert_overwrite` | Replace partitions   | Rebuilds overwritten partitions             | No, not row-level       | Yes, partition-level    | Partitioned tables                          | Low-Medium    |
| `microbatch`       | Process in batches   | Smaller batch scans                         | Depends on adapter      | Yes, depends on adapter | Very large time-series data                 | Medium        |

##### **Detailed comparison of Incremental Model Strategies:**

| Strategy             | Action                                                                                      | Table scan?                                                                                                                                    | Check duplicates?                                                                                                            | Updates existing rows?                                                            | Best for                                                                                                                          | Resource consumption                                                                                             |
| -------------------- | ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `append`           | Inserts new rows only. No overwrite, no delete.                                             | Usually scans only the new/incremental dataset produced by the model query. Does not need to match against existing target rows.               | No. Duplicates can accumulate if the source is not truly append-only or the incremental filter overlaps.                     | No.                                                                               | Immutable event data, logs, append-only tables, simple pipelines.                                                                 | Lowest. Usually the cheapest and simplest strategy.                                                              |
| `delete+insert`    | Deletes existing matching rows, then inserts replacement rows.                              | Usually scans the incremental batch and the matching portion of the target table that must be deleted.                                         | Yes, indirectly via `unique_key` matching for rows being replaced. Not a full duplicate audit.                             | Yes, by replacing matched rows.                                                   | When rows can change and `merge` is unsupported, unreliable, or problematic.                                                    | Medium to high. More expensive than `append` because it performs two write operations.                         |
| `merge`            | Uses a single `merge` statement to update matched rows and insert unmatched rows.         | Yes. Typically scans the incremental dataset and compares it to existing target rows on `unique_key`. Often the heaviest row-level strategy. | Yes, via `unique_key`. If the key is not truly unique, results may fail or be nondeterministic depending on the warehouse. | Yes.                                                                              | Standard upsert use cases: late-arriving changes, corrected records, mutable fact/dimension tables.                               | Medium to high. Often the most expensive row-level option on large tables.                                       |
| `insert_overwrite` | Replaces whole partitions instead of updating individual rows.                              | Scans and rebuilds the partitions being overwritten. On some adapters, may behave like full-table overwrite.                                   | No row-level duplicate check. It prevents duplicates by replacing entire partitions.                                         | Yes, at partition level.                                                          | Large partitioned time-series tables, especially reload recent N days/months patterns.                                            | Low to medium when only a few partitions are replaced; high if many partitions or the full table is overwritten. |
| `microbatch`       | Processes incremental data in multiple smaller batches, usually using an event-time column. | Scans data in smaller windows or batches instead of one large operation. Exact behavior depends on adapter implementation.                     | Not primarily a duplicate-check strategy by itself. Duplicate handling depends on adapter behavior and configuration.        | Yes, potentially, but in batched or windowed form depending on adapter semantics. | Very large event or time-series tables, backfills, late-arriving data, and workloads where one huge incremental run is too heavy. | Usually medium. Total cost can still be high, but operationally more scalable and reliable for large datasets.   |

##### dbtLabs explanation:

#### Append:

* **Adds** new rows to target table **only**
* Does not check for duplicates
* Does not check for updates
* **Best used for:** Truly immutable event streams
* **SQL used: insert into** to add new rows

#### Merge:

* Updates records that already exist using primary key
* Inserts new records based on primary key
* Runs full table scan (can cause performance issues at scale)
* **Best used for**:
  * Models that are getting new data added, BUT they could also be updating existing records. This is a good way to address the duplicate records issue that something like append doesn't address.
  * Best for tables with a small number of updates each run.
* **SQL Used**: merge into with matching on primary key

#### Delete+insert

* Grabs all selected records, deletes old version of those records if they exist in the target table.
* Inserts new records *and* the new version of the records deleted above based on primary key
* Requires full table scan (unless you configure incremental predicates)
* **Best used for**: Models are getting new data and updates to old rows, but the data platform does not support MERGE.
* **SQL used:** delete from and then insert into with matching on primary key

#### Insert_overwrite

* Replaces entire partitions in a destination table.
* Does not require scanning entire source table–will only scan the partitions you configure.
* **Much more efficient than merge on BigQuery.**
* **Best used for**: Models *that are partitioned* getting new data and updates to old rows, but *merge* is too slow and costly. insert_overwrite is more complex, & most useful on BigQuery.
* **SQL used:**
  * In BigQuery: creates temp table, declares partitions to replace, then merge into.
  * In other databases: DELETE FROM then INSERT INTO

#### Microbatch

* Divides data into atomic, time-bound units (ex: day)
* Splits large models into multiple time-bounded queries: batches! dbt takes those queries and inserts them into your target table.
* **Best used for** :
  * Very large time-series data sets
  * Time series with regular updates.
* **SQL used** :
  * Time-bound SELECT query to construct batch.
  * To insert batch, dbt will use insert/overwrite or delete + insert depending on data platform.
