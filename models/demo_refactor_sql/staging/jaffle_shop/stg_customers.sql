with raw as (
  select
    id,
    first_name,
    last_name
  from {{ source('jaffle_shop', 'customers') }}
),

transformed as (
  select
    id,
    first_name,
    last_name,
    first_name || ' ' || last_name as full_name
  from raw
)

select * from transformed