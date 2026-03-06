-- Import staging models

with customers as (

  select * from {{ ref('stg_customers') }}

),

orders as (
  select * from {{ ref('stg_orders') }}
),

payments as (

  select * from {{ ref('stg_payments') }}

),


-- Marts models
customer_order_history as (
  select
    c.id as customer_id,
    c.full_name,
    min(o.order_date) as first_order_date,
    min(
      case
        when o.order_status not in ('returned', 'returned_pending') then o.order_date
      end
    ) as first_non_returned_order_date,
    max(
      case
        when o.order_status not in ('returned', 'returned_pending') then o.order_date
      end
    ) as last_most_recent_non_returned_order_date,
    coalesce(max(o.user_order_seq), 0) as order_count,
    count(
      case
        when o.order_status != 'returned' then 1
      end
    ) as non_returned_order_count,
    round(
      sum(
        case
          when o.order_status not in ('returned', 'returned_pending')
          then p.payment_amount
          else 0
        end
      ),
      2
    ) as total_lifetime_value,
    round(
      (
        sum(
          case
            when o.order_status not in ('returned', 'returned_pending')
            then p.payment_amount
            else 0
          end
        )
      ) / nullif(
        count(
          case
            when o.order_status not in ('returned', 'returned_pending') then 1
          end
        ),
        0
      ),
      2
    ) as avg_non_returned_value,
    array_agg(distinct o.order_id order by o.order_id) as order_ids
  from orders as o
  join customers as c
    on o.customer_id = c.id
  join payments as p
    on o.order_id = p.order_id
  where o.order_status != 'pending'
  group by c.id, c.full_name
),

final as (
  select
    o.order_id,
    o.customer_id,
    c.full_name,
    coh.first_order_date,
    coh.order_count,
    coh.total_lifetime_value,
    round(p.payment_amount, 2) as order_value_dollars,
    o.order_status,
    p.payment_status
  from orders as o

  join customers as c
    on o.customer_id = c.id

  join customer_order_history as coh
    on o.customer_id = coh.customer_id

  left join payments as p
    on o.order_id = p.order_id
)

select
  order_id,
  customer_id,
  full_name,
  first_order_date,
  order_count,
  total_lifetime_value,
  order_value_dollars,
  order_status,
  payment_status
from final


