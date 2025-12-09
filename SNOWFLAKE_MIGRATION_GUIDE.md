# TerraClimate Notebook Migration Guide
## From Local Deployment to Snowflake Notebooks

---

## 📋 Overview

This guide provides step-by-step instructions for migrating the **Demo_TerraClimate** notebook from local deployment to Snowflake Notebooks. The migration addresses Snowflake's architectural constraints while enabling access to PyPI packages through UDFs.

### Key Changes Summary

| Aspect | Local Version | Snowflake Version |
|--------|--------------|-------------------|
| **Data Access** | Direct API calls to Planetary Computer | PyPI-enabled UDFs for external connections |
| **Package Management** | pip install from requirements.txt | Anaconda packages + PyPI via UDFs |
| **Data Processing** | Local pandas/xarray | Snowpark DataFrames + Anaconda packages |
| **Storage** | Local file system (GeoTIFF) | Snowflake stages and tables |
| **Network Access** | Unrestricted | Requires UDFs or external functions |

---

## 🚀 Quick Start

### Prerequisites

1. **Snowflake Account** with appropriate permissions
2. **Role with PyPI Repository Access** (requires ACCOUNTADMIN to grant)
3. **Snowflake Notebook Environment** access
4. **Warehouse** for compute resources

### Files Included

- `snowflake_setup.sql` - Complete SQL setup script with UDFs, infrastructure, and external network access
- `Demo_TerraClimate_Snowflake.ipynb` - Modified notebook for Snowflake
- `SNOWFLAKE_MIGRATION_GUIDE.md` - This comprehensive guide
- `Demo_TerraClimate.ipynb` - Original local notebook (for reference)

---

## 📝 Step-by-Step Migration Process

### Step 1: Grant PyPI Repository Access

**Run as ACCOUNTADMIN:**

```sql
-- Connect as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- Grant PyPI repository access to your role
GRANT DATABASE ROLE SNOWFLAKE.PYPI_REPOSITORY_USER TO ROLE <YOUR_ROLE>;

-- Alternatively, grant to all users:
GRANT DATABASE ROLE SNOWFLAKE.PYPI_REPOSITORY_USER TO ROLE PUBLIC;
```

**Verification:**
```sql
-- Check granted roles
SHOW GRANTS TO ROLE <YOUR_ROLE>;
```

### Step 1b: Configure External Network Access (CRITICAL!)

**⚠️ IMPORTANT:** UDFs that make external API calls require External Access Integration.

**Run as ACCOUNTADMIN:**

```sql
-- Create network rule for Planetary Computer
CREATE OR REPLACE NETWORK RULE planetary_computer_network_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('planetarycomputer.microsoft.com', 'api.stacspec.org', 'stacspec.org');

-- Create external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION planetary_computer_integration
  ALLOWED_NETWORK_RULES = (planetary_computer_network_rule)
  ENABLED = TRUE;

-- Grant usage on integration to your role
GRANT USAGE ON INTEGRATION planetary_computer_integration TO ROLE <YOUR_ROLE>;
```

**Verification:**
```sql
-- Verify integration exists and is enabled
DESCRIBE INTEGRATION planetary_computer_integration;
SHOW INTEGRATIONS;
```

**Note:** Without this step, UDFs cannot make external API calls to Planetary Computer.

### Step 2: Run Setup SQL Script

Execute the `snowflake_setup.sql` script to create:
- Database and schema
- Stages for data storage
- Tables for climate data
- PyPI-enabled UDFs for data access
- Stored procedures for processing

```sql
-- Option 1: Run entire script at once
-- Open snowflake_setup.sql in Snowflake UI and execute

-- Option 2: Run step by step
-- Follow the numbered steps in the SQL file
```

**What Gets Created:**
- ✅ Database: `TERRACLIMATE_DB`
- ✅ Schema: `CLIMATE_DATA`
- ✅ Stage: `TERRACLIMATE_STAGE`
- ✅ Table: `CLIMATE_DATASET`
- ✅ UDF: `get_terraclimate_metadata()`
- ✅ UDF: `get_zarr_asset_info()`
- ✅ UDF: `prepare_terraclimate_access()`
- ✅ Stored Procedure: `process_climate_data()`

### Step 3: Upload Notebook to Snowflake

1. **Open Snowflake UI** → Navigate to **Projects** → **Notebooks**
2. **Click "Import .ipynb file"**
3. **Select** `Demo_TerraClimate_Snowflake.ipynb`
4. **Choose warehouse** (recommended: LARGE or XLARGE for data processing)
5. **Click "Create Notebook"**

### Step 4: Configure Notebook Context

In the first cell of the notebook, verify/set the context:

```python
session.sql("USE DATABASE TERRACLIMATE_DB").collect()
session.sql("USE SCHEMA CLIMATE_DATA").collect()
```

