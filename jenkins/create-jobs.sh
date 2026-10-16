#!/usr/bin/env bash
# Creates or updates the Jenkins pipeline jobs deploy-<app>, which run jenkins/Jenkinsfile from this repo.
# Authenticates to Jenkins with your OpenShift token (oc whoami -t).
# Usage: jenkins/create-jobs.sh [app ...]   (default: every app under apps/)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

url="https://$(oc get route jenkins -o jsonpath='{.spec.host}')"
auth="Authorization: Bearer $(oc whoami -t)"
jar="$(mktemp)"; trap 'rm -f "$jar"' EXIT

crumb="$(curl -fsS -c "$jar" -b "$jar" -H "$auth" "$url/crumbIssuer/api/json" \
  | sed -E 's/.*"crumbRequestField":"([^"]+)".*"crumb":"([^"]+)".*/\1:\2/; t; s/.*"crumb":"([^"]+)".*"crumbRequestField":"([^"]+)".*/\2:\1/')"

apps=("$@")
[ ${#apps[@]} -gt 0 ] || apps=($(ls "$root/apps"))

for app in "${apps[@]}"; do
  job="deploy-$app"
  config="<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin=\"workflow-job\">
  <description>Test, build and deploy $app to OpenShift. Defined in devops_ocp/jenkins/Jenkinsfile.</description>
  <keepDependencies>false</keepDependencies>
  <definition class=\"org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition\" plugin=\"workflow-cps\">
    <scm class=\"hudson.plugins.git.GitSCM\" plugin=\"git\">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig><url>https://github.com/andrewsselvaraj/devops_ocp.git</url></hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches><hudson.plugins.git.BranchSpec><name>*/main</name></hudson.plugins.git.BranchSpec></branches>
    </scm>
    <scriptPath>jenkins/Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <disabled>false</disabled>
</flow-definition>"

  if curl -fsS -o /dev/null -b "$jar" -H "$auth" "$url/job/$job/api/json" 2>/dev/null; then
    target="$url/job/$job/config.xml"
  else
    target="$url/createItem?name=$job"
  fi
  printf '%s' "$config" | curl -fsS -b "$jar" -H "$auth" -H "$crumb" -H "Content-Type: application/xml" \
    --data-binary @- "$target"
  echo "Job $job ready: $url/job/$job/"
done
