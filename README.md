# Data Challenge - Satellite Imagery Analysis

Snowflake notebooks for analyzing Landsat satellite imagery with cloud filtering and vegetation phenology.

**🎯 This workspace uses a shared library architecture** - install packages once, use across all notebooks!

## Requirements

- Snowflake account with **Notebooks in Workspaces** (Preview) enabled
- ACCOUNTADMIN role (for initial setup)
- External Access Integration configured

## Quick Start

### 1. Upload Files to Snowflake Workspace

Upload all files to your Snowflake Workspace:
- All `.ipynb` notebook files
- `requirements.txt`
- All data files (`.csv`, `.pkl`)

### 2. Configure External Access Integration

**Must be done by admin (ACCOUNTADMIN role):**

Run in a Snowflake SQL worksheet:

```sql
-- See snowflake_setup.sql for complete setup including PyPI and Planetary Computer access
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION pypi_planetary_access
  ALLOWED_NETWORK_RULES = (pypi_network_rule, planetary_computer_network_rule)
  ENABLED = TRUE;
```

Configure this integration at the **workspace/service level** (not per-notebook).

### 3. Run Setup Notebook (REQUIRED)

**📝 IMPORTANT: Run this first, and after every service restart!**

```
Open: SETUP_NOTEBOOK.ipynb
Run: All Cells
Wait: 5-10 minutes for package installation
Verify: All packages show ✓ in verification output
```

This installs all packages from `requirements.txt` to a shared directory.

### 4. Run Any Notebook

All notebooks are pre-configured to use the shared library directory:
- `GETTING_STARTED_NOTEBOOK.ipynb` - Introduction to Snowflake Notebooks
- `GETTING_STARTED_DATA_CHALLENGE.ipynb` - Data challenge overview
- `Demo_TerraClimate.ipynb` - TerraClimate climate data
- `Demo_Landsat_Viewer.ipynb` - Landsat satellite imagery
- `Biodiversity_Challenge_Benchmark.ipynb` - Biodiversity analysis

Just open and run - no package installation needed!

### 5. After Service Restarts

⚠️ **The `/workspace` directory is NOT persistent!** Packages are lost when the service restarts.

**When to re-run setup:**
- After weekend maintenance
- After idle timeout (default 1 hour)
- After 7 days (mandatory maintenance)
- If you see `ModuleNotFoundError`

**Solution:** Re-run `SETUP_NOTEBOOK.ipynb` (takes 5-10 minutes)

## 📁 Files

### Setup & Documentation
| File | Description |
|------|-------------|
| `SETUP_NOTEBOOK.ipynb` | **⚠️ RUN THIS FIRST!** Installs all packages to shared directory |
| `requirements.txt` | All required Python packages |
| `snowflake_setup.sql` | SQL setup for External Access Integration |
| `README.md` | This file - getting started guide |
| `QUICK_REFERENCE.md` | **Quick reference guide** - print this! |
| `SHARED_LIBRARY_ARCHITECTURE.md` | Complete architecture documentation |
| `WORKSPACE_PERSISTENCE_EXPLAINED.md` | Technical deep-dive on persistence |
| `SNOWFLAKE_MIGRATION_GUIDE.md` | Migration guide for Snowflake |

### Demo Notebooks (Pre-configured)
| File | Description |
|------|-------------|
| `GETTING_STARTED_NOTEBOOK.ipynb` | Introduction to Snowflake Notebooks |
| `GETTING_STARTED_DATA_CHALLENGE.ipynb` | Data challenge getting started |
| `Demo_TerraClimate.ipynb` | TerraClimate dataset demonstration |
| `Demo_TerraClimate_Snowflake.ipynb` | TerraClimate optimized for Snowflake |
| `Demo_Landsat_Viewer.ipynb` | Landsat satellite imagery viewer |
| `Landsat_Demo_Snowflake.ipynb` | Landsat demo for Snowflake |
| `SNOWFLAKE_DEMO_LANDSAT_VIEWER.ipynb` | Landsat viewer for Snowflake Workspaces |
| `Biodiversity_Challenge_Benchmark.ipynb` | Biodiversity data challenge |

