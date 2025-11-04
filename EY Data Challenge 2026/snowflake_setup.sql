-- ============================================================================
-- Snowflake Setup for TerraClimate Notebook
-- ============================================================================
-- This script sets up the necessary infrastructure for running the 
-- TerraClimate notebook in Snowflake, including PyPI-enabled UDFs with
-- external network access to Planetary Computer API
-- ============================================================================

-- IMPORTANT: Steps 1-3 MUST be run as ACCOUNTADMIN
-- Steps 4 onward can be run with SYSADMIN or appropriate role
-- ============================================================================

-- Step 1: Grant PyPI Repository Access (Run as ACCOUNTADMIN)
-- ============================================================================
USE ROLE ACCOUNTADMIN;

-- Grant PyPI repository access (replace SYSADMIN with your role if different)
GRANT DATABASE ROLE SNOWFLAKE.PYPI_REPOSITORY_USER TO ROLE SYSADMIN;
-- Or grant to all users:
-- GRANT DATABASE ROLE SNOWFLAKE.PYPI_REPOSITORY_USER TO ROLE PUBLIC;

-- Step 2: Create Network Rule for External API Access (ACCOUNTADMIN)
-- ============================================================================
-- This allows UDFs to connect to Planetary Computer and Azure services
CREATE OR REPLACE NETWORK RULE planetary_computer_network_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = (
    -- Planetary Computer API endpoints
    'planetarycomputer.microsoft.com',
    'api.planetarycomputer.microsoft.com',
    
    -- STAC specification endpoints
    'api.stacspec.org',
    'stacspec.org',
    
    -- Azure Blob Storage (required for planetary-computer library)
    '*.blob.core.windows.net',
    
    -- Azure Data Lake Storage (required for Zarr data access)
    '*.dfs.core.windows.net',
    
    -- Microsoft authentication endpoints
    'login.microsoftonline.com',
    'management.azure.com'
  );

-- Verify network rule creation
DESCRIBE NETWORK RULE planetary_computer_network_rule;

-- Step 3: Create External Access Integration (ACCOUNTADMIN)
-- ============================================================================
-- This integration enables UDFs to make external network calls
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION planetary_computer_integration
  ALLOWED_NETWORK_RULES = (planetary_computer_network_rule)
  ENABLED = TRUE;

-- Verify integration creation
DESCRIBE INTEGRATION planetary_computer_integration;

-- Grant usage on integration to roles that will use the UDFs
GRANT USAGE ON INTEGRATION planetary_computer_integration TO ROLE SYSADMIN;
-- Add other roles as needed:
-- GRANT USAGE ON INTEGRATION planetary_computer_integration TO ROLE <YOUR_ROLE>;

-- Step 4: Switch to Working Role and Create Database
-- ============================================================================
-- Now you can switch to your regular role (SYSADMIN or your custom role)
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS TERRACLIMATE_DB;
USE DATABASE TERRACLIMATE_DB;
CREATE SCHEMA IF NOT EXISTS CLIMATE_DATA;
USE SCHEMA CLIMATE_DATA;

-- Step 5: Create Stage for Data Storage
-- ============================================================================
CREATE STAGE IF NOT EXISTS TERRACLIMATE_STAGE
    COMMENT = 'Stage for storing TerraClimate data and outputs';

