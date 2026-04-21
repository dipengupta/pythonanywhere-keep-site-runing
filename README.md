# PythonAnywhere Keep Site Running

Playwright scripts for PythonAnywhere:

- `npm run extend` logs in, opens the Web tab, clicks "Run until 1 month from today", verifies that the best-before date changed, then logs out.
- `npm run get-date` logs in, opens the Web tab, reads the "This site will be disabled on ..." line, then logs out.

## Setup

```bash
npm install
npm run install:browsers
cp .env.example .env
```

Edit `.env`:

```bash
PYTHONANYWHERE_USERNAME=your-username
PYTHONANYWHERE_PASSWORD=your-password
```

If your PythonAnywhere account has multiple web apps, also set:

```bash
PYTHONANYWHERE_WEBAPP_NAME=yourusername.pythonanywhere.com
```

## Commands

Read the current best-before date:

```bash
npm run get-date
```

Extend the app by clicking "Run until 1 month from today":

```bash
npm run extend
```

Run the scheduled wrapper manually:

```bash
npm run extend:scheduled
```

That wrapper:

- runs at most once every 15 days after the previous successful extend
- runs `npm run get-date` first
- runs `npm run extend` only if `npm run get-date` exits successfully and returns output
- writes logs to `logs/extend-if-due.log`

Install the cron job:

```cron
0 9 * * * PATH=/home/dipen/.nvm/versions/node/v22.19.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin /usr/bin/env bash /home/dipen/Desktop/codebases/pythonanywhere-keep-site-runing/scripts/extend-if-due.sh
```

The cron job checks daily at 9:00 AM. The wrapper performs the 15-day interval check, so if an extend fails it will retry on the next daily cron run instead of waiting another 15 days.

Run visibly while debugging:

```bash
HEADLESS=false SLOW_MO_MS=250 npm run get-date
HEADLESS=false SLOW_MO_MS=250 npm run extend
```
