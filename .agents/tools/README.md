# Vault tools

Tools in this directory operate on the Markdown vault or produce disposable
derived views. They must not turn generated indexes, graphs, caches, or
databases into a second source of truth.

The Markdown graph utility reads frontmatter, Markdown links, and wikilinks,
then emits deterministic JSON or Graphviz DOT on demand.