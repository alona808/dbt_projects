with raw as (
  select
    orderid,
    status,
    amount,
    created,
    _batched_at
  from {{ source('stripe', 'payment') }}
),

transformed as (
  select
    orderid as order_id,
    status as payment_status,
    round(amount / 100.0, 2) as payment_amount,
    created as payment_created_at,
    _batched_at
  from raw
  --where status != 'fail'
)

select * from transformed
