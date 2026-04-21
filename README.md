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

Run visibly while debugging:

```bash
HEADLESS=false SLOW_MO_MS=250 npm run get-date
HEADLESS=false SLOW_MO_MS=250 npm run extend
```
