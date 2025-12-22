# Why Can't Runtime Changes Go to the Persistent Workspace Directory?

## The Paradox Explained

You've identified a crucial architectural detail: The `/workspace/<workspace_hash>` directory has **TWO separate storage layers**, even though they appear as the same directory path!

## The Key Documentation Quote

From the [Working with the file system](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-filesystem) documentation:

> "Although the Workspaces directory is read/write, file persistence is limited:
> 
> - **Files created in code or from the terminal exist only for the duration of the current notebook service session.** When the notebook service is suspended, these files are removed. During the session, you will see these files if you list the directory (using `ls`) under `/workspace/<workspace_hash>`, but they do not persist after the session ends.
> - **Only files that are uploaded or created in Snowsight persist across sessions.**
> - **Files created from code or the terminal do not appear in the left-hand pane.** This is a temporary limitation."

## Two Storage Layers in the Same Directory

### Layer 1: Snowflake-Managed Persistent Storage (Snowsight Files)

```
/workspace/<workspace_hash>/
  ├── notebook1.ipynb           ✅ Persistent (uploaded via Snowsight)
  ├── requirements.txt          ✅ Persistent (uploaded via Snowsight)
  ├── data.csv                  ✅ Persistent (uploaded via Snowsight)
  └── my_script.py              ✅ Persistent (uploaded via Snowsight)
```

**Storage backend:** Snowflake's internal storage system (similar to stages)  
**Appears in:** Left-hand pane in Workspaces UI  
**Lifecycle:** Independent of container service  
**Access:** Mounted read-only (or with restricted write) into container

### Layer 2: Container Ephemeral Storage (Runtime Files)

```
/workspace/<workspace_hash>/
  ├── site-packages-shared/     ❌ Ephemeral (created via pip/code)
  │   ├── rioxarray/            ❌ Ephemeral
  │   ├── pandas/               ❌ Ephemeral
  │   └── ...
  ├── temp_output.tiff          ❌ Ephemeral (created via code)
  └── downloaded_data.json      ❌ Ephemeral (created via code)
```

**Storage backend:** Container's writable filesystem layer  
**Appears in:** Terminal `ls` but NOT in Snowsight UI  
**Lifecycle:** Tied to container service instance  
**Access:** Container's ephemeral storage

## The Architecture: Why They're Separate

### How Snowflake Mounts the Workspace

```
┌─────────────────────────────────────────────────────────┐
│  Container Instance (SPCS)                              │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  Ephemeral Layer (Container Filesystem)        │    │
│  │  /workspace/<hash>/site-packages-shared/       │    │
│  │  /workspace/<hash>/temp_files/                 │    │
│  │  ← Created by code/terminal                    │    │
│  │  ← LOST on container suspend                   │    │
│  └────────────────────────────────────────────────┘    │
│                      ↓ Union Mount                      │
│  ┌────────────────────────────────────────────────┐    │
│  │  Snowflake-Managed Mount (Read-mostly)         │    │
│  │  /workspace/<hash>/notebook1.ipynb             │    │
│  │  /workspace/<hash>/requirements.txt            │    │
│  │  ← Synced from Snowflake storage               │    │
│  │  ← PERSISTS across service restarts            │    │
│  └────────────────────────────────────────────────┘    │
│                      ↑                                   │
└──────────────────────┼───────────────────────────────────┘
                       │
                       │ Network/Storage Protocol
                       ↓
         ┌─────────────────────────────┐
         │  Snowflake Backend Storage  │
         │  (Internal Stage-like)      │
         │  - notebook1.ipynb          │
         │  - requirements.txt         │
         │  - data.csv                 │
         └─────────────────────────────┘
```

### Union Mount Filesystem

The container uses a **union mount** or **overlay filesystem**:

1. **Bottom layer:** Snowflake-managed files (persistent)
   - Mounted into container from Snowflake's storage backend
   - Read-only or read-mostly access
   - Survives container lifecycle

2. **Top layer:** Container's writable layer (ephemeral)
   - Catches all writes from code/terminal
   - Writable by container processes
   - Discarded on container stop

