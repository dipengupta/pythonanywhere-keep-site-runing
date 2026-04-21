const fs = require("node:fs");
const path = require("node:path");
require("dotenv").config();
const { chromium } = require("playwright");

const BASE_URL = (process.env.PYTHONANYWHERE_BASE_URL || "https://www.pythonanywhere.com").replace(/\/$/, "");
const USERNAME = process.env.PYTHONANYWHERE_USERNAME;
const PASSWORD = process.env.PYTHONANYWHERE_PASSWORD;
const WEBAPP_NAME = process.env.PYTHONANYWHERE_WEBAPP_NAME;
const HEADLESS = process.env.HEADLESS !== "false";
const SLOW_MO_MS = Number(process.env.SLOW_MO_MS || 0);
const AUTH_DIR = path.join(process.cwd(), ".auth");
const STORAGE_STATE = path.join(AUTH_DIR, "pythonanywhere.json");
const BEST_BEFORE_PATTERN = /This site will be disabled on\s+([A-Za-z]+,?\s+\d{1,2}\s+[A-Za-z]+\s+\d{4})/i;

function requireConfig() {
  if (!USERNAME) {
    throw new Error("Missing PYTHONANYWHERE_USERNAME. Add it to .env or export it before running the script.");
  }
}

async function launchBrowser() {
  const browser = await chromium.launch({ headless: HEADLESS, slowMo: SLOW_MO_MS });
  const contextOptions = { viewport: { width: 1280, height: 900 } };

  if (fs.existsSync(STORAGE_STATE)) {
    contextOptions.storageState = STORAGE_STATE;
  }

  const context = await browser.newContext(contextOptions);
  const page = await context.newPage();
  page.setDefaultTimeout(15000);
  return { browser, context, page };
}

function webAppsUrl() {
  return `${BASE_URL}/user/${encodeURIComponent(USERNAME)}/webapps/`;
}

async function loginIfNeeded(page, context) {
  await page.goto(webAppsUrl(), { waitUntil: "domcontentloaded" });

  if (await isOnWebAppsPage(page)) {
    return;
  }

  if (!PASSWORD) {
    throw new Error("Missing PYTHONANYWHERE_PASSWORD. Add it to .env or export it before running the script.");
  }

  await page.goto(`${BASE_URL}/login/`, { waitUntil: "domcontentloaded" });

  const usernameInput = page
    .locator('input[name="auth-username"], input[name="username"], input[id*="username"], input[type="text"]')
    .first();
  const passwordInput = page
    .locator('input[name="auth-password"], input[name="password"], input[id*="password"], input[type="password"]')
    .first();

  await usernameInput.fill(USERNAME);
  await passwordInput.fill(PASSWORD);

  const submit = page
    .getByRole("button", { name: /log in|login|sign in/i })
    .first();

  await Promise.all([
    page.waitForLoadState("domcontentloaded"),
    submit.click()
  ]);

  await page.goto(webAppsUrl(), { waitUntil: "domcontentloaded" });

  if (!(await isOnWebAppsPage(page))) {
    throw new Error(
      "Login did not reach the PythonAnywhere Web tab. Check credentials, 2FA, or whether the page layout changed."
    );
  }

  fs.mkdirSync(AUTH_DIR, { recursive: true });
  await context.storageState({ path: STORAGE_STATE });
}

async function isOnWebAppsPage(page) {
  return page.url().includes(`/user/${encodeURIComponent(USERNAME)}/webapps/`) &&
    !(await page.locator('input[type="password"]').first().isVisible().catch(() => false));
}

async function openWebTab(page) {
  await page.goto(webAppsUrl(), { waitUntil: "domcontentloaded" });

  if (WEBAPP_NAME) {
    const appLink = page.getByRole("link", { name: new RegExp(escapeRegExp(WEBAPP_NAME), "i") }).first();
    if (await appLink.isVisible().catch(() => false)) {
      await Promise.all([
        page.waitForLoadState("domcontentloaded"),
        appLink.click()
      ]);
    }
  }

  await page.waitForLoadState("networkidle").catch(() => {});
}

async function getBestBeforeLine(page) {
  const bestBeforeHeading = page.getByText(/best before date/i).first();
  await bestBeforeHeading.waitFor({ state: "visible" });

  await page.getByText(/this site will be disabled on/i).first().waitFor({ state: "visible" });

  const pageText = normalizeSpace(await page.locator("body").innerText());
  const match = pageText.match(BEST_BEFORE_PATTERN);
  if (!match) {
    throw new Error('Could not find a "This site will be disabled on ..." date on the Web tab.');
  }

  return `This site will be disabled on ${match[1].trim()}`;
}

async function getBestBeforeDate(page) {
  const line = await getBestBeforeLine(page);
  const match = line.match(BEST_BEFORE_PATTERN);
  if (!match) {
    throw new Error(`Could not parse the best-before date from: "${line}"`);
  }
  return { line, dateText: match[1].trim() };
}

async function clickRunUntilOneMonth(page) {
  const before = await getBestBeforeDate(page);
  const button = page
    .getByRole("button", { name: /run until .*1 month from today/i })
    .or(page.getByRole("link", { name: /run until .*1 month from today/i }))
    .or(page.locator('input[type="submit"][value*="Run until"]'))
    .first();

  await button.waitFor({ state: "visible" });

  await Promise.all([
    page.waitForLoadState("domcontentloaded").catch(() => {}),
    button.click()
  ]);

  await page.waitForFunction(
    (oldDateText) => {
      const text = document.body.innerText.replace(/\s+/g, " ");
      const match = text.match(/This site will be disabled on\s+([A-Za-z]+,?\s+\d{1,2}\s+[A-Za-z]+\s+\d{4})/i);
      return match && match[1].trim() !== oldDateText;
    },
    before.dateText,
    { timeout: 15000 }
  );

  const after = await getBestBeforeDate(page);
  if (after.line === before.line || after.dateText === before.dateText) {
    throw new Error(`The best-before date did not change. Before: "${before.line}". After: "${after.line}".`);
  }

  return { before, after };
}

async function logout(page) {
  const logoutLink = page
    .getByRole("link", { name: /log out|logout/i })
    .or(page.getByRole("button", { name: /log out|logout/i }))
    .first();

  if (await logoutLink.isVisible().catch(() => false)) {
    await Promise.all([
      page.waitForLoadState("domcontentloaded").catch(() => {}),
      logoutLink.click()
    ]);
  } else {
    await page.goto(`${BASE_URL}/logout/`, { waitUntil: "domcontentloaded" }).catch(() => {});
  }

  if (fs.existsSync(STORAGE_STATE)) {
    fs.rmSync(STORAGE_STATE);
  }
}

function normalizeSpace(value) {
  return value.replace(/\s+/g, " ").trim();
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

module.exports = {
  clickRunUntilOneMonth,
  getBestBeforeDate,
  launchBrowser,
  loginIfNeeded,
  logout,
  openWebTab,
  requireConfig
};