-- Step 6: Create Table for Storing Climate Data
-- ============================================================================
CREATE TABLE IF NOT EXISTS CLIMATE_DATASET (
    dataset_id VARCHAR(100),
    time_period VARCHAR(50),
    latitude FLOAT,
    longitude FLOAT,
    variable_name VARCHAR(50),
    variable_value FLOAT,
    load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Step 7: Create UDF to Fetch TerraClimate Metadata
-- ============================================================================
-- This UDF connects to Planetary Computer and retrieves collection metadata
CREATE OR REPLACE FUNCTION get_terraclimate_metadata()
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
ARTIFACT_REPOSITORY = snowflake.snowpark.pypi_shared_repository
PACKAGES = ('pystac-client==0.8.5', 'planetary-computer==1.0.0', 'requests==2.31.0')
EXTERNAL_ACCESS_INTEGRATIONS = (planetary_computer_integration)
HANDLER = 'fetch_metadata'
AS $$
import pystac_client
import planetary_computer
import json
import traceback

def fetch_metadata():
    """Fetch TerraClimate collection metadata from Planetary Computer"""
    try:
        # Access STAC catalog with planetary computer signing
        catalog = pystac_client.Client.open(
            "https://planetarycomputer.microsoft.com/api/stac/v1",
            modifier=planetary_computer.sign_inplace
        )
        
        # Get collection information
        collection = catalog.get_collection("terraclimate")
        
        # Extract relevant metadata
        metadata = {
            "id": collection.id,
            "title": collection.title,
            "description": collection.description,
            "license": collection.license,
            "spatial_extent": collection.extent.spatial.bboxes[0] if collection.extent.spatial.bboxes else None,
            "temporal_extent": [
                str(collection.extent.temporal.intervals[0][0]) if collection.extent.temporal.intervals[0][0] else None,
                str(collection.extent.temporal.intervals[0][1]) if collection.extent.temporal.intervals[0][1] else None
            ] if collection.extent.temporal.intervals else None,
            "assets": list(collection.assets.keys()),
            "status": "success"
        }
        
        return metadata
        
    except Exception as e:
        return {
            "error": str(e),
            "error_type": type(e).__name__,
            "traceback": traceback.format_exc()
        }
$$;

-- Step 8: Create UDF to Get Zarr Asset Information
-- ============================================================================
CREATE OR REPLACE FUNCTION get_zarr_asset_info()
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
ARTIFACT_REPOSITORY = snowflake.snowpark.pypi_shared_repository
PACKAGES = ('pystac-client==0.8.5', 'planetary-computer==1.0.0', 'requests==2.31.0')
EXTERNAL_ACCESS_INTEGRATIONS = (planetary_computer_integration)
HANDLER = 'get_asset_info'
AS $$
import pystac_client
import planetary_computer
import traceback

def get_asset_info():
    """Get Zarr asset information for accessing the dataset"""
    try:
        catalog = pystac_client.Client.open(
            "https://planetarycomputer.microsoft.com/api/stac/v1",
            modifier=planetary_computer.sign_inplace
        )
        
        collection = catalog.get_collection("terraclimate")
        asset = collection.assets.get("zarr-abfs")
        
        if asset:
            return {
                "href": asset.href,
                "title": asset.title if hasattr(asset, 'title') else None,
                "description": asset.description if hasattr(asset, 'description') else None,
                "extra_fields": asset.extra_fields if hasattr(asset, 'extra_fields') else {},
                "status": "success"
            }
        else:
            return {"error": "zarr-abfs asset not found"}
            
    except Exception as e:
        return {
            "error": str(e),
            "error_type": type(e).__name__,
            "traceback": traceback.format_exc()
        }
$$;

-- Step 9: Create UDF for Data Access Preparation
-- ============================================================================
-- This UDF prepares parameters for accessing TerraClimate data
CREATE OR REPLACE FUNCTION prepare_terraclimate_access(
    start_date STRING,
    end_date STRING,
    min_lon FLOAT,
    max_lon FLOAT,
    min_lat FLOAT,
    max_lat FLOAT
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
ARTIFACT_REPOSITORY = snowflake.snowpark.pypi_shared_repository
PACKAGES = ('pystac-client==0.8.5', 'planetary-computer==1.0.0', 'requests==2.31.0')
EXTERNAL_ACCESS_INTEGRATIONS = (planetary_computer_integration)
HANDLER = 'prepare_access'
AS $$
import pystac_client
import planetary_computer
import traceback

def prepare_access(start_date, end_date, min_lon, max_lon, min_lat, max_lat):
    """
    Prepare TerraClimate data access parameters
    Returns the necessary information to access the dataset
    """
    try:
        catalog = pystac_client.Client.open(
            "https://planetarycomputer.microsoft.com/api/stac/v1",
            modifier=planetary_computer.sign_inplace
        )
        
        collection = catalog.get_collection("terraclimate")
        asset = collection.assets["zarr-abfs"]
        
        return {
            "data_url": asset.href,
            "time_range": {"start": start_date, "end": end_date},
            "spatial_bounds": {
                "min_lon": min_lon,
                "max_lon": max_lon,
                "min_lat": min_lat,
                "max_lat": max_lat
            },
            "open_kwargs": asset.extra_fields.get("xarray:open_kwargs", {}),
            "status": "ready"
        }
        
    except Exception as e:
        return {
            "error": str(e),
            "error_type": type(e).__name__,
            "traceback": traceback.format_exc()
        }
$$;

-- Step 10: Create Stored Procedure for Data Processing
-- ============================================================================
-- This procedure can be used to process data using Snowpark
CREATE OR REPLACE PROCEDURE process_climate_data(
    table_name STRING,
    start_date STRING,
    end_date STRING
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'process_data'
AS $$
def process_data(session, table_name, start_date, end_date):
    """
    Process climate data stored in a Snowflake table
    """
    try:
        # Example processing - calculate statistics
        query = f"""
            SELECT 
                variable_name,
                AVG(variable_value) as avg_value,
                MIN(variable_value) as min_value,
                MAX(variable_value) as max_value,
                COUNT(*) as record_count
            FROM {table_name}
            WHERE time_period BETWEEN '{start_date}' AND '{end_date}'
            GROUP BY variable_name
        """
        
        result = session.sql(query).collect()
        return f"Processed {len(result)} variables successfully"
    except Exception as e:
        return f"Error: {str(e)}"
$$;

-- Step 11: Verify Setup
-- ============================================================================
-- Test the metadata function
SELECT get_terraclimate_metadata() as metadata;

-- Test the asset info function
SELECT get_zarr_asset_info() as asset_info;

-- Test the access preparation function
SELECT prepare_terraclimate_access(
    '2017-11-01', 
    '2019-11-01', 
    139.94, 
    151.48, 
    -39.74, 
    -30.92
) as access_info;

-- ============================================================================
-- Setup Complete!
-- ============================================================================
-- If all tests above return JSON without errors, your setup is successful!
--
-- Next steps:
-- 1. Open the Demo_TerraClimate_Snowflake.ipynb notebook in Snowflake
-- 2. The notebook will automatically connect to this database
-- 3. Run the notebook cells sequentially
-- 4. Enjoy your TerraClimate data analysis!
-- ============================================================================

-- Troubleshooting: If you encounter errors
-- ============================================================================
-- 1. Verify network rule exists:
--    SHOW NETWORK RULES;
--
-- 2. Verify integration exists and is enabled:
--    SHOW INTEGRATIONS;
--    DESCRIBE INTEGRATION planetary_computer_integration;
--
-- 3. Verify your role has necessary grants:
--    SHOW GRANTS TO ROLE SYSADMIN;  -- or your role
--
-- 4. If you update network rules, recreate the UDFs to pick up changes:
--    DROP FUNCTION get_terraclimate_metadata();
--    -- Then recreate using CREATE OR REPLACE FUNCTION commands above
-- ============================================================================
