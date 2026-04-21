const {
  clickRunUntilOneMonth,
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

    const { before, after } = await clickRunUntilOneMonth(page);
    console.log(`Best before date changed:`);
    console.log(`  Before: ${before.dateText}`);
    console.log(`  After:  ${after.dateText}`);
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
