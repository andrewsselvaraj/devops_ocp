#!/usr/bin/env bash
# Connects an app's GitHub repo to its OpenShift BuildConfig. Run once per app (needs `oc` and `gh` logged in).
# Usage: scripts/setup-ci.sh <app> <github-owner/repo>
#   e.g. scripts/setup-ci.sh neet-chat andrewsselvaraj/NEET_CHAT
#
# 1. Allows webhook calls into the project (cluster/webhook-access.yaml).
# 2. Creates the <app>-webhook secret the BuildConfig's Generic trigger refers to (if missing).
# 3. Stores the full webhook URL as the OCP_BUILD_WEBHOOK secret in the GitHub repo.
set -euo pipefail

app="${1:?usage: $0 <app> <owner/repo>}"
repo="${2:?usage: $0 <app> <owner/repo>}"
root="$(cd "$(dirname "$0")/.." && pwd)"

oc apply -f "$root/cluster/webhook-access.yaml"

if ! oc get secret "$app-webhook" >/dev/null 2>&1; then
  oc create secret generic "$app-webhook" \
    --from-literal=WebHookSecretKey="$(openssl rand -hex 20)"
fi

key="$(oc get secret "$app-webhook" -o jsonpath='{.data.WebHookSecretKey}' | base64 -d)"
url="$(oc whoami --show-server)/apis/build.openshift.io/v1/namespaces/$(oc project -q)/buildconfigs/$app/webhooks/$key/generic"

printf '%s' "$url" | gh secret set OCP_BUILD_WEBHOOK --repo "$repo"
echo "OCP_BUILD_WEBHOOK set on $repo; pushes to main now deploy $app after tests pass."