When you run `pip install --target /workspace/site-packages-shared`:
- Python creates files/directories
- These writes go to the **ephemeral top layer**
- They never reach the **persistent bottom layer**
- Result: Lost on container restart

## Why Doesn't Snowflake Sync Runtime Files Back?

### Technical Reasons

#### 1. **Performance Implications**

Syncing thousands of small files (typical for Python packages) back to Snowflake storage would be extremely slow:

```
A typical pip install might create:
- 10,000+ small files (Python modules, metadata)
- 100+ directories
- Symlinks, compiled bytecode, etc.

Syncing this would require:
- Individual file uploads to Snowflake storage
- Metadata tracking for each file
- Network round-trips for each file
- Significant latency on every write
```

**Package installation that normally takes 5 minutes could take 30+ minutes!**

#### 2. **Storage System Design**

Snowflake's workspace storage is optimized for:
- ✅ Notebook files (.ipynb) - infrequent updates, manual edits
- ✅ Data files (.csv, .parquet) - read-heavy workloads
- ✅ Code files (.py, .sql) - version-controlled, deliberate changes

It's **NOT** optimized for:
- ❌ High-frequency small file writes (pip install)
- ❌ Thousands of tiny files (Python packages)
- ❌ Temporary/transient data (runtime state)

#### 3. **Security and Control**

Allowing arbitrary runtime files to persist introduces risks:
- **Malicious packages** could persist across sessions
- **Corrupted installations** would persist
- **Difficult cleanup** of failed installations
- **Version conflicts** harder to resolve

By keeping runtime installations ephemeral:
- Each restart = clean slate
- No accumulation of installation debris
- Easier to recover from errors
- More predictable environment

#### 4. **State Management Complexity**

If runtime files persisted, Snowflake would need to:
- Track which files are "official" workspace files vs. runtime files
- Handle file conflicts (uploaded vs. installed)
- Manage file ownership and permissions
- Sync files bidirectionally between container and backend
- Handle concurrent access from multiple notebooks

This adds enormous complexity!

#### 5. **Container Services Architecture**

Snowpark Container Services follows standard container design:
- **Immutable infrastructure** principle
- **Ephemeral containers** by default
- **Explicit persistence** only where needed (via volumes)
- **Clear separation** between code/config (persistent) and state (ephemeral)

## Could Snowflake Change This?

### Possible Future Solutions

#### Option 1: Automatic Sync for Specific Directories

Snowflake could designate certain directories for automatic sync:

```python
/workspace/<hash>/persistent_packages/  # Auto-synced to backend
```

**Challenges:**
- Performance overhead
- Sync timing (immediate vs. periodic vs. on-suspend)
- Conflict resolution
- Storage costs

**Status:** Not currently available

#### Option 2: Block Storage Volumes

Snowflake does offer persistent block storage for SPCS:

```yaml
spec:
  volumes:
  - name: packages
    source: block
    size: 10Gi
```

**Why not used for notebooks:**
- Requires custom service configuration
- Not available in standard notebook workspaces
- Adds complexity and cost
- Would still need explicit mounting

**Status:** Available for custom SPCS services, but not for standard Notebooks in Workspaces

#### Option 3: Pre-built Custom Container Images

Users could build custom container images with packages pre-installed:

```dockerfile
FROM snowflake-notebook-base:latest
COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt
```

**Benefits:**
- Packages baked into image = persistent
- No runtime installation needed
- Faster startup

**Status:** 
From [Notebooks in Workspaces limitations](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-limitations):

> "**Custom container images and the artifact repository are not yet supported in Notebooks in Workspaces.**"

This may come in future releases!

#### Option 4: Managed Package Registry

Snowflake could create a managed package cache:

```python
# Hypothetical future feature
!sf-pip install rioxarray  # Installs from Snowflake's managed cache
```

**Benefits:**
- Fast installation (cached by Snowflake)
- Potentially persistent across restarts
- Pre-validated packages

**Status:** Not currently available (speculation)

