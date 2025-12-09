-- ============================================================================
-- Snowflake Setup Planetary Computer
-- ============================================================================
-- This script creates external network access to install PyPI packages
-- and access Planetary Computer API endpoints. 
-- Note that network rules are stored in a database, while network policies 
-- are account-level objects that do not require a database. You can attach many
-- rules to the same policy.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE DATA_CHALLENGE;
CREATE SCHEMA DATA_CHALLENGE.CORE_POLICY;
USE SCHEMA DATA_CHALLENGE.CORE_POLICY;

CREATE  NETWORK RULE if not exists DATA_CHALLENGE.CORE_POLICY.PLANETARY_COMPUTER_NETWORK_RULE
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


-- -- Verify network rule creation
SHOW NETWORK RULES LIKE 'planetary_computer%';
DESCRIBE NETWORK RULE PLANETARY_COMPUTER_NETWORK_RULE;


CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION DATA_CHALLENGE_EXTERNAL_ACCESS;
  ALLOWED_NETWORK_RULES = (
    snowflake.external_access.pypi_rule, 
    DATA_CHALLENGE.CORE_POLICY.PLANETARY_COMPUTER_NETWORK_RULE)
  ENABLED = TRUE;

-- Verify integration creation
DESCRIBE INTEGRATION DATA_CHALLENGE_EXTERNAL_ACCESS;



-- Create Stage for Data Storage
-- ============================================================================
CREATE SCHEMA DATA;
CREATE STAGE IF NOT EXISTS DATA_CHALLENGE.DATA.TERRACLIMATE_STAGE
    COMMENT = 'Stage for storing TerraClimate data and outputs';

