# TerraClimate Snowflake Migration

This repository contains a Snowflake-compatible version of the TerraClimate demonstration notebook.

## 📁 Files

### Setup and Configuration
- **`snowflake_setup.sql`** - Complete setup script that creates database, tables, network rules, external access integration, and UDFs with proper PyPI and network access configuration

### Notebooks
- **`Demo_TerraClimate_Snowflake.ipynb`** - Snowflake-compatible notebook using Snowpark and Anaconda packages
- **`Demo_TerraClimate.ipynb`** - Original local notebook (for reference)

### Documentation
- **`SNOWFLAKE_MIGRATION_GUIDE.md`** - Comprehensive migration guide with step-by-step instructions, troubleshooting, and best practices
- **`requirements.txt`** - Python dependencies for local development

## 🚀 Quick Start

### Prerequisites
- Snowflake account with ACCOUNTADMIN access (for initial setup)
- Snowflake Notebook environment

### Setup Steps

1. **Run Setup Script** (as ACCOUNTADMIN)
   ```sql
   -- Execute snowflake_setup.sql in Snowflake
   -- This creates all necessary infrastructure and UDFs
   ```

2. **Upload Notebook**
   - Go to Snowflake UI → Projects → Notebooks
   - Import `Demo_TerraClimate_Snowflake.ipynb`
   - Select a warehouse

3. **Run Notebook**
   - Execute cells sequentially
   - The notebook will call the UDFs and process TerraClimate data

## 🔑 Key Changes from Local Version

| Aspect | Local | Snowflake |
|--------|-------|-----------|
| **Data Access** | Direct API calls | PyPI-enabled UDFs with External Access Integration |
| **Packages** | pip install from requirements.txt | Anaconda packages + PyPI via UDFs |
| **Processing** | Local pandas/xarray | Snowpark DataFrames |
| **Storage** | Local files (GeoTIFF) | Snowflake stages and tables |
| **Network** | Unrestricted | Controlled via network rules and integrations |

## 📚 What's Configured

The `snowflake_setup.sql` script sets up:

1. **PyPI Repository Access** - Allows UDFs to use packages from PyPI
2. **Network Rules** - Defines allowed external endpoints:
   - Planetary Computer API (`planetarycomputer.microsoft.com`)
   - Azure Blob Storage (`*.blob.core.windows.net`)
   - Azure Data Lake (`*.dfs.core.windows.net`)
   - Microsoft authentication endpoints
3. **External Access Integration** - Enables UDFs to make network calls
4. **Database and Schema** - `TERRACLIMATE_DB.CLIMATE_DATA`
5. **UDFs** - Three functions for accessing TerraClimate metadata and data
6. **Stored Procedure** - For data processing with Snowpark

## ⚠️ Important Notes

### Network Access
UDFs require External Access Integration to call external APIs. The setup script creates:
- Network rules defining allowed endpoints
- External Access Integration enabling the access
- UDFs configured to use the integration

### Package Management
- **Anaconda packages** (numpy, pandas, matplotlib) - Import directly in notebook cells
- **PyPI packages** (pystac-client, planetary-computer) - Only available via UDFs

### Function Recreation
If you update network rules after creating UDFs, you must recreate the UDFs:
```sql
DROP FUNCTION IF EXISTS get_terraclimate_metadata();
-- Then recreate using CREATE OR REPLACE FUNCTION...
```

UDFs cache their configuration when created, so changes to network rules won't apply to existing functions.

## 📖 Documentation

See `SNOWFLAKE_MIGRATION_GUIDE.md` for:
- Detailed migration steps
- Architecture explanations
- Package compatibility matrix
- Troubleshooting guide
- Best practices
- Advanced topics

## ✅ Verification

After running the setup script, verify everything works:

```sql
-- All three should return JSON without errors
SELECT get_terraclimate_metadata();
SELECT get_zarr_asset_info();
SELECT prepare_terraclimate_access('2017-11-01', '2019-11-01', 139.94, 151.48, -39.74, -30.92);
```

## 🆘 Troubleshooting

### Issue: Network connection errors

**Symptoms:**
- UDFs fail with "Failed to establish a new connection"
- Test functions work but main functions fail

**Solutions:**
1. Verify network rule includes all Azure endpoints (see `snowflake_setup.sql`)
2. Verify External Access Integration exists and is enabled
3. Recreate UDFs if you updated network rules after creating them
4. Check that your role has USAGE on the integration

See the troubleshooting section in `SNOWFLAKE_MIGRATION_GUIDE.md` for detailed solutions.

## 🎯 Success Criteria

You're ready to use the notebook when:
- ✅ `get_terraclimate_metadata()` returns collection metadata
- ✅ `get_zarr_asset_info()` returns Zarr asset information  
- ✅ No network connection errors
- ✅ Notebook cells execute successfully

## 📊 Data Flow

```
Snowflake Notebook
    ↓
Snowpark (for data manipulation)
    ↓
Anaconda Packages (numpy, pandas, matplotlib)
    ↓
PyPI-Enabled UDFs
    ↓
External Access Integration → Network Rules
    ↓
Planetary Computer API → TerraClimate Data
```

## 🎓 Key Learnings

1. **Two separate security features**: PyPI access ≠ Network access
2. **External Access Integration**: Required for UDFs to make API calls
3. **Network rules**: Must include all endpoints the libraries need
4. **Function caching**: Recreate UDFs after infrastructure changes
5. **Wildcard patterns**: Use `*.blob.core.windows.net` for Azure services

---

**For detailed information, see `SNOWFLAKE_MIGRATION_GUIDE.md`**

