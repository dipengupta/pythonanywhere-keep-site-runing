const {
  getBestBeforeDate,
  launchBrowser,
  loginIfNeeded,
  logout,
  openWebTab,
  requireConfig
} = require("./pythonanywhere");

(async () => {
  requireConfig();
  const { browser, context, page } = await launchBrowser();

  try {
    await loginIfNeeded(page, context);
    await openWebTab(page);

    const { line, dateText } = await getBestBeforeDate(page);
    console.log(line);
    console.log(`Best before date: ${dateText}`);
  } finally {
    await logout(page).catch((error) => {
      console.warn(`Logout failed: ${error.message}`);
    });
    await browser.close();
  }
})().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});
