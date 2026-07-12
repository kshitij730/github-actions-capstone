# GitHub Actions Capstone — Health Check API

A minimal FastAPI service with a single `/health` endpoint, containerized with Docker and shipped through a complete, production-style GitHub Actions CI/CD pipeline: **build & test → Docker build & push → deploy (manual approval) → scheduled health monitoring**.

This project was built as the Day 48 capstone for **#90DaysOfDevOps (TrainWithShubham, Udaan Batch 11)**, bringing together workflows, secrets, Docker builds, reusable workflows, and advanced triggers learned across Day 40–47 into a single end-to-end pipeline.

![PR Pipeline](https://github.com/kshitij730/github-actions-capstone/actions/workflows/pr-pipeline.yml/badge.svg)
![Main Pipeline](https://github.com/kshitij730/github-actions-capstone/actions/workflows/main-pipeline.yml/badge.svg)
![Health Check](https://github.com/kshitij730/github-actions-capstone/actions/workflows/health-check.yml/badge.svg)

---

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Run Locally](#run-locally)
- [Pipeline Architecture](#pipeline-architecture)
- [Setup Instructions](#setup-instructions)
- [Workflows Explained](#workflows-explained)
- [Verifying the Pipeline](#verifying-the-pipeline)
- [What I'd Add Next](#what-id-add-next)

---

## Overview

The app itself is intentionally simple — one FastAPI endpoint that reports service health as JSON. The real focus of this project is the **CI/CD pipeline wrapped around it**, which mirrors how a production team would ship and monitor a service:

- Every pull request is automatically tested before merge.
- Every merge to `main` builds a fresh Docker image, pushes it to Docker Hub, and deploys — but only after manual approval.
- A scheduled job checks the deployed image's health every 12 hours, so failures don't go unnoticed.

```json
GET /health

{
  "status": "ok",
  "service": "github-actions-capstone",
  "time": "2026-07-12T10:15:32.120Z"
}
```

---

## Tech Stack

| Layer          | Tool                                   |
|----------------|------------------------------------------|
| App            | Python 3.11, FastAPI, Uvicorn           |
| Containerization | Docker                                |
| CI/CD          | GitHub Actions (reusable workflows)      |
| Registry       | Docker Hub                              |
| Deployment gate | GitHub Environments (manual approval)   |
| Monitoring     | Scheduled workflow (`cron`) + `$GITHUB_STEP_SUMMARY` |

---

## Project Structure

```text
github-actions-capstone/
│
├── app.py                  # FastAPI app with /health endpoint
├── requirements.txt        # Python dependencies
├── Dockerfile              # Container build definition
├── test_health.sh          # Test script — builds, runs, curls /health
├── README.md
│
└── .github/
    └── workflows/
        ├── reusable-build-test.yml   # Reusable: install, build, test
        ├── reusable-docker.yml       # Reusable: Docker build & push
        ├── pr-pipeline.yml           # Runs on PRs — test only
        ├── main-pipeline.yml         # Runs on push to main — full chain
        └── health-check.yml          # Scheduled health monitoring
```

---

## Run Locally

Clone the repo and run the container directly:

```bash
git clone https://github.com/kshitij730/github-actions-capstone.git
cd github-actions-capstone

docker build -t capstone-image .
docker run -p 8000:8000 capstone-image
curl http://localhost:8000/health
```

Or run the same test the CI pipeline runs:

```bash
chmod +x test_health.sh
./test_health.sh
```

Expected output:
```text
Building and starting container for test...
Curling /health endpoint...
Response: {"status":"ok","service":"github-actions-capstone","time":"..."}
Test passed
```

---

## Pipeline Architecture

```text
┌─────────────────────┐
│   PR opened/synced   │
└──────────┬───────────┘
           ▼
   build & test (reusable)
           ▼
   PR checks pass ✅  (no Docker push)


┌─────────────────────┐
│   Push to main       │
└──────────┬───────────┘
           ▼
   build & test (reusable)
           ▼
   Docker build & push  → tags: latest, sha-<short-hash>
           ▼
   deploy  (⏸ requires manual approval via production environment)


┌─────────────────────┐
│   Every 12 hours      │
└──────────┬───────────┘
           ▼
   pull latest image → run → curl /health → report to job summary
```

**Key design choice:** Docker images are only built and pushed *after* a merge to `main`, never on a pull request. This keeps the registry clean and avoids wasting a push on code that hasn't been approved yet.

---

## Setup Instructions

Follow these steps in order to get the pipeline fully working on your fork.

### 1. Fork / clone the repo

```bash
git clone https://github.com/kshitij730/github-actions-capstone.git
```

### 2. Add Docker Hub secrets

Go to **Repo → Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret name       | Value                              |
|--------------------|-------------------------------------|
| `DOCKER_USERNAME`  | Your Docker Hub username            |
| `DOCKER_TOKEN`     | A Docker Hub [access token](https://hub.docker.com/settings/security) (not your password) |

### 3. Create the `production` environment

Go to **Repo → Settings → Environments → New environment** → name it `production`.

Enable **Required reviewers** and add yourself (or a teammate) — this is what makes the `deploy` job pause and wait for manual approval instead of running automatically.

### 4. Enable Actions permissions

Go to **Repo → Settings → Actions → General → Workflow permissions** and make sure workflows have **Read and write permissions**, so job summaries and outputs work correctly.

### 5. Push and test

```bash
git checkout -b feature/test-pipeline
# make a small change
git commit -am "test: trigger pipeline"
git push origin feature/test-pipeline
```

Open a PR into `main` → the **PR pipeline** should run (test only).
Merge it → the **Main pipeline** should run the full chain and pause at `deploy` for your approval.

---

## Workflows Explained

### `reusable-build-test.yml`
Called via `workflow_call`. Installs dependencies, builds the image for testing, and runs `test_health.sh`. Outputs `passed` or `failed` so calling workflows can act on the result.

### `reusable-docker.yml`
Called via `workflow_call`. Logs into Docker Hub using secrets, builds the image, and pushes it with the given `image_name` and `tag`. Outputs the full `image_url`.

### `pr-pipeline.yml`
Triggered on `pull_request` (`opened`, `synchronize`) into `main`. Calls the build-test workflow only — **no Docker push on PRs**. A `pr-comment` job prints a pass summary once tests succeed.

### `main-pipeline.yml`
Triggered on `push` to `main`. Chains: build & test → get short commit SHA → Docker build & push (two tags: `latest` and `sha-<hash>`) → `deploy` job gated behind the `production` environment.

### `health-check.yml`
Triggered on a `schedule` (`0 */12 * * *`) plus `workflow_dispatch` for manual runs. Pulls the latest deployed image, runs it, curls `/health`, and writes a pass/fail report to `$GITHUB_STEP_SUMMARY`.

---

## Verifying the Pipeline

- ✅ Open a PR → only the build-test job runs, no image is pushed to Docker Hub
- ✅ Merge to `main` → full pipeline runs, `deploy` job shows **"Waiting for approval"**
- ✅ Approve the deployment → `deploy` step prints the deployed image URL
- ✅ Check **Actions → Health Check → Run workflow** to trigger it manually and see the summary report
- ✅ Docker Hub shows both `latest` and `sha-xxxxxxx` tags after a merge

---

## What I'd Add Next

- Slack notification when a deploy or health check fails
- Multi-environment promotion: `staging` → `production`
- Automatic rollback to the previous image if a scheduled health check fails
- A Trivy vulnerability scan as a mandatory gate before `deploy`

---

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`