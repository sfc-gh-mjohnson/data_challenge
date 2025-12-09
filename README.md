# Data Challenge - Satellite Imagery Analysis

Snowflake notebooks for analyzing Landsat satellite imagery with cloud filtering and vegetation phenology.

## Requirements

- Snowflake account with Container Runtime enabled
- ACCOUNTADMIN role (for initial setup)

## Quick Start

### 1. Create External Access Integration

Run in a Snowflake SQL worksheet:

```sql
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION pypi_access
  ALLOWED_NETWORK_RULES = (snowflake.external_access.pypi_rule)
  ENABLED = TRUE;
```

### 2. Create a Notebook with Container Runtime

1. Go to **Projects → Notebooks** in Snowflake
2. Click **+ Notebook** → **Import .ipynb file**
3. Upload `Landsat_Demo_Snowflake.ipynb`
4. **Important:** Select **Container Runtime** (not Warehouse Runtime)
5. Attach the `pypi_access` integration to the notebook

### 3. Install Dependencies

In the first cell of your notebook, run:

```python
!pip install -r requirements.txt
```

Or install packages directly:

```python
!pip install pystac-client planetary-computer odc-stac dask xarray matplotlib
```

### 4. Run the Notebook

Execute cells sequentially. The notebook will:
- Connect to Microsoft Planetary Computer
- Load Landsat imagery for your area of interest
- Apply cloud masking
- Calculate NDVI vegetation index
- Generate visualizations

## Files

| File | Description |
|------|-------------|
| `Landsat_Demo_Snowflake.ipynb` | Main notebook for Snowflake Container Runtime |
| `Demo_Landsat_Viewer.ipynb` | Local/Jupyter version |
| `requirements.txt` | Python dependencies |
| `snowflake_setup.sql` | Additional network rules (if needed) |

## Why Container Runtime?

Container Runtime allows `pip install` for any PyPI package. This is required for geospatial packages like `odc-stac` and `planetary-computer` that aren't available in Snowflake's Anaconda channel.

## Troubleshooting

**"Could not find a Chunk Manager" error**
- Add `import dask` and `import dask.array as da` before using chunked operations

**Network/connection errors**
- Verify the external access integration is attached to your notebook
- Check that Container Runtime is selected (not Warehouse Runtime)

**Package not found**
- Run `!pip install <package>` in a notebook cell
- Ensure you're using Container Runtime
