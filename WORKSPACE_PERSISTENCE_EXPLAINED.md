# Why the /workspace Directory is NOT Persistent in Snowflake Workspaces

## Executive Summary

The `/workspace` directory in Snowflake Notebooks is **ephemeral storage** that is tied to the lifecycle of a **Snowpark Container Services (SPCS) instance**. When the container service suspends or restarts, all files created programmatically or via terminal commands are **permanently deleted**. This is a fundamental architectural limitation of how Snowflake Notebooks on Container Runtime operates.

---

## The Core Issue: Ephemeral Container Filesystem

### What Snowflake Documentation Says

From the [Working with the file system](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-filesystem) documentation:

> "Although the Workspaces directory is read/write, file persistence is limited:
> 
> - **Files created in code or from the terminal exist only for the duration of the current notebook service session.** When the notebook service is suspended, these files are removed. During the session, you will see these files if you list the directory (using `ls`) under `/workspace/<workspace_hash>`, but they do not persist after the session ends.
> - **Only files that are uploaded or created in Snowsight persist across sessions.**
> - Files created from code or the terminal do not appear in the left-hand pane. This is a temporary limitation."

**Key Takeaway:** Files created by `pip install --target /workspace/site-packages-shared` are created via code/terminal and therefore **do not persist** when the service suspends.

---

## Understanding Snowpark Container Services Architecture

### Notebooks Run on Container Services

Snowflake Notebooks in Workspaces run on **Snowpark Container Services (SPCS)**, which are Docker-like containers managed by Snowflake. Each notebook service is essentially a containerized environment.

From the [Compute setup for Snowflake Notebooks in Workspaces](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-compute-setup) documentation:

> "When a user runs a notebook, the user creates a Snowflake-managed notebook service to host the notebook kernel and execute code."

### Container Lifecycle = File Lifecycle

In container architectures, the filesystem inside a container is **ephemeral by default** unless explicitly configured otherwise. When a container stops, its filesystem state is lost.

