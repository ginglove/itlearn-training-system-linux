# ITLearn Enterprise Platform - Online Quiz & Hybrid Coding System

A secure, high-performance web platform for hosting software testing exams, quizzes, and automated multi-language code execution assessments. Built with Next.js App Router, Tailwind CSS v4, Drizzle ORM, PostgreSQL, and local Redis.

---

## Key Features

- **Interactive Student Exam Workspace:** Real-time countdown timer, side-by-side multiple choice selections, and a full-featured code editor.
- **Asynchronous Code Execution Queue:** Student code submissions are pushed to a local Redis queue and graded asynchronously against test cases.
- **Teacher / Admin Dashboard:** Manage questions (add, edit, delete), assign exams, review focus loss analytics, monitor live student exam progress, and grade history.
- **Anti-Cheat Monitoring:** Captures browser tab focus switches and triggers alerts in the monitor screen.
- **Bespoke UI styling:** Premium dark glassmorphic components, Bricolage Grotesque display headers, Plus Jakarta Sans text, and custom background radial glows matching the ITLearn brand design.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Next.js 16 (React 19, TypeScript) |
| Styling | Tailwind CSS v4, Framer Motion |
| Database | PostgreSQL (local, via `postgres` driver) |
| ORM | Drizzle ORM |
| Cache / Queue | Redis (local, via `ioredis`) |
| Authentication | JWT stored in secure HTTP-only cookies |
| Hosting | Local server (`next start`) |
| Cron Worker | `npm run worker` (node-cron, runs every minute) |
| Code Execution | Piston API (external sandboxed executor) |

---

## Prerequisites

Before starting, ensure these are installed on your server:

- **Node.js 20+** — [nodejs.org](https://nodejs.org/)
- **PostgreSQL 15+** — [postgresql.org](https://www.postgresql.org/)
- **Redis 7+** — [redis.io](https://redis.io/)

Start Redis and PostgreSQL services:

```bash
# macOS (Homebrew)
brew services start postgresql
brew services start redis

# Linux (systemd)
sudo systemctl start postgresql
sudo systemctl start redis
```

Create a PostgreSQL database:

```bash
psql -U postgres -c "CREATE DATABASE itlearn;"
```

---

## Local Server Setup

### 1. Configure Environment Variables

Create a `.env` file in the project root:

```env
# Local PostgreSQL connection string
DATABASE_URL="postgresql://username:password@127.0.0.1:5432/itlearn"

# JWT secret — must be set; generate with: openssl rand -hex 32
JWT_SECRET="your_long_random_secret_here"

# Local Redis URL (default shown — change only if Redis runs on a different port/host)
REDIS_URL="redis://127.0.0.1:6379"

# Internal cron secret — any secret string; must match what the worker sends
INTERNAL_CRON_SECRET="your-cron-auth-secret-token"

# The base URL of this server (used by the worker to call the internal API)
APP_URL="http://localhost:3000"

# Optional: override the default Piston API endpoint
# PISTON_API_URL="https://emkc.org/api/v2/piston"
```

> **Note:** `JWT_SECRET` and `INTERNAL_CRON_SECRET` are required. The app throws an error at startup if either is missing.

### 2. Install Dependencies

```bash
npm install
```

### 3. Initialize Database Schema

Applies the full schema from `init.sql` to your local PostgreSQL database:

```bash
npm run db:setup
```

### 4. Seed Database

Inserts default teacher, student accounts, settings, exam configurations, and test cases:

```bash
npm run seed
```

> Only run seed once. Re-running on a populated database will cause duplicate key errors.

### 5. Build the App

```bash
npm run build
```

### 6. Start the App and Worker

You need **two terminal processes** running simultaneously:

**Terminal 1 — Next.js app server:**
```bash
npm start
```

**Terminal 2 — Code execution worker (cron):**
```bash
npm run worker
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## Default Seed Credentials

| Role | Username | Password |
|---|---|---|
| Teacher / Admin | `teacher_admin` | `Teacher@123!` |

> All seeded accounts require a password change on first login (enforced by platform settings).

---

## Running in Development Mode

For development with hot reload, use `next dev` instead of `next start`:

```bash
# Terminal 1
npm run dev

# Terminal 2
npm run worker
```

---

## Process Management with PM2 (Production)

For production deployments, use [PM2](https://pm2.keymetrics.io/) to keep processes alive and auto-restart on crash:

```bash
npm install -g pm2

# Start Next.js app
pm2 start "npm start" --name itlearn-app

# Start the code execution worker
pm2 start "npm run worker" --name itlearn-worker

# Save process list for auto-start on reboot
pm2 save
pm2 startup
```

View logs:

```bash
pm2 logs itlearn-app
pm2 logs itlearn-worker
```

---

## Database Schema Operations

| Script | Command | Description |
|---|---|---|
| Apply schema | `npm run db:setup` | Reads `init.sql` and applies it to `DATABASE_URL` |
| Seed data | `npm run seed` | Inserts default users, exams, and questions |

---

## How the Code Execution Worker Runs

The file `scripts/worker.ts` is a local cron script powered by `node-cron`:

```
npm run worker
      │  (every minute)
      ▼
scripts/worker.ts
      │  POST /api/v1/internal/execute-code
      │  Authorization: Bearer <INTERNAL_CRON_SECRET>
      ▼
Next.js API Route
      │  rpop("code_execution_queue")  ← Local Redis
      │  execute test cases via Piston API
      │  UPDATE submission_details     ← Local PostgreSQL
      ▼
Done
```

The worker must be running alongside the Next.js app for async code grading to work.

---

## Architecture Overview

```
Browser
  │
  ▼
Next.js App (npm start — port 3000)
  │
  ├── Pages & API Routes
  │     ├── Auth (JWT in HTTP-only cookies, IP-bound)
  │     ├── Teacher APIs  (exams, questions, monitor, settings)
  │     └── Student APIs
  │           ├── auto-save → upserts draft answers to PostgreSQL (transactional)
  │           ├── submit   → grades quiz + code, writes final result to PostgreSQL
  │           └── run-code → executes sample test cases via Piston API
  │
  ├── Local PostgreSQL (standard TCP connection via postgres driver)
  │
  ├── Local Redis (standard TCP via ioredis — queue for async code execution)
  │
  └── scripts/worker.ts (npm run worker — every 1 min)
        └── Pops job from Redis → Piston API → writes result to PostgreSQL
```

---

## Environment Variables Reference

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `JWT_SECRET` | Yes | Secret for signing JWTs. Generate: `openssl rand -hex 32` |
| `INTERNAL_CRON_SECRET` | Yes | Shared secret between the worker and the internal API route |
| `REDIS_URL` | No | Redis connection URL. Defaults to `redis://127.0.0.1:6379` |
| `APP_URL` | No | Base URL the worker uses to call the internal API. Defaults to `http://localhost:3000` |
| `PISTON_API_URL` | No | Override the Piston code execution API. Defaults to `https://emkc.org/api/v2/piston` |
