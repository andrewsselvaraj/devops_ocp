#!/usr/bin/env bash
# Applies one app's manifests to the current OpenShift project.
# Usage: scripts/deploy.sh <php-to-spring-converter|neet-chat>
set -euo pipefail

app="${1:?usage: $0 <app>}"
dir="$(cd "$(dirname "$0")/.." && pwd)/apps/$app"
[ -d "$dir" ] || { echo "Unknown app: $app" >&2; exit 1; }

if [ -f "$dir/secret.yaml" ]; then
  oc apply -f "$dir/secret.yaml"
elif ! oc get secret "$app-secrets" >/dev/null 2>&1; then
  echo "Secret $app-secrets is missing: copy $dir/secret.yaml.example to secret.yaml and fill it in." >&2
  exit 1
fi

oc apply -f "$dir"
echo "Route: https://$(oc get route "$app" -o jsonpath='{.spec.host}')"
