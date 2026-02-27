import holidays
import pandas as pd

# all python models need to be defined at the start with this specific syntax
def model(dbt, session):

# Python models don't use Jinja. Here we are using dbt.config to create model configuration.
# Be sure to materialize python models as a tables, and specify the packages that were imported above.
    dbt.config(
        materialized="table",
        packages=["holidays", "pandas"]
    )

    #il_holidays = holidays.IL(years=[2026])
    il_holidays = holidays.country_holidays('IL', year=2026)

# Python models don't use Jinja. Here we are using dbt.ref to create model references.
    df = dbt.ref('date_spine').to_pandas()

# If you are using snowspark, columns need to be UPPERCASE.
    df['IS_HOLIDAY'] = df['DATE'].apply(lambda x: x in il_holidays)

    return df