### Step 5: Run the Notebook

Execute cells sequentially to:
1. ✅ Connect to Snowflake session
2. ✅ Access TerraClimate metadata via UDFs
3. ✅ Process sample climate data
4. ✅ Create visualizations
5. ✅ Export results to Snowflake stages

---

## 🔍 Understanding the Changes

### 1. Package Management Differences

#### Original (Local):
```python
# requirements.txt
pystac-client==0.8.5
planetary-computer==1.0.0
xarray==2024.10.0
# ... etc
```

#### Snowflake Approach:

**For Anaconda Packages (directly in notebook):**
```python
import numpy as np        # ✅ Available from Anaconda
import pandas as pd       # ✅ Available from Anaconda
import matplotlib.pyplot  # ✅ Available from Anaconda
```

**For PyPI Packages (via UDFs):**
```sql
CREATE FUNCTION my_function()
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  ARTIFACT_REPOSITORY = snowflake.snowpark.pypi_shared_repository
  PACKAGES = ('pystac-client', 'planetary-computer')
  ...
```

### 2. Data Access Pattern Changes

#### Original (Local):
```python
# Direct API access
catalog = pystac_client.Client.open(
    "https://planetarycomputer.microsoft.com/api/stac/v1",
    modifier=planetary_computer.sign_inplace
)
collection = catalog.get_collection("terraclimate")
```

#### Snowflake (Via UDF):
```python
# Call UDF that handles external API access
metadata_df = session.sql("SELECT get_terraclimate_metadata() as metadata").collect()
metadata = json.loads(metadata_df[0]['METADATA'])
```

**Why?** Snowflake notebooks have restricted network access. UDFs with PyPI packages can make external API calls.

### 3. Data Processing Changes

#### Original (Local):
```python
# Load data directly with xarray
ds = xr.open_dataset(asset.href, **asset.extra_fields["xarray:open_kwargs"])
ds = ds.sel(time=slice("2017-11-01", "2019-11-01"))
```

#### Snowflake:
```python
# Load data into Snowflake table first
snowpark_df = session.create_dataframe(data)
snowpark_df.write.save_as_table("CLIMATE_DATA")

# Process with Snowpark
result = session.table("CLIMATE_DATA").select("TIME", "TMAX").to_pandas()
```

### 4. Output Storage Changes

#### Original (Local):
```python
# Save as local GeoTIFF file
with rasterio.open('TerraClimate_output.tiff', 'w', **kwargs) as dst:
    dst.write(data)
```

#### Snowflake:
```sql
-- Export to Snowflake stage
COPY INTO @TERRACLIMATE_STAGE/summary_results/
FROM CLIMATE_SUMMARY_RESULTS
FILE_FORMAT = (TYPE = PARQUET)
```

---

## 🔧 Troubleshooting

### Issue 1: Network Connection Error (MOST COMMON!)

**Error:**
```
HTTPSConnectionPool(host='planetarycomputer.microsoft.com', port=443): 
Max retries exceeded... Failed to establish a new connection
```

**Root Cause:** UDFs don't have external network access configured, or the network rule is incomplete.

**Solution:**

```sql
-- As ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

CREATE NETWORK RULE planetary_computer_network_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('planetarycomputer.microsoft.com');

CREATE EXTERNAL ACCESS INTEGRATION planetary_computer_integration
  ALLOWED_NETWORK_RULES = (planetary_computer_network_rule)
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION planetary_computer_integration TO ROLE <YOUR_ROLE>;

-- If you already created UDFs, recreate them to pick up the new network config:
DROP FUNCTION IF EXISTS get_terraclimate_metadata();
-- Then run the CREATE OR REPLACE FUNCTION commands from snowflake_setup.sql
```

**Important:** If you update network rules after creating UDFs, you must recreate the UDFs for them to use the updated configuration. UDFs cache their network settings when created.

### Issue 2: PyPI Repository Access Denied

**Error:**
```
Access denied for PYPI_REPOSITORY_USER database role
```

**Solution:**
```sql
-- As ACCOUNTADMIN, grant the role
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.PYPI_REPOSITORY_USER TO ROLE <YOUR_ROLE>;
```

### Issue 3: UDF Creation Fails with Package Error

**Error:**
```
Package 'some-package' cannot be installed
```

**Solution:**
Test locally first:
```bash
pip install <package-name> --only-binary=:all: --python-version 3.11 --platform manylinux2014_x86_64
```

If it works locally but not in Snowflake:
- Check package compatibility with x86 architecture
- Add `RESOURCE_CONSTRAINT=(architecture='x86')` to UDF
- Verify package is available on PyPI

### Issue 4: Network Access Error in Notebook Cells

**Error:**
```
Network access denied
```

**Solution:**
- Move network operations to UDFs
- UDFs can access external APIs, notebook cells cannot directly
- Use UDFs as a bridge for external data access

