# Shared Library Architecture for Snowflake Workspaces

## Overview

This workspace is configured to use a **shared Python package directory** across all notebooks, allowing your team to install packages once and use them everywhere. This document explains the architecture, benefits, risks, and usage instructions.

## 📚 Related Documentation

- **[WORKSPACE_PERSISTENCE_EXPLAINED.md](./WORKSPACE_PERSISTENCE_EXPLAINED.md)** - Comprehensive technical explanation of why `/workspace` storage is not persistent, with extensive Snowflake documentation citations
- **[SETUP_NOTEBOOK.ipynb](./SETUP_NOTEBOOK.ipynb)** - The setup notebook you must run first (and after each service restart)

---

## Architecture

### Default Snowflake Behavior
By default, Snowflake Notebooks in Workspaces gives each notebook its own isolated virtual environment and kernel. This means:
- Each notebook requires separate package installation
- Package installations are isolated per notebook
- More storage is used for duplicate packages

### Shared Library Approach
Instead, we've implemented a shared library directory:
- Location: `/workspace/site-packages-shared`
- All packages from `requirements.txt` are installed here once
- All notebooks add this directory to their Python path
- Packages are shared across all notebooks in the workspace

From the [Notebooks in Workspaces limitations](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-limitations) documentation:

> "Notebooks in the same workspace connect to a shared service by default."

This means notebooks in the same workspace already share compute resources, making a shared library directory a natural fit.

---

## Benefits

### 1. **Install Once, Use Everywhere**
- Run `SETUP_NOTEBOOK.ipynb` once to install all packages
- All other notebooks can immediately use these packages
- No need to run `pip install` in each notebook

### 2. **Faster Notebook Startup**
- Skip package installation time in individual notebooks
- Only need to configure the Python path (instant)
- Reduces overall development time

### 3. **Consistent Package Versions**
- All notebooks use the same package versions
- Reduces "works on my machine" problems
- Easier to debug and maintain

### 4. **Reduced Storage Usage**
- Packages stored once instead of duplicated across notebooks
- More efficient use of workspace storage
- Lower costs for large dependency trees

### 5. **Team Collaboration**
- Familiar workflow for teams used to shared environments
- Similar to traditional virtual environment approach
- Easier onboarding for new team members

---

## Risks and Limitations

### ⚠️ 1. **Non-Persistent Storage**

**CRITICAL LIMITATION:** The `/workspace` directory is **NOT persistent** across service restarts.

From the [Working with the file system](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-filesystem) documentation:

> "Files created in code or from the terminal exist only for the duration of the current notebook service session. When the notebook service is suspended, these files are removed."

