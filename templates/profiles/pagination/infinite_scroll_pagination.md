# Pagination Profile — infinite_scroll_pagination

- Use the installed package version/API and the project's existing paging pattern, not stale snippets.
- Prevent duplicate next-page requests.
- Distinguish first load, next page, refresh, empty, error, and completed states as required by the active state architecture.
- Filter/search changes reset paging intentionally.
- Preserve existing items during next-page/refresh when appropriate.