### Issue 5: Package Not Found in Anaconda

**Error:**
```
ModuleNotFoundError: No module named 'rioxarray'
```

**Solution:**
Check if package is available:
```sql
SELECT * FROM information_schema.packages 
WHERE language = 'python' AND package_name = 'rioxarray';
```

If not available:
- Use PyPI via UDF for that package
- Or upload pure Python package to stage
- Or request package addition via [Snowflake Ideas Forum](https://community.snowflake.com/s/ideas)

### Issue 6: Large Data Processing Slow

**Solution:**
- Use larger warehouse (XLARGE or 2XLARGE)
- Enable Snowpark-optimized warehouse:
```sql
CREATE WAREHOUSE my_warehouse WITH
  WAREHOUSE_SIZE = 'LARGE'
  WAREHOUSE_TYPE = 'SNOWPARK-OPTIMIZED';
```
- Process data in batches
- Use Snowflake's distributed processing capabilities

---

## 📊 Package Compatibility Matrix

### Libraries from Original Notebook

| Package | Status | Source | Notes |
|---------|--------|--------|-------|
| `numpy` | ✅ Available | Anaconda | Direct import in notebook |
| `pandas` | ✅ Available | Anaconda | Direct import in notebook |
| `xarray` | ✅ Available | Anaconda | Direct import in notebook |
| `matplotlib` | ✅ Available | Anaconda | Direct import in notebook |
| `seaborn` | ✅ Available | Anaconda | Direct import in notebook |
| `scikit-learn` | ✅ Available | Anaconda | Direct import in notebook |
| `tqdm` | ✅ Available | Anaconda | Direct import in notebook |
| `rasterio` | ⚠️ Check | Anaconda | May need version verification |
| `rioxarray` | ⚠️ Check | Anaconda/PyPI | May require PyPI via UDF |
| `pystac-client` | ❌ PyPI Only | PyPI | **Must use via UDF** |
| `planetary-computer` | ❌ PyPI Only | PyPI | **Must use via UDF** |
| `fsspec` | ✅ Available | Anaconda | For file system operations |
| `adlfs` | ⚠️ Check | PyPI | Azure Data Lake support |

### Checking Package Availability

```sql
-- Query to check all packages
SELECT package_name, version, language
FROM information_schema.packages
WHERE language = 'python'
AND package_name IN ('numpy', 'pandas', 'xarray', 'matplotlib', 
                      'rasterio', 'rioxarray', 'pystac-client')
ORDER BY package_name;
```

---

## 🎯 Best Practices

### 1. **Separate Concerns**
- Use UDFs for external data access
- Use notebook cells for data processing and visualization
- Store results in Snowflake tables/stages

### 2. **Optimize Performance**
- Use appropriate warehouse size
- Leverage Snowpark for distributed processing
- Cache frequently accessed data in tables

### 3. **Manage Dependencies**
- Keep UDFs focused on specific packages
- Use Anaconda packages directly when possible
- Document PyPI package requirements clearly

### 4. **Handle Data Efficiently**
- Filter data early in the pipeline
- Use table caching for intermediate results
- Export large results to stages

### 5. **Error Handling**
- Wrap UDF code in try-except blocks
- Return meaningful error messages
- Test UDFs independently before notebook integration

---

## 📚 Advanced Topics

### Creating Custom UDFs for Your Use Case

If you need to load actual TerraClimate data:

```sql
CREATE OR REPLACE FUNCTION load_terraclimate_data(
    start_date STRING,
    end_date STRING,
    min_lon FLOAT,
    max_lon FLOAT,
    min_lat FLOAT,
    max_lat FLOAT,
    variables ARRAY
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
ARTIFACT_REPOSITORY = snowflake.snowpark.pypi_shared_repository
PACKAGES = ('xarray', 'fsspec', 'adlfs', 'pystac-client', 'planetary-computer', 'zarr')
HANDLER = 'load_data'
AS $$
import xarray as xr
import pystac_client
import planetary_computer
import json

def load_data(start_date, end_date, min_lon, max_lon, min_lat, max_lat, variables):
    try:
        # Access STAC catalog
        catalog = pystac_client.Client.open(
            "https://planetarycomputer.microsoft.com/api/stac/v1",
            modifier=planetary_computer.sign_inplace
        )
        
        # Get collection and asset
        collection = catalog.get_collection("terraclimate")
        asset = collection.assets["zarr-abfs"]
        
        # Open dataset
        ds = xr.open_dataset(
            asset.href,
            **asset.extra_fields["xarray:open_kwargs"]
        )
        
        # Filter by time and space
        ds = ds.sel(time=slice(start_date, end_date))
        mask_lon = (ds.lon >= min_lon) & (ds.lon <= max_lon)
        mask_lat = (ds.lat >= min_lat) & (ds.lat <= max_lat)
        ds = ds.where(mask_lon & mask_lat, drop=True)
        
        # Select variables
        if variables:
            ds = ds[variables]
        
        # Convert to dictionary format that can be returned as VARIANT
        result = {
            'dims': dict(ds.dims),
            'coords': {k: v.values.tolist() for k, v in ds.coords.items()},
            'data_vars': list(ds.data_vars),
            'attrs': dict(ds.attrs)
        }
        
        return result
        
    except Exception as e:
        return {"error": str(e), "type": type(e).__name__}
$$;
```

### Using Snowpark-Optimized Warehouses

For compute-intensive operations:

```sql
-- Create Snowpark-optimized warehouse
CREATE WAREHOUSE CLIMATE_ANALYTICS_WH WITH
    WAREHOUSE_SIZE = 'LARGE'
    WAREHOUSE_TYPE = 'SNOWPARK-OPTIMIZED'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    RESOURCE_CONSTRAINT = 'MEMORY_16X_X86';

-- Use it in your session
USE WAREHOUSE CLIMATE_ANALYTICS_WH;
```

### Scheduling Notebook Execution

Create a task to run data updates:

```sql
CREATE TASK update_climate_data
    WAREHOUSE = CLIMATE_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0 2 * * * UTC'  -- Daily at 2 AM UTC
AS
CALL process_climate_data('CLIMATE_DATASET', '2017-01-01', '2024-12-31');
```

---

## 🔗 Additional Resources

### Snowflake Documentation
- [Using Third-Party PyPI Packages](https://docs.snowflake.com/en/developer-guide/udf/python/udf-python-packages#get-started)
- [Snowpark Python Developer Guide](https://docs.snowflake.com/en/developer-guide/snowpark/python/index)
- [Snowflake Notebooks](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks)
- [Anaconda Packages in Snowflake](https://docs.snowflake.com/en/developer-guide/udf/python/udf-python-packages#using-third-party-packages-from-anaconda)

### External Resources
- [TerraClimate Dataset](https://planetarycomputer.microsoft.com/dataset/terraclimate)
- [STAC Client Documentation](https://pystac-client.readthedocs.io/)
- [Planetary Computer Hub](https://planetarycomputer.microsoft.com/)

### Getting Help
- [Snowflake Community](https://community.snowflake.com/)
- [Snowflake Support](https://support.snowflake.com/)
- [Snowflake Ideas Forum](https://community.snowflake.com/s/ideas)

---

## ✅ Migration Checklist

Use this checklist to track your migration progress:

- [ ] **Prerequisites**
  - [ ] Snowflake account access confirmed
  - [ ] ACCOUNTADMIN role available (or contact admin)
  - [ ] Warehouse created and accessible

- [ ] **Setup**
  - [ ] PyPI repository role granted
  - [ ] `snowflake_setup.sql` executed successfully
  - [ ] Database and schema created
  - [ ] UDFs created without errors
  - [ ] Stages and tables created

- [ ] **Notebook Migration**
  - [ ] Notebook uploaded to Snowflake
  - [ ] Warehouse assigned to notebook
  - [ ] Context set correctly (database/schema)
  - [ ] All cells execute without errors

- [ ] **Testing**
  - [ ] UDFs return expected data
  - [ ] Visualizations render correctly
  - [ ] Data exports to stages successfully
  - [ ] Performance is acceptable

- [ ] **Optimization**
  - [ ] Warehouse size optimized
  - [ ] Caching strategy implemented
  - [ ] Error handling verified

- [ ] **Documentation**
  - [ ] Team trained on new workflow
  - [ ] Changes documented
  - [ ] Runbook created

---

## 🎓 Learning Path

### For Beginners
1. Start with the basic notebook execution
2. Understand how UDFs work
3. Learn Snowpark DataFrame basics
4. Practice with stages and tables

### For Advanced Users
1. Create custom UDFs for your specific data sources
2. Optimize warehouse configuration
3. Implement scheduled tasks
4. Build production pipelines

---

## 📞 Support

If you encounter issues not covered in this guide:

1. **Check Snowflake Documentation**: Most answers are in the official docs
2. **Search Community Forums**: Others may have faced similar issues
3. **Contact Support**: Snowflake support is very responsive
4. **File Feature Requests**: Use the Ideas forum for missing features

---

## 📝 Changelog

### Version 1.0 (Current)
- Initial migration guide created
- Basic UDFs for TerraClimate access
- Sample data processing workflow
- Export to stages functionality

### Planned Enhancements
- Full xarray data loading via UDFs
- GeoTIFF export functionality
- Advanced spatial processing
- ML integration examples

---

**Last Updated**: November 2025  
**Snowflake Version**: Compatible with current release  
**Python Version**: 3.11 (UDF runtime)

---

*This guide is part of the TerraClimate Snowflake Migration Project*

