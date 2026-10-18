// Rendu des images du jeu en PNG (nécessite Node + Playwright).
// Usage : node render.js   (depuis assets/sources)
const path = require('path');
const { chromium } = require('playwright');
const jobs = [
  { html: 'logo.html', w: 1600, h: 800, out: '../logo.png', transparent: true },
  { html: 'icon.html', w: 512, h: 512, out: '../icone.png' },
  { html: 'thumbnail.html', w: 1920, h: 1080, out: '../miniature.png' },
];
(async () => {
  const browser = await chromium.launch();
  for (const job of jobs) {
    const page = await browser.newPage({ viewport: { width: job.w, height: job.h } });
    await page.goto('file://' + path.resolve(__dirname, job.html));
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(300);
    await page.screenshot({ path: path.resolve(__dirname, job.out), omitBackground: !!job.transparent });
    await page.close();
  }
  await browser.close();
})();
