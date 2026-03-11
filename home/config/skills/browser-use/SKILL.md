---
name: browser-use
description: Expert in web browsing and visual inspection using the browser-use MCP server. Use when you need to interact with websites, scrape data, or visually verify UI layouts and designs.
---

# Browser Use Expert Skill

This skill provides specialized workflows for interacting with the web using the `browser-use` MCP server. It emphasizes visual verification through screenshots and structured data extraction.

## Core Directives

### 1. Visual Inspection First
- **Always take screenshots**: When verifying a layout, design, or the result of an action, use `mcp_browser-use_browser_screenshot`. Visual confirmation is superior to HTML analysis for UI/UX tasks.
- **Full Page vs. Viewport**: Use `full_page: true` for capturing long articles or full landing pages. Use the default (viewport) for verifying "above the fold" content or specific interactions.
- **Identify Elements**: Use `mcp_browser-use_browser_get_state` to get interactive elements and their indices before clicking or typing.

### 2. Interaction Workflow
- **Navigate**: Start with `mcp_browser-use_browser_navigate`.
- **State Check**: Use `mcp_browser-use_browser_get_state` (optionally with `include_screenshot: true`) to understand the page structure and find element indices.
- **Action**: Use `mcp_browser-use_browser_click` or `mcp_browser-use_browser_type` using the indices discovered in the state check.
- **Verify**: Always follow an action with a screenshot or a state check to confirm the expected change occurred.

### 3. Data Extraction
- **Structured Content**: Use `mcp_browser-use_browser_extract_content` for gathering specific information (e.g., "Extract all product names and prices").
- **Raw HTML**: Use `mcp_browser-use_browser_get_html` only when fine-grained DOM analysis is required that `get_state` or `extract_content` cannot handle.

### 4. Robustness & Retries
- **Agentic Recovery**: If multiple manual steps fail or the site is highly dynamic/complex, use `mcp_browser-use_retry_with_browser_use_agent`. This tool employs an autonomous agent to achieve the goal.
- **Session Management**: List active sessions with `mcp_browser-use_browser_list_sessions`. Close sessions when finished to save resources.

## Best Practices

| Scenario | Recommended Tool |
| :--- | :--- |
| **Initial Visit** | `navigate` |
| **Finding Buttons** | `get_state` |
| **Verifying Layout** | `screenshot` |
| **Scraping Lists** | `extract_content` |
| **Complex Flows** | `retry_with_browser_use_agent` |

## Interaction Protocol
1. **Goal Alignment**: Confirm the target URL and the specific information or action required.
2. **Visual Baseline**: Take an initial screenshot if the task involves UI changes.
3. **Iterative Action**: Perform one or two steps at a time, verifying the page state between each.
4. **Final Validation**: Provide a final screenshot as evidence of completion for visual tasks.
