"""Sample functions for the 'Azure SQL, Locked Down' demo.

Two HTTP triggers, both reading Azure SQL through the SQL input binding:

  whoami   - who the database thinks is connecting, and from which address.
             The address is the proof: a 10.60.x.x address means the query
             came in through the private endpoint, not the public gateway.
  products - five rows of AdventureWorksLT, so there is real data on screen.

There is no password, key or token in this file or in the app settings. The
binding's connection string names a server and says "use my managed identity";
Entra ID does the rest. The SQL runs in the Functions host (.NET SqlClient),
so there is no ODBC driver to install either.
"""

import json

import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

WHOAMI_SQL = """
SELECT
    SUSER_SNAME()                                                           AS login_name,
    USER_NAME()                                                             AS database_user,
    CAST(CONNECTIONPROPERTY('client_net_address') AS varchar(48))           AS client_address,
    DB_NAME()                                                               AS database_name,
    CAST(DATABASEPROPERTYEX(DB_NAME(), 'ServiceObjective') AS varchar(48))  AS service_objective
"""

PRODUCTS_SQL = """
SELECT TOP (5)
    p.ProductID,
    p.Name,
    c.Name AS Category,
    p.ListPrice
FROM SalesLT.Product AS p
JOIN SalesLT.ProductCategory AS c ON c.ProductCategoryID = p.ProductCategoryID
ORDER BY p.ListPrice DESC
"""


def _json_response(rows: func.SqlRowList) -> func.HttpResponse:
    payload = [json.loads(row.to_json()) for row in rows]
    return func.HttpResponse(
        json.dumps(payload, indent=2),
        mimetype="application/json",
        status_code=200,
    )


@app.route(route="whoami", methods=["GET"])
@app.sql_input(
    arg_name="rows",
    command_text=WHOAMI_SQL,
    command_type="Text",
    connection_string_setting="SqlConnectionString",
)
def whoami(req: func.HttpRequest, rows: func.SqlRowList) -> func.HttpResponse:
    """Identity and network path, as SQL Server sees them."""
    return _json_response(rows)


@app.route(route="products", methods=["GET"])
@app.sql_input(
    arg_name="rows",
    command_text=PRODUCTS_SQL,
    command_type="Text",
    connection_string_setting="SqlConnectionString",
)
def products(req: func.HttpRequest, rows: func.SqlRowList) -> func.HttpResponse:
    """The five most expensive products. Needs db_datareader — whoami doesn't."""
    return _json_response(rows)
