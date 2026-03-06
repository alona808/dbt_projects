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
    order_date as order_placed_at,
    status as order_status,

    row_number() over (
      partition by user_id
      order by order_date, id
    ) as user_order_seq,

    case
        when status not in ('returned','return_pending')
        then order_date
    end as valid_order_date,
    _etl_loaded_at

  from raw
)

select * from transformed