## Why the Current Design Makes Sense

Despite the limitation, the current architecture is actually **well-reasoned**:

### 1. **Clear Mental Model**
- Uploaded via UI = Persistent
- Created via code = Ephemeral
- Easy to understand and explain

### 2. **Fast Iteration During Sessions**
- Runtime installations are fast (local filesystem)
- No network overhead during active work
- Optimized for development workflows

### 3. **Clean State on Restart**
- No accumulated cruft
- Fresh environment every time
- Easier troubleshooting

### 4. **Explicit Persistence**
- Forces deliberate decisions about what persists
- Prevents accidental data loss (thinking something persists when it doesn't)
- Clear workflow: upload important files via UI

### 5. **Standard Container Patterns**
- Follows Docker/Kubernetes conventions
- Familiar to engineers
- Industry best practices

## The Real Question: Why Not Git-Track Packages?

An alternative approach some users might consider:

```
/workspace/<hash>/.venv/    # Track this in Git?
```

**Why this doesn't work:**
1. **Size:** Python packages = 100s of MB to GBs (Git is for source code, not dependencies)
2. **Platform-specific:** Compiled extensions differ by OS/architecture
3. **Binary files:** Git handles text files well, not binary wheels
4. **Conflicts:** Merge conflicts in package binaries are unsolvable

**Standard practice:** Track `requirements.txt` in Git, install packages at runtime

This is exactly what Snowflake's approach enforces!

## Workarounds (Current State)

Given the architectural limitations, here are the practical approaches:

### Approach 1: Re-install on Restart (Your Current Approach)
```python
# SETUP_NOTEBOOK.ipynb
!pip install --target /workspace/site-packages-shared -r requirements.txt
```

**Pros:** Simple, works, familiar workflow  
**Cons:** 5-10 minutes setup after each restart

### Approach 2: Install Per-Notebook
```python
# In each notebook
!pip install rioxarray pandas matplotlib
```

**Pros:** Standard pattern, each notebook independent  
**Cons:** Slower startup, repeated installations

### Approach 3: Use Pre-installed Packages Only
```python
# Only use packages in base image
import pandas  # Pre-installed
import numpy   # Pre-installed
```

**Pros:** No installation needed, always available  
**Cons:** Limited package selection, can't control versions

### Approach 4: Upload .whl Files, Install from Local
```python
# Upload packages as .whl files to workspace
!pip install /workspace/<hash>/my_package-1.0.0-py3-none-any.whl
```

**Pros:** Faster than downloading from PyPI, wheels are persistent  
**Cons:** Must manually download/upload wheels, dependency management complex

## The Bottom Line

**Why can't runtime changes go to the persistent workspace directory?**

Because the "persistent workspace directory" is actually:
1. **Mounted FROM** Snowflake's backend storage INTO the container
2. **Optimized FOR** user-uploaded files (notebooks, data, code)
3. **Not designed FOR** high-frequency small writes (package installations)
4. **Architecturally separate FROM** the container's writable filesystem

The `/workspace` path you see is a **union** of two storage layers:
- **Snowflake-managed layer** (persistent, read-mostly) - for user files
- **Container filesystem layer** (ephemeral, read-write) - for runtime state

When you run `pip install`, writes go to the **ephemeral layer**, which is by design!

## Future Outlook

Snowflake may address this in future releases:
- ✅ Custom container images (most likely solution)
- ✅ Workspace-level package management
- ✅ Persistent package cache
- ❌ Auto-sync of runtime files (unlikely due to performance)

Until then, the **re-run setup approach** is the pragmatic solution that balances convenience with the platform's architectural constraints.

---

## References

1. [Working with the file system](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-filesystem) - Explains persistent vs. ephemeral files
2. [Notebooks in Workspaces limitations](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-limitations) - Current limitations
3. [Using block storage volumes with services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-volumes) - Alternative for custom services

---

**Document Version:** 1.0  
**Last Updated:** December 22, 2025  
**Snowflake Version:** Notebooks in Workspaces (Preview)

