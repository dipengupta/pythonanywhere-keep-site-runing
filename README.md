# PythonAnywhere Keep Site Running

Playwright scripts for PythonAnywhere:

- `npm run extend` logs in, opens the Web tab, clicks "Run until 1 month from today", verifies that the best-before date changed, then logs out.
- `npm run get-date` logs in, opens the Web tab, reads the "This site will be disabled on ..." line, then logs out.

## Setup

```bash
npm install
npm run install:browsers
```

### Single account

```bash
cp .env.example .env.myaccount
```

Edit `.env.myaccount`:

```bash
PYTHONANYWHERE_USERNAME=your-username
PYTHONANYWHERE_PASSWORD=your-password
```

### Multiple accounts

Create one `.env.<name>` file per account (the name is just a label used in logs):

```bash
cp .env.example .env.alice
cp .env.example .env.bob
```

Fill in the credentials in each file. The automated wrapper (`extend-all-accounts.sh`) discovers all `.env.*` files automatically, so no other configuration is needed.

If a PythonAnywhere account has multiple web apps, also set in that account's env file:

```bash
PYTHONANYWHERE_WEBAPP_NAME=yourusername.pythonanywhere.com
```

## Commands

These commands read from `.env` by default. To run them for a specific account file, export the vars first:

```bash
set -a; source .env.alice; set +a
npm run get-date
npm run extend
```

Read the current best-before date:

```bash
npm run get-date
```

Extend the app by clicking "Run until 1 month from today":

```bash
npm run extend
```

Run the scheduled wrapper manually (single account):

```bash
ENV_FILE=.env.alice npm run extend:scheduled
```

Run the scheduled wrapper for all accounts:

```bash
bash scripts/extend-all-accounts.sh
```

## How the cron job works

The cron job fires **daily at 9:00 AM** and runs `extend-all-accounts.sh`, which:

1. Finds every `.env.*` file in the project root (skipping `.env.example`)
2. For each account, runs `extend-if-due.sh`, which:
   - Skips the extend if fewer than **15 days** have passed since the last successful run (checked per account)
   - Runs `npm run get-date` first; skips the extend if it fails or returns no output
   - Runs `npm run extend` only when everything looks good
   - Writes timestamped, verbose logs to `logs/extend-if-due-<username>.log`
3. Logs a summary of all accounts to `logs/extend-all-accounts.log`

Because the 15-day check is separate from the daily cron schedule, if an extend fails it will automatically retry on the next daily run rather than waiting another 15 days.

### Install the cron job

```bash
crontab -e
```

Add this line (adjust the Node path to match your environment — run `which node` to find it):

```cron
0 9 * * * PATH=/home/dipen/.nvm/versions/node/v22.19.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin /usr/bin/env bash /home/dipen/Desktop/codebases/pythonanywhere-keep-site-runing/scripts/extend-all-accounts.sh
```

### Log files

| File | Contents |
|------|----------|
| `logs/extend-all-accounts.log` | Top-level summary: which accounts ran and their result |
| `logs/extend-if-due-<username>.log` | Per-account detail: timing, dates, success/failure |

### State files

Each account tracks when it last extended in `.cron-state/last-extend-success-epoch-<username>`. Delete this file for an account to force an extend on the next cron run.

## Debugging

Run with a visible browser and slowed-down interactions:

```bash
set -a; source .env.alice; set +a
HEADLESS=false SLOW_MO_MS=250 npm run get-date
HEADLESS=false SLOW_MO_MS=250 npm run extend
```
