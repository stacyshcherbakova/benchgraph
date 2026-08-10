#!/usr/bin/env bash
# Preview or build the documentation site locally.
#
#   ./scripts/docs.sh            # serve with live reload, on the first free port
#   ./scripts/docs.sh serve 8090 # serve on a port you choose
#   ./scripts/docs.sh build      # one-off strict build, exactly as CI runs it
#
# Creates a virtualenv under .venv-docs on first run and installs the pinned
# versions from requirements-docs.txt, so a local preview matches what GitHub
# Pages publishes. The venv is gitignored; delete it to start over.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$ROOT/.venv-docs"
REQS="$ROOT/requirements-docs.txt"

cd "$ROOT"

if [[ ! -x "$VENV/bin/mkdocs" ]]; then
  echo "Setting up the docs environment in .venv-docs (first run only)…"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet -r "$REQS"
fi

# Rebuild if the pinned requirements changed since the venv was made.
if [[ "$REQS" -nt "$VENV/bin/mkdocs" ]]; then
  echo "requirements-docs.txt changed — updating the docs environment…"
  "$VENV/bin/pip" install --quiet -r "$REQS"
fi

case "${1:-serve}" in
  build)
    # --strict matches .github/workflows/docs.yml: any broken link or missing
    # nav entry fails, rather than shipping a 404 to the published site.
    exec "$VENV/bin/mkdocs" build --strict
    ;;
  serve)
    # mkdocs dies with "Address already in use" if its default port is taken,
    # which is easy to mistake for a broken site. Pick a free one instead.
    port="${2:-}"
    if [[ -z "$port" ]]; then
      for candidate in 8000 8001 8002 8003 8080 8090; do
        if ! lsof -nP -iTCP:"$candidate" -sTCP:LISTEN >/dev/null 2>&1; then
          port="$candidate"
          break
        fi
      done
      : "${port:=8765}"
      [[ "$port" == "8000" ]] || echo "Port 8000 is in use — serving on $port instead."
    fi
    # mkdocs mounts the site under the path component of `site_url`, so with
    # site_url .../benchgraph/ the local root 302s and every page 404s unless
    # you include that prefix. Print the URL that actually works.
    base="$(sed -n 's|^site_url:[[:space:]]*https\{0,1\}://[^/]*||p' mkdocs.yml | tr -d ' ')"
    [[ "$base" == */ ]] || base="$base/"
    echo "Serving the docs at http://127.0.0.1:${port}${base} — Ctrl-C to stop."
    exec "$VENV/bin/mkdocs" serve --dev-addr "127.0.0.1:$port"
    ;;
  *)
    exec "$VENV/bin/mkdocs" "$@"
    ;;
esac
