with raw as (
  select
    orderid,
    status,
    amount
  from {{ source('stripe', 'payment') }}
),

transformed as (
  select
    orderid as order_id,
    status as payment_status,
    round(amount / 100.0, 2) as payment_amount
  from raw
  where status != 'fail'
)

select * from transformed
