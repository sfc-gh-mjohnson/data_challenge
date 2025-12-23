# Quick Reference: Shared Libraries in Snowflake Workspaces

## 🚀 Getting Started (First Time)

1. **Upload all files to Snowflake Workspace**
   - All `.ipynb` notebooks
   - `requirements.txt`
   - All data files

2. **Configure External Access Integration**
   - Must be done by admin (ACCOUNTADMIN role)
   - Required for downloading packages from PyPI

3. **Run Setup**
   ```
   Open: SETUP_NOTEBOOK.ipynb
   Click: Run All
   Wait: 5-10 minutes
   Verify: All packages show ✓
   ```

4. **Run any notebook**
   - Already configured with shared library path
   - No package installation needed!

---

## 🔄 After Service Restart

### When do restarts happen?
- Weekend maintenance (Saturdays)
- Idle timeout (default: 1 hour)
- After 7 days (mandatory)
- Configuration changes

### How do you know a restart happened?
- Import errors: `ModuleNotFoundError`
- Variables lost
- Files created in code are missing

### What to do?
```
1. Open: SETUP_NOTEBOOK.ipynb
2. Run All Cells
3. Wait 5-10 minutes
4. Continue working
```

---

## ⚠️ Critical Warning

**THE `/workspace` DIRECTORY IS NOT PERSISTENT!**

From [Snowflake Documentation](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-filesystem):

> "Files created in code or from the terminal exist only for the duration of the current notebook service session. When the notebook service is suspended, these files are removed."

**This means:**
- ❌ Packages installed via `pip` are lost on restart
- ❌ Files created via Python code are lost
- ❌ Terminal commands output is lost
- ✅ **Solution:** Re-run `SETUP_NOTEBOOK.ipynb` after restarts

**For detailed explanation:** See [WORKSPACE_PERSISTENCE_EXPLAINED.md](./WORKSPACE_PERSISTENCE_EXPLAINED.md)

---

## 📝 Daily Workflow

### Morning Routine
```
1. Open Snowflake Workspace
2. Open any notebook
3. Try running a cell with imports
4. If imports fail → Run SETUP_NOTEBOOK.ipynb
5. If imports work → Continue working!
```

### During Work
- ✅ Run any notebook without installing packages
- ✅ All notebooks share same package versions
- ✅ Fast iteration and development

### Monday After Weekend
- ⚠️ Expect to re-run SETUP_NOTEBOOK.ipynb
- ⚠️ Weekend maintenance likely occurred
- ⚠️ Budget 5-10 minutes for setup

---

## 🛠️ Troubleshooting

### Problem: `ModuleNotFoundError`
```python
ModuleNotFoundError: No module named 'rioxarray'
```
**Solution:** Run `SETUP_NOTEBOOK.ipynb`

---

### Problem: Imports are slow
**Cause:** Normal - many packages to import  
**Solution:** None needed, first import is always slower

---

### Problem: Package installation fails
```
ERROR: Could not fetch URL https://pypi.org/...
```
**Solution:** Check External Access Integration settings with admin

---

### Problem: Setup takes > 15 minutes
**Cause:** Large dependency tree, slow network  
**Solution:** Be patient, this is normal for first install

---

### Problem: Version conflicts
```
ERROR: Cannot install package X and Y together
```
**Solution:**
1. Edit `requirements.txt`
2. Adjust version constraints
3. Re-run `SETUP_NOTEBOOK.ipynb`

---

## 📦 Adding New Packages

1. **Edit `requirements.txt`:**
   ```txt
   existing-package==1.0.0
   new-package==2.3.0  # ← Add this line
   ```

2. **Re-run setup:**
   ```
   Open: SETUP_NOTEBOOK.ipynb
   Run All Cells
   ```

3. **Use in notebooks:**
   ```python
   import new_package  # Works immediately!
   ```

---

## 📊 What Persists vs. What Doesn't

### ✅ Persistent (Survives Restarts)
- Notebooks (`.ipynb` files)
- Data files uploaded via Snowsight
- Code files (`.py`) uploaded via Snowsight
- `requirements.txt`
- Files in left-hand pane of Workspace

