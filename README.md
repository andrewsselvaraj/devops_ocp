# devops_ocp

CI/CD and OpenShift deployment for these Spring Boot apps:

| App | Code | OpenShift build |
| --- | --- | --- |
| `php-to-spring-converter` | [php-to-spring-converter](https://github.com/andrewsselvaraj/php-to-spring-converter) | Source-to-Image (`java:openjdk-17-ubi8`) |
| `neet-chat` | [NEET_CHAT](https://github.com/andrewsselvaraj/NEET_CHAT) | `Dockerfile` in the app repo (bundles the question PDFs) |

## How a change reaches OpenShift

```text
push to main ──> GitHub Actions: mvn verify ──(tests pass)──> POST BuildConfig webhook
                                                                    │
                          Deployment rolls out <── image pushed <── OpenShift build
```

- Pull requests and other branches run the tests only.
- GitHub holds only a webhook URL (`OCP_BUILD_WEBHOOK`), never cluster credentials. The URL can start a build and nothing else.
- No Jenkins: OpenShift's BuildConfig does the build, and the Deployment's image trigger does the rollout.

## Layout

| Path | Purpose |
| --- | --- |
| `.github/workflows/maven-ci.yml` | Reusable workflow the app repos call: test, then trigger the build |
| `apps/<app>/` | Manifests: ImageStream, BuildConfig, Deployment, Service, Route, `secret.yaml.example` |
| `apps/<app>/secret.yaml` | Your filled-in secret (git-ignored, stays on your machine) |
| `cluster/webhook-access.yaml` | Lets webhook calls into the project (OpenShift 4 blocks them by default) |
| `scripts/deploy.sh` | Applies one app's secret and manifests |
| `scripts/setup-ci.sh` | Creates the webhook secret and stores the URL in the app's GitHub repo |

## Set up an app

Log in first with `oc login` (and `gh auth login`), then:

```text
cp apps/neet-chat/secret.yaml.example apps/neet-chat/secret.yaml   # fill in the values
scripts/deploy.sh neet-chat
scripts/setup-ci.sh neet-chat andrewsselvaraj/NEET_CHAT
```

The app repo needs `.github/workflows/ci.yml`:

```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:
jobs:
  ci:
    uses: andrewsselvaraj/devops_ocp/.github/workflows/maven-ci.yml@main
    secrets: inherit
```

## Day to day

- Deploy code: merge or push to `main`. Watch it with `oc get builds -w`.
- Rebuild by hand: `oc start-build <app> --follow`.
- Change a key: edit `apps/<app>/secret.yaml`, run `oc apply -f apps/<app>/secret.yaml`, then `oc rollout restart deployment/<app>`.
- Developer Sandbox scales apps to zero after 12 hours: `oc scale deployment/<app> --replicas=1`.