From the [Managing a notebook service](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-compute-setup#managing-a-notebook-service) documentation:

> "Suspending a service disconnects all notebooks connected to it, clears in-memory states, and removes all packages and variables. **Files created from code and the command line to the Workspace file system and the /tmp directory are lost as well.**"

---

## When Does the Service Suspend (and Files Get Lost)?

### 1. Idle Timeout (Default: 1 hour)

From the [Notebooks in Workspaces limitations](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-limitations) documentation:

> "After a Container Runtime notebook session starts, it can run up to seven days without disruption. After seven days, it may be disrupted and shut down if there is a scheduled SPCS service maintenance event. **The notebook idle time settings still apply.**"

**Default idle timeout:** 1 hour (configurable up to 72 hours)

When idle timeout is reached:
- Service suspends automatically
- All containers shut down
- Filesystem is wiped
- **All packages in `/workspace/site-packages-shared` are deleted**

### 2. Weekend Maintenance

From the [Notebooks in Workspaces limitations](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-limitations) documentation:

> "**Notebook services may be restarted over the weekend for container service maintenance.** After a restart, you must rerun notebooks and reinstall any packages to restore variables and packages."

Snowflake performs routine maintenance on container services, particularly on weekends. This is mandatory and unavoidable.

### 3. Seven-Day Service Limit

From the [Service maintenance](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-compute-setup#service-maintenance) documentation:

> "After a notebook service enters the RUNNING state (whether newly created or resumed after being in SUSPENDED state), it is guaranteed not to be disrupted for seven calendar days (168 hours) due to service maintenance. **After seven days of creation, the service may be suspended for mandatory maintenance.**"

Even if you keep the service active, it **must** be restarted after 7 days for mandatory maintenance.

### 4. Manual Suspension

Users or administrators can manually suspend a service:
- Via the Snowsight UI
- Via SQL: `ALTER SERVICE ... SUSPEND`
- Via Snowflake CLI

When manually suspended, all ephemeral files are deleted.

### 5. Service Configuration Changes

From the [Editing a notebook service](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-compute-setup#editing-a-notebook-service) documentation:

> "Changes to (1) [External Access Integrations] or (2) [Runtime version] suspend then restart the service."

Any configuration change that requires a restart will wipe the filesystem.

---

## What IS Persistent in Snowflake Workspaces?

### Only Snowsight-Uploaded Files Persist

From the [Working with the file system](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-filesystem) documentation:

> "**Only files that are uploaded or created in Snowsight persist across sessions.**"

Files that persist:
- ✅ Notebook `.ipynb` files uploaded via Snowsight
- ✅ Data files (`.csv`, `.txt`) uploaded via Snowsight
- ✅ Any file created using the Snowsight file upload UI
- ✅ Files in the left-hand pane of the Workspaces interface

Files that **DO NOT** persist:
- ❌ Packages installed via `pip install`
- ❌ Files created via Python code (e.g., `open('file.txt', 'w')`)
- ❌ Files created via terminal commands (e.g., `mkdir`, `touch`)
- ❌ Downloaded data from external APIs
- ❌ Generated plots or images saved to disk
- ❌ Any file in `/tmp` directory

---

## Why Doesn't Snowflake Use Persistent Storage?

### Container Services Design Philosophy

Snowpark Container Services follows standard containerization principles where:
1. **Containers are immutable** - The base image doesn't change
2. **State is ephemeral** - Runtime changes don't persist
3. **Data is externalized** - Persistent data goes to external storage

### Persistent Storage Options (Not Available for Packages)

Snowflake does provide persistent storage options for **data** (not packages):

#### Block Storage Volumes

From the [Using block storage volumes with services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-volumes) documentation:

Block storage volumes provide persistent storage that survives service restarts. However:
- These are designed for **data persistence**, not package management
- Must be explicitly configured in service specification
- Require additional setup and cost
- **Not available for standard notebook workspaces** (requires custom service configuration)

#### Stage Volumes

From the [Using Snowflake stage volumes with services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-volumes-stage) documentation:

Snowflake stages can be mounted as volumes for persistent storage. However:
- Stages are optimized for **data files**, not Python packages
- Performance issues with many small files (typical for packages)
- File rename/move operations not well supported
- Not suitable for package management use cases

### Why Not Use These for Packages?

Python packages have characteristics that don't work well with persistent volumes:
1. **Many small files**: A typical package has hundreds of small `.py` files
2. **Complex directory structures**: Nested folders and symlinks
3. **Performance requirements**: Import statements need fast file access
4. **Dependency on file permissions**: Some packages need specific permissions

---

## Technical Deep Dive: Container Filesystem Layers

### How Container Filesystems Work

Container filesystems use a **layered architecture**:

```
┌─────────────────────────────────────┐
│  Ephemeral Layer (Read/Write)       │ ← /workspace files here
│  - Runtime modifications             │ ← Packages installed here
│  - User-created files                │ ← LOST on suspend
├─────────────────────────────────────┤
│  Container Image Layers (Read-Only) │
│  - Base OS                           │ ← Pre-installed packages
│  - Python runtime                    │ ← Persists (in image)
│  - Pre-installed packages            │ ← Persists (in image)
└─────────────────────────────────────┘
```

When a container service suspends:
1. The **ephemeral layer is discarded** (top layer)
2. The **base image layers are preserved** (bottom layers)
3. On restart, a **new ephemeral layer** is created from scratch

### What's in the Base Image?

Snowflake's container images come with pre-installed packages:
- Python standard library
- Snowpark Python
- Common scientific packages (varies by version)
- System utilities

These persist because they're **baked into the image**, not installed at runtime.

### What You Install at Runtime

Packages installed via `pip install` go into the ephemeral layer:
```bash
pip install --target /workspace/site-packages-shared -r requirements.txt
```

This command:
1. Downloads packages from PyPI
2. Extracts them to `/workspace/site-packages-shared`
3. Files are written to the **ephemeral layer**
4. **Lost when container suspends**

---

## Why This Matters for Shared Libraries

### The Shared Library Architecture's Dependency

The shared library approach relies on:
1. Creating a directory at runtime: `mkdir -p /workspace/site-packages-shared`
2. Installing packages at runtime: `pip install --target ...`
3. Accessing those packages later: `sys.path.append(...)`

**All three steps depend on ephemeral storage.**

### What Happens on Service Restart

```
Timeline:
─────────────────────────────────────────────────────────────────
Day 1, 9:00 AM:
  ✓ Run SETUP_NOTEBOOK.ipynb
  ✓ Packages installed to /workspace/site-packages-shared
  ✓ All notebooks work perfectly

Day 1, 10:00 AM - Day 3:
  ✓ Notebooks running fine
  ✓ No package installation needed
  ✓ Fast and efficient

Weekend (Saturday):
  ⚠️  Mandatory maintenance
  ⚠️  Service suspends
  ❌ /workspace/site-packages-shared DELETED
  ⚠️  Service restarts with clean filesystem

Monday, 9:00 AM:
  ❌ Notebooks fail with "ModuleNotFoundError"
  ⚠️  Need to re-run SETUP_NOTEBOOK.ipynb
  ⚠️  Wait 5-10 minutes for reinstall
  ✓ After setup, notebooks work again
─────────────────────────────────────────────────────────────────
```

---

## Comparison: Different Storage Approaches

| Approach | Persistence | Use Case | Available in Notebooks? |
|----------|-------------|----------|------------------------|
| **Ephemeral Container Filesystem** | ❌ Lost on suspend | Runtime state, temporary files | ✅ Yes (default) |
| **Snowsight-Uploaded Files** | ✅ Persistent | Notebooks, data files, code | ✅ Yes |
| **Block Storage Volumes** | ✅ Persistent | Large datasets, ML models | ❌ No (custom services only) |
| **Stage Volumes** | ✅ Persistent | Data files, archives | ⚠️ Limited (not for packages) |
| **Snowflake Tables** | ✅ Persistent | Structured data | ✅ Yes (via SQL) |
| **Pre-installed Packages** | ✅ Persistent | Common libraries | ✅ Yes (in base image) |
| **Runtime-installed Packages** | ❌ Lost on suspend | Custom libraries | ✅ Yes (must reinstall) |

---

## Alternative Approaches (and Why They Don't Work)

### ❌ Approach 1: "Just use persistent storage"

**Problem:** 
- Block storage not available for standard notebooks
- Would require custom service configuration
- Adds complexity and cost
- Still need to configure mount paths

### ❌ Approach 2: "Install packages to a Snowflake stage"

**Problem:**
- Stages optimized for large files, not many small files
- Poor performance for package imports
- Complex setup with `GET` commands
- Python's import system doesn't work well with stage-backed files

### ❌ Approach 3: "Use pre-installed packages only"

**Problem:**
- Limited to packages in base image
- Can't use specialized libraries (rioxarray, pystac_client, etc.)
- Can't control versions
- Doesn't meet project requirements

### ❌ Approach 4: "Build a custom container image"

**Potential solution, but:**
- Requires ACCOUNTADMIN privileges
- Complexity of managing container images
- Need container registry setup
- Not yet supported for Notebooks in Workspaces

From the [Notebooks in Workspaces limitations](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-limitations) documentation:

> "**Custom container images and the artifact repository are not yet supported in Notebooks in Workspaces.**"

---

## The Shared Library Approach: Accepted Trade-off

### Why Use It Despite Non-Persistence?

The shared library approach **accepts** non-persistence in exchange for:

**Benefits:**
1. ✅ Install once per session instead of once per notebook
2. ✅ Faster iteration during active development
3. ✅ Familiar workflow for data science teams
4. ✅ Reduced storage usage within a session
5. ✅ Consistent package versions across notebooks

**Trade-offs:**
1. ⚠️ Must re-run setup after service restarts
2. ⚠️ Requires team awareness and documentation
3. ⚠️ No environment isolation between notebooks
4. ⚠️ Need monitoring for service maintenance events

### When Is This Acceptable?

**Good fit:**
- ✅ Active development phases (daily work)
- ✅ Teams with good communication
- ✅ Projects with consistent package requirements
- ✅ Workloads that can tolerate 5-10 minute setup
- ✅ Cost-sensitive projects

**Not ideal:**
- ❌ Production pipelines requiring 100% uptime
- ❌ Infrequent usage (weekly/monthly)
- ❌ Unattended automated workflows
- ❌ Critical real-time processing

---

## Mitigation Strategies

### 1. Automate Setup Verification

Add a check at the beginning of each notebook:

```python
import sys
import os

SITE_SHARED = "/workspace/site-packages-shared"

# Check if setup has been run
if not os.path.exists(SITE_SHARED) or not os.listdir(SITE_SHARED):
    print("⚠️  ERROR: Shared library directory not found!")
    print("⚠️  Please run SETUP_NOTEBOOK.ipynb first.")
    print(f"⚠️  Expected directory: {SITE_SHARED}")
    raise RuntimeError("Setup required - run SETUP_NOTEBOOK.ipynb")

# Add to path
if SITE_SHARED not in sys.path:
    sys.path.append(SITE_SHARED)
    
print(f"✓ Shared library path configured: {SITE_SHARED}")
```

### 2. Monitor Service Status

Keep track of when the service was last restarted:

```python
import datetime
import os

STATUS_FILE = "/workspace/last_setup_time.txt"

# Record setup time
with open(STATUS_FILE, 'w') as f:
    f.write(datetime.datetime.now().isoformat())

# In other notebooks, check setup age
if os.path.exists(STATUS_FILE):
    with open(STATUS_FILE, 'r') as f:
        setup_time = datetime.datetime.fromisoformat(f.read())
    age_hours = (datetime.datetime.now() - setup_time).total_seconds() / 3600
    if age_hours > 168:  # 7 days
        print(f"⚠️  Warning: Setup is {age_hours:.1f} hours old")
        print("⚠️  Service maintenance may occur soon. Be prepared to re-run setup.")
```

### 3. Optimize Reinstallation Time

Use `pip` caching and wheel files:

```bash
# Install with cache
pip install --target /workspace/site-packages-shared \
    --cache-dir /workspace/pip-cache \
    -r requirements.txt

# Cache persists within session, speeds up re-installs
```

### 4. Documentation and Communication

- ✅ Clear documentation (like this file!)
- ✅ Team onboarding checklist
- ✅ Slack/email notifications about maintenance
- ✅ Shared team calendar for known maintenance windows

---

## Future Snowflake Enhancements (Speculation)

Snowflake may eventually address this limitation:

### Possible Future Solutions

1. **Custom Container Image Support**
   - Package dependencies baked into image
   - Would persist across restarts
   - Currently not supported

2. **Persistent Package Cache**
   - Snowflake-managed package storage
   - Automatic restoration after restart
   - Similar to Anaconda channel (deprecated)

3. **Artifact Repository Integration**
   - From [Notebooks in Workspaces limitations](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-limitations):
   > "Custom container images and the artifact repository are not yet supported in Notebooks in Workspaces."
   - May be available in future releases

4. **Workspace-Level Package Management**
   - Install packages at workspace level
   - Shared across all notebooks automatically
   - Would require architectural changes

---

## Summary

### The Core Answer

**Why is `/workspace` not persistent?**

Because Snowflake Notebooks run on **Snowpark Container Services**, which use **ephemeral container filesystems** that are **intentionally wiped** when the service suspends or restarts. This is standard container architecture and a deliberate design choice for security, consistency, and resource management.

### What This Means for Your Team

1. **Accept the limitation**: Ephemeral storage is fundamental to the architecture
2. **Plan for restarts**: Budget 5-10 minutes to re-run setup after service restarts
3. **Document clearly**: Ensure all team members understand the workflow
4. **Monitor proactively**: Be aware of maintenance schedules and idle timeouts
5. **Trade efficiency within sessions for setup after restarts**: This is the core trade-off

### The Bottom Line

The shared library approach **works well** for active development but requires **disciplined setup management** when services restart. It's a pragmatic solution that trades persistence for convenience and efficiency during active work sessions.

---

## References

All information in this document is sourced from official Snowflake documentation:

1. [Working with the file system](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-filesystem)
2. [Notebooks in Workspaces limitations](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-limitations)
3. [Compute setup for Snowflake Notebooks in Workspaces](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-compute-setup)
4. [Managing a notebook service](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-compute-setup#managing-a-notebook-service)
5. [Using block storage volumes with services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-volumes)
6. [Using Snowflake stage volumes with services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-volumes-stage)

---

**Document Version:** 1.0  
**Last Updated:** December 22, 2025  
**Snowflake Version:** Notebooks in Workspaces (Preview)

