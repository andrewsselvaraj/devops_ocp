#!/usr/bin/env bash
# Installs Jenkins (Red Hat image, OpenShift login, 1Gi volume) into the current project
# and creates one pipeline job per app from jenkins/Jenkinsfile.
# Usage: jenkins/install.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

if ! oc get svc jenkins >/dev/null 2>&1; then
  oc new-app --template=openshift/jenkins-persistent \
    -p MEMORY_LIMIT=2Gi -p VOLUME_CAPACITY=1Gi -p DISABLE_ADMINISTRATIVE_MONITORS=true
fi
oc rollout status dc/jenkins --timeout=10m

"$here/create-jobs.sh"
echo "Jenkins: https://$(oc get route jenkins -o jsonpath='{.spec.host}') (log in with OpenShift)"
