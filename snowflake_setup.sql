USE ROLE ACCOUNTADMIN;
USE DATABASE SNOWFLAKE_LEARNING_DB;
CREATE SCHEMA IF NOT EXISTS DATA;
CREATE STAGE IF NOT EXISTS DATA.DATA_OUTPUT_STAGE
    COMMENT = 'Stage for storing data and outputs';

CREATE NETWORK RULE IF NOT EXISTS SNOWFLAKE_LEARNING_DB.PUBLIC.PYPI_NETWORK_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('pypi.org', 'pypi.python.org', 'pythonhosted.org', 'files.pythonhosted.org');


CREATE NETWORK RULE IF NOT EXISTS SNOWFLAKE_LEARNING_DB.PUBLIC.PLANETARY_COMPUTER_NETWORK_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = (
    -- Primary API endpoints
    'planetarycomputer.microsoft.com',
    'api.planetarycomputer.microsoft.com',
    'planetarycomputer.microsoft.com:443',
    
    -- STAC specification endpoints
    'api.stacspec.org',
    'stacspec.org',
    
    -- Azure Blob Storage (needed for data access)
    'planetarycomputer.blob.core.windows.net',
    'cpdataeuwest.blob.core.windows.net',
    'ai4edataeuwest.blob.core.windows.net',
    'naipeuwest.blob.core.windows.net',
    
    -- Azure Data Lake Storage (for Zarr access)
    'planetarycomputer.dfs.core.windows.net',
    'cpdataeuwest.dfs.core.windows.net',
    
    -- SAS token and authentication endpoints
    '*.blob.core.windows.net',
    '*.dfs.core.windows.net',
    
    -- Microsoft authentication (if needed)
    'login.microsoftonline.com',
    'management.azure.com'
  );

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION DATA_CHALLENGE_EXTERNAL_ACCESS
  ALLOWED_NETWORK_RULES = (
    SNOWFLAKE_LEARNING_DB.PUBLIC.PYPI_NETWORK_RULE,
    SNOWFLAKE_LEARNING_DB.PUBLIC.PLANETARY_COMPUTER_NETWORK_RULE
  )
  ENABLED = TRUE;


-- Verify integration creation
DESCRIBE INTEGRATION DATA_CHALLENGE_EXTERNAL_ACCESS;


-- Create Github Integrations
create or replace api integration notebooks_workspaces
    api_provider = git_https_api
    api_allowed_prefixes = ('https://github.com/ailyninja/notebooks_workspaces_demo_repo')
    enabled = true
    allowed_authentication_secrets = all;


create or replace api integration snowflake_labs
    api_provider = git_https_api
    api_allowed_prefixes = ('https://github.com/Snowflake-Labs')
    enabled = true
    allowed_authentication_secrets = all;