And from the [Managing a notebook service](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-compute-setup#managing-a-notebook-service) documentation:

> "Suspending a service disconnects all notebooks connected to it, clears in-memory states, and removes all packages and variables. Files created from code and the command line to the Workspace file system and the /tmp directory are lost as well."

**Why this happens:** Snowflake Notebooks run on ephemeral container filesystems. Files created at runtime (like installed packages) are stored in the ephemeral layer and are deleted when the container service suspends.

**When does the service suspend?**
- Weekend maintenance (mandatory) → packages lost
- Idle timeout (default 1 hour, max 72 hours) → packages lost  
- After 7 days (mandatory maintenance) → packages lost
- Manual service restarts → packages lost
- Service configuration changes → packages lost

**Impact:**
- All packages in `/workspace/site-packages-shared` are permanently deleted
- Must completely reinstall all packages
- Typically requires 5-10 minutes to restore

**Solution:** Re-run `SETUP_NOTEBOOK.ipynb` after any service restart

**For detailed explanation:** See [WORKSPACE_PERSISTENCE_EXPLAINED.md](./WORKSPACE_PERSISTENCE_EXPLAINED.md) for a comprehensive technical deep-dive with full documentation citations.

### ⚠️ 2. **No Environment Isolation**

Unlike the default per-notebook approach, all notebooks share the same package versions.

**Impact:**
- If Notebook A needs `pandas==2.0.0` and Notebook B needs `pandas==2.3.0`, only one version can be installed
- Version conflicts must be resolved in `requirements.txt`
- Breaking changes in packages affect all notebooks

**Solution:** 
- Carefully manage package versions in `requirements.txt`
- Test all notebooks when updating package versions
- Consider using compatible version ranges (e.g., `pandas>=2.0.0,<3.0.0`)

### ⚠️ 3. **Package Compatibility Issues**

From the Snowflake documentation on requirements.txt:

> "If the package version specified in requirements.txt conflicts with supported versions of the pre-installed packages, the Python environment may break. Validate compatibility before installing."

**Impact:**
- Conflicts with pre-installed packages can break the entire environment
- All notebooks affected if environment breaks
- Recovery requires removing conflicting packages

**Solution:**
- Test package installations in `SETUP_NOTEBOOK.ipynb`
- Check for errors in the verification step
- Use `pip freeze` to inspect all installed packages

### ⚠️ 4. **Harder Debugging**

Without isolation, debugging package-related issues becomes more challenging.

**Impact:**
- Can't easily isolate which notebook caused a package conflict
- All notebooks affected by breaking changes
- Harder to roll back changes to specific notebooks

**Solution:**
- Document package requirements clearly
- Test changes in `SETUP_NOTEBOOK.ipynb` before deploying
- Keep version history in Git

### ⚠️ 5. **Setup Dependency**

All notebooks depend on `SETUP_NOTEBOOK.ipynb` being run first.

**Impact:**
- New team members must run setup first
- Easy to forget after service restarts
- Notebooks will fail with import errors if setup not run

**Solution:**
- Clear documentation (this file!)
- Add checks in notebooks for shared directory existence
- Display helpful error messages

---

## Usage Instructions

### Initial Setup

1. **Upload Files to Snowflake Workspace:**
   - All `.ipynb` notebook files
   - `requirements.txt`
   - All data files (`.csv`, etc.)

2. **Configure External Access Integration:**
   - Must be done by an admin with ACCOUNTADMIN role
   - Required for downloading packages from PyPI
   - See: [Enable External Access Integrations](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-on-spcs#enable-external-access-integrations-in-snowsight)

3. **Run Setup Notebook:**
   ```
   Open: SETUP_NOTEBOOK.ipynb
   Run All Cells
   Wait: 5-10 minutes for package installation
   Verify: All packages show ✓ in verification step
   ```

4. **Run Other Notebooks:**
   - All notebooks already have the shared library path configured
   - Just open and run any notebook
   - No additional package installation needed!

### After Service Restart

If you see import errors in your notebooks:

1. Check if service was restarted:
   - Notebook variables lost?
   - Import errors for previously working packages?
   - Weekend maintenance occurred?

2. Re-run Setup Notebook:
   ```
   Open: SETUP_NOTEBOOK.ipynb
   Run All Cells
   Wait: 5-10 minutes
   ```

3. Resume work in other notebooks

### Adding New Packages

1. Update `requirements.txt`:
   ```txt
   existing-package==1.0.0
   new-package==2.3.0
   ```

2. Re-run `SETUP_NOTEBOOK.ipynb`:
   - Creates a fresh shared directory
   - Installs all packages (including new ones)
   - Verifies installation

3. Test in notebooks:
   - New packages immediately available
   - No changes needed to notebook code

### Troubleshooting

#### Import Errors
```
Error: ModuleNotFoundError: No module named 'package_name'
```

**Solution:** Re-run `SETUP_NOTEBOOK.ipynb`

#### Package Conflicts
```
Error: Cannot install package X and Y together
```

**Solution:** 
1. Check `requirements.txt` for version conflicts
2. Adjust version requirements
3. Re-run `SETUP_NOTEBOOK.ipynb`

#### External Access Errors
```
Error: Could not fetch URL https://pypi.org/...
```

**Solution:** 
1. Verify External Access Integration is enabled
2. Check network rules include PyPI endpoints
3. Contact admin if needed

#### Slow Installation
```
Installation taking > 15 minutes
```

**Solution:**
1. This is normal for large dependency trees
2. Be patient - installation only needs to run once
3. Check notebook kernel is still running

---

## Technical Details

### Shared Directory Location
```
/workspace/site-packages-shared
```

### Python Path Configuration
Each notebook includes this code at the top:

```python
import sys

SITE_SHARED = "/workspace/site-packages-shared"

if SITE_SHARED not in sys.path:
    sys.path.append(SITE_SHARED)
```

This adds the shared directory to Python's module search path.

### Package Installation Command
```bash
mkdir -p /workspace/site-packages-shared
pip install --target /workspace/site-packages-shared -r requirements.txt
```

The `--target` flag tells pip to install packages to a custom location instead of the default site-packages.

### Package Search Order
Python searches for modules in this order:
1. Built-in modules
2. Current directory
3. Standard library
4. Default site-packages (pre-installed packages)
5. Custom paths in `sys.path` (including our shared directory)

---

## Comparison: Shared vs. Isolated Environments

| Aspect | Shared Library (This Approach) | Isolated Per-Notebook (Default) |
|--------|-------------------------------|----------------------------------|
| **Installation** | Once per workspace | Once per notebook |
| **Startup Time** | Fast (no installation) | Slower (must install packages) |
| **Storage Usage** | Efficient (packages stored once) | Higher (duplicate packages) |
| **Version Control** | Single version per package | Different versions per notebook |
| **Isolation** | No (all notebooks share) | Yes (each notebook isolated) |
| **Debugging** | Harder (shared conflicts) | Easier (isolated issues) |
| **Team Workflow** | Familiar (like venv) | Different (per-notebook) |
| **Persistence** | Not persistent (must re-run setup) | Not persistent (must re-install) |
| **Best For** | Teams with shared dependencies | Projects needing different versions |

---

## When to Use This Approach

### ✅ Good Fit:
- Teams accustomed to shared virtual environments
- Projects with consistent package requirements across notebooks
- Workflows prioritizing fast iteration
- Training/education scenarios with many users
- Cost-sensitive projects (reduced storage/compute)

### ❌ Not Ideal:
- Projects requiring different package versions per notebook
- Critical production workflows (isolation preferred)
- Infrequent service restart tolerance is low
- Teams unfamiliar with shared environment debugging

---

## Files in This Workspace

### Setup Files
- `SETUP_NOTEBOOK.ipynb` - Run this first! Installs all packages
- `requirements.txt` - List of all required Python packages
- `SHARED_LIBRARY_ARCHITECTURE.md` - This documentation file

### Demo Notebooks (All configured for shared libraries)
- `GETTING_STARTED_NOTEBOOK.ipynb` - Introduction to Snowflake Notebooks
- `GETTING_STARTED_DATA_CHALLENGE.ipynb` - Data challenge introduction
- `Demo_TerraClimate.ipynb` - TerraClimate dataset demo
- `Demo_TerraClimate_Snowflake.ipynb` - TerraClimate with Snowflake
- `Demo_Landsat_Viewer.ipynb` - Landsat imagery viewer
- `Landsat_Demo_Snowflake.ipynb` - Landsat with Snowflake
- `SNOWFLAKE_DEMO_LANDSAT_VIEWER.ipynb` - Landsat viewer for Snowflake
- `Biodiversity_Challenge_Benchmark.ipynb` - Biodiversity challenge

### Data Files
- `Training_Data.csv` - Training dataset
- `Validation_Template.csv` - Validation template
- `water_quality_training_dataset_100.csv` - Water quality data
- `regression_pipeline.pkl` - Saved ML pipeline

### Other Files
- `snowflake_setup.sql` - SQL setup scripts
- `SNOWFLAKE_MIGRATION_GUIDE.md` - Migration guide
- `README.md` - Project README

---

## Best Practices

### 1. Document Package Requirements
- Keep `requirements.txt` updated
- Add comments explaining why packages are needed
- Pin versions for reproducibility

### 2. Test After Changes
- Always run `SETUP_NOTEBOOK.ipynb` after updating `requirements.txt`
- Check the verification step for errors
- Test in a sample notebook before rolling out

### 3. Monitor Service Restarts
- Be aware of weekend maintenance schedules
- Check for restart indicators (lost variables, import errors)
- Set idle timeout appropriately for your workflow

### 4. Communicate with Team
- Notify team when updating packages
- Share this documentation with new members
- Establish process for handling service restarts

### 5. Version Control
- Commit `requirements.txt` to Git
- Track changes to package versions
- Document reasons for major version updates

---

## Additional Resources

### Snowflake Documentation
- [Notebooks in Workspaces](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-on-spcs)
- [Notebooks Limitations](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-limitations)
- [Manage Packages](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-manage-packages)
- [External Access Integration](https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-overview)

### Python Package Management
- [pip Documentation](https://pip.pypa.io/)
- [requirements.txt Format](https://pip.pypa.io/en/stable/reference/requirements-file-format/)
- [Python Module Search Path](https://docs.python.org/3/tutorial/modules.html#the-module-search-path)

---

## Summary

The shared library architecture provides a familiar, efficient workflow for teams accustomed to traditional virtual environments. While it requires awareness of service restarts and careful version management, it significantly improves development speed and resource efficiency for projects with consistent package requirements.

**Key Takeaway:** This approach works well, but **always re-run `SETUP_NOTEBOOK.ipynb` after service restarts** to restore the shared package environment.

---

**Last Updated:** December 22, 2025
**Snowflake Version:** Notebooks in Workspaces (Preview)

