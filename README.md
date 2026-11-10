# devops_ocp

CI/CD and OpenShift deployment for these Spring Boot apps:

| App | Code | OpenShift build |
| --- | --- | --- |
| `php-to-spring-converter` | [php-to-spring-converter](https://github.com/andrewsselvaraj/php-to-spring-converter) | Source-to-Image (`java:openjdk-17-ubi8`) |
| `neet-chat` | [NEET_CHAT](https://github.com/andrewsselvaraj/NEET_CHAT) | `Dockerfile` in the app repo (bundles the question PDFs) |
| `election-ai` | [election_ai](https://github.com/andrewsselvaraj/election_ai) | `Dockerfile` in the app repo (Java 21; no secrets) |

## How a change reaches OpenShift

```text
push / pull request ──> GitHub Actions: mvn verify            (tests only, every branch)

push to main ──> Jenkins job deploy-<app> (polls GitHub every 5 min, or Build Now)
                   Checkout ─> Test ─> Build image ─> Rollout ─> Smoke test
                                         │               │
                              oc start-build <app>   Deployment picks up the new image
```

- Jenkins runs in the same OpenShift project and logs in with your OpenShift account.
- Each pipeline run uses a throwaway pod: `jnlp` (has `oc`, runs as the `jenkins` service account with the edit role) and `maven` (JDK and Maven: 17, or the version set for the app in `APP_JDKS` in the Jenkinsfile, e.g. 21 for `election-ai`).
- GitHub Actions only tests. It never touches the cluster and needs no secrets.

## Layout

| Path | Purpose |
| --- | --- |
| `jenkins/Jenkinsfile` | Deploy pipeline shared by all apps; the job name `deploy-<app>` selects the app |
| `jenkins/install.sh` | Installs Jenkins (`jenkins-persistent` template, 2Gi memory, 1Gi volume) and creates the jobs |
| `jenkins/create-jobs.sh` | Creates or updates the `deploy-<app>` jobs through the Jenkins API |
| `.github/workflows/maven-ci.yml` | Reusable test workflow the app repos call |
| `apps/<app>/` | Manifests: ImageStream, BuildConfig, Deployment, Service, Route, and `secret.yaml.example` if the app needs secrets |
| `apps/<app>/secret.yaml` | Your filled-in secret (git-ignored, stays on your machine) |
| `scripts/deploy.sh` | Applies one app's secret and manifests |

## Set up from scratch

Log in first with `oc login`, then:

```text
cp apps/neet-chat/secret.yaml.example apps/neet-chat/secret.yaml   # fill in the values
scripts/deploy.sh neet-chat
scripts/deploy.sh election-ai                                       # no secret needed
jenkins/install.sh
```

If Jenkins is already installed, `jenkins/create-jobs.sh election-ai` adds just the new job.

To add another app: put its manifests in `apps/<app>/`, add its repo URL to the map in `jenkins/Jenkinsfile` (and its JDK to `APP_JDKS` if not 17), and run `jenkins/create-jobs.sh <app>`.

The app repo's `.github/workflows/ci.yml`:

```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:
jobs:
  ci:
    uses: andrewsselvaraj/devops_ocp/.github/workflows/maven-ci.yml@main
    # with: { java-version: "21" }   # for Java 21 apps such as election-ai
```

## Day to day

- Deploy code: push to `main`; Jenkins picks it up within 5 minutes. Or open the job in Jenkins and click **Build Now**.
- Jenkins URL: `oc get route jenkins`.
- Change a key: edit `apps/<app>/secret.yaml`, run `oc apply -f apps/<app>/secret.yaml`, then `oc rollout restart deployment/<app>`.
- Developer Sandbox scales apps (and Jenkins) to zero after 12 hours: `oc scale deployment/<app> --replicas=1` and `oc scale dc/jenkins --replicas=1`.