### Data Files
| File | Description |
|------|-------------|
| `Training_Data.csv` | Training dataset |
| `Validation_Template.csv` | Validation template |
| `water_quality_training_dataset_100.csv` | Water quality training data |
| `regression_pipeline.pkl` | Saved regression model pipeline |

## 📚 Documentation

**Start here:**
1. **README.md** (this file) - Basic getting started
2. **QUICK_REFERENCE.md** - Daily workflow and troubleshooting
3. **SHARED_LIBRARY_ARCHITECTURE.md** - Full architecture explanation
4. **WORKSPACE_PERSISTENCE_EXPLAINED.md** - Why packages don't persist

## 🏗️ Architecture: Shared Library Approach

Instead of each notebook installing packages separately, we use a **shared library directory**:

```
/workspace/site-packages_shared/
```

**Benefits:**
- ✅ Install once, use across all notebooks
- ✅ Faster notebook startup
- ✅ Consistent package versions
- ✅ Reduced storage usage

**Trade-offs:**
- ⚠️ Must re-run setup after service restarts
- ⚠️ No per-notebook environment isolation

**Why this approach?**  
Familiar workflow for teams accustomed to shared virtual environments. Significantly faster during active development.

## ⚠️ Critical: Non-Persistent Storage

**THE `/workspace` DIRECTORY IS NOT PERSISTENT!**

From [Snowflake Documentation](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-filesystem):

> "Files created in code or from the terminal exist only for the duration of the current notebook service session. When the notebook service is suspended, these files are removed."

**This means:**
- Packages installed via `pip` are deleted on service restart
- Must re-run `SETUP_NOTEBOOK.ipynb` after restarts
- Service restarts happen: weekends, idle timeout, 7-day limit

**For detailed explanation:** See [WORKSPACE_PERSISTENCE_EXPLAINED.md](./WORKSPACE_PERSISTENCE_EXPLAINED.md)

## 🛠️ Troubleshooting

### Problem: `ModuleNotFoundError: No module named 'package_name'`
**Solution:** Re-run `SETUP_NOTEBOOK.ipynb` - service likely restarted

### Problem: Package installation fails in setup
**Error:** `Could not fetch URL https://pypi.org/...`  
**Solution:** Verify External Access Integration is configured at workspace level

### Problem: Setup takes > 15 minutes
**Cause:** Large dependency tree, normal for first install  
**Solution:** Be patient, subsequent installs are faster

### Problem: "Could not find a Chunk Manager" error
**Solution:** Add `import dask` and `import dask.array as da` before chunked operations

### Problem: Import errors after weekend
**Cause:** Weekend maintenance restarted service  
**Solution:** Re-run `SETUP_NOTEBOOK.ipynb` every Monday morning

## 💡 Best Practices

1. **Monday morning routine:** Re-run `SETUP_NOTEBOOK.ipynb` to restore packages after weekend
2. **Check before starting:** Try importing a package to verify setup
3. **Team communication:** Share setup status with teammates
4. **Increase idle timeout:** Settings → 72 hours max (reduces restart frequency)
5. **Read the docs:** See `QUICK_REFERENCE.md` for daily workflow

## 🎯 Workflow Summary

```
First Time:
  1. Upload all files to Snowflake Workspace
  2. Configure External Access Integration (admin)
  3. Run SETUP_NOTEBOOK.ipynb (5-10 min)
  4. Run any other notebook - works immediately!

After Service Restart:
  1. Notice import errors in notebooks
  2. Re-run SETUP_NOTEBOOK.ipynb (5-10 min)
  3. Continue working

Daily Work:
  - Just open and run notebooks
  - No package installation needed (unless restart occurred)
  - All notebooks share same environment
```

## 📖 Additional Resources

- [Snowflake Notebooks in Workspaces](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-on-spcs)
- [Working with the file system](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-filesystem)
- [Managing packages](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-manage-packages)
- [External Access Integration](https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-overview)

---

**Version:** 1.0  
**Last Updated:** December 22, 2025  
**Snowflake:** Notebooks in Workspaces (Preview)