### ❌ Not Persistent (Lost on Restart)
- **Packages installed via `pip`** ← YOUR MAIN CONCERN
- Files created in Python code
- Files created via terminal
- Variables and notebook state
- Downloaded data not uploaded to Snowsight
- `/tmp` directory contents

---

## 🔍 How to Check If Setup Is Needed

### Method 1: Visual Check
```python
import os
path = "/workspace/site-packages-shared"
if os.path.exists(path) and os.listdir(path):
    print("✓ Setup already run")
else:
    print("❌ Need to run SETUP_NOTEBOOK.ipynb")
```

### Method 2: Try Import
```python
try:
    import rioxarray
    print("✓ Packages available")
except ImportError:
    print("❌ Run SETUP_NOTEBOOK.ipynb")
```

---

## 💡 Pro Tips

### Tip 1: Start Each Monday with Setup
- Weekend maintenance is common
- Proactively run `SETUP_NOTEBOOK.ipynb` Monday morning
- Avoid mid-work interruptions

### Tip 2: Share Setup Status with Team
- "Just re-ran setup, all good for today"
- Helps teammates know if setup needed
- Reduces duplicate setup runs

### Tip 3: Keep Terminal Open
- Terminal in Workspace shows if service restarted
- Look for "connection lost" messages
- Indicator to re-run setup

### Tip 4: Set Idle Timeout Higher
- Default: 1 hour
- Maximum: 72 hours
- Settings → Notebook actions → Idle timeout
- Reduces frequency of restarts

### Tip 5: Monitor Service Age
```python
# In notebooks, check last setup time
import os
if os.path.exists("/workspace/last_setup_time.txt"):
    with open("/workspace/last_setup_time.txt") as f:
        print(f"Last setup: {f.read()}")
```

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `SETUP_NOTEBOOK.ipynb` | **Run this first!** Installs all packages |
| `SHARED_LIBRARY_ARCHITECTURE.md` | Complete architecture explanation |
| `WORKSPACE_PERSISTENCE_EXPLAINED.md` | Technical deep-dive on persistence |
| `QUICK_REFERENCE.md` | This file - quick reference guide |
| `requirements.txt` | List of required packages |

---

## 🎯 Key Takeaways

1. **First time:** Run `SETUP_NOTEBOOK.ipynb` once
2. **After restarts:** Re-run `SETUP_NOTEBOOK.ipynb`
3. **All notebooks:** Already configured, just run them
4. **Persistence:** Only Snowsight-uploaded files persist
5. **Restarts happen:** Weekends, idle timeout, 7-day limit

---

## ❓ FAQ

**Q: Why not just install packages in each notebook?**  
A: You can! The shared approach saves time during active development.

**Q: Can I make packages persistent?**  
A: No, ephemeral storage is fundamental to container architecture.

**Q: What if I forget to run setup?**  
A: Notebooks fail with import errors. Just run `SETUP_NOTEBOOK.ipynb`.

**Q: How often do restarts happen?**  
A: Variable - weekends, idle timeouts, max 7 days between mandatory restarts.

**Q: Can I use different package versions in different notebooks?**  
A: Not with this approach. That requires per-notebook installation.

**Q: Will this work in production?**  
A: It works, but consider whether 5-10 minute setup after restarts is acceptable.

**Q: What if PyPI is down?**  
A: Package installation fails. Wait for PyPI to recover, then retry.

**Q: Can I install from private package repositories?**  
A: Yes, configure External Access Integration for your repository.

---

## 📞 Getting Help

1. **Check documentation:**
   - Read `WORKSPACE_PERSISTENCE_EXPLAINED.md`
   - Review `SHARED_LIBRARY_ARCHITECTURE.md`

2. **Verify setup:**
   - Re-run `SETUP_NOTEBOOK.ipynb`
   - Check verification output for errors

3. **Check External Access:**
   - Ask admin to verify External Access Integration
   - Confirm PyPI endpoints are allowed

4. **Review Snowflake docs:**
   - [Notebooks in Workspaces](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-on-spcs)
   - [Working with the file system](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-filesystem)

---

**Last Updated:** December 22, 2025  
**Version:** 1.0  
**Snowflake:** Notebooks in Workspaces (Preview)

