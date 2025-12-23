# Agent Instructions

## Snowflake Documentation Citations

When quoting from Snowflake documentation (via the `mcp_snowflake-docs_snowflake-docs` tool):

1. **Always include direct links** to the documentation source when providing quotes
2. The MCP results include the page title in the format `"Page Title | Snowflake Documentation"` - use this to construct the URL
3. Snowflake docs URLs follow the pattern: `https://docs.snowflake.com/en/` + kebab-case path derived from the title
4. Example format for citations:

```
From the [Limitations with Notebooks](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-limitations) documentation:

> "Only one executable ipynb file is permitted within each notebook."
```

### Common Documentation URL Patterns

| Topic | URL Pattern |
|-------|-------------|
| Notebooks | `https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks-*` |
| SQL Commands | `https://docs.snowflake.com/en/sql-reference/sql/*` |
| Snowpark | `https://docs.snowflake.com/en/developer-guide/snowpark/*` |
| Data Loading | `https://docs.snowflake.com/en/user-guide/data-load-*` |

### When URLs Cannot Be Determined

If the exact URL cannot be confidently determined from the MCP result, note this:

```
From Snowflake documentation (search for "topic name" in docs.snowflake.com):

> "Quoted text here"
```

## General Citation Guidelines

- Always quote documentation verbatim when referencing specific rules or limitations
- Provide context around quotes to explain their relevance
- If multiple sources support a point, cite the most authoritative/specific one

