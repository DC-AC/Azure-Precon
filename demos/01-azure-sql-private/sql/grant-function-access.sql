-- Demo 01 — give the function app's managed identity a database user.
--
-- Run as the server's Entra admin, against the demo database (not master),
-- while public access is still on. The grant_command output does this:
--
--   eval "$(terraform output -raw grant_command)"
--
-- Authentication is not authorization. Entra ID can already prove who the
-- function is; until this runs, the database has no idea what it may do.

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$(FunctionIdentity)')
    CREATE USER [$(FunctionIdentity)] FROM EXTERNAL PROVIDER;

ALTER ROLE db_datareader ADD MEMBER [$(FunctionIdentity)];

SELECT name, type_desc, authentication_type_desc
FROM sys.database_principals
WHERE name = N'$(FunctionIdentity)';
