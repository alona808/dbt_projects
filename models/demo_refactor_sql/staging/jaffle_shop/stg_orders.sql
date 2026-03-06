with raw as (
  select
    id,
    user_id,
    order_date,
    status,
    _etl_loaded_at
  from {{ source('jaffle_shop', 'orders') }}
),

transformed as (
  select
    id as order_id,
    user_id as customer_id,
    order_date,
    status as order_status,
    row_number() over (
      partition by user_id
      order by order_date, id
    ) as user_order_seq,
    _etl_loaded_at
  from raw
)

select * from transformed

