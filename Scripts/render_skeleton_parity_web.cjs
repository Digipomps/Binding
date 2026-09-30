// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors
// Render the SAME frozen skeleton/root as SkeletonSnapshotRenderXCTest.
// This is the standard light Porthole host, not a claim about product-specific CSS.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { createRequire } = require('node:module');

async function main() {
  const args = Object.fromEntries(Array.from({length: (process.argv.length - 2) / 2}, (_, i) =>
    [process.argv[2 + i * 2], process.argv[3 + i * 2]]));
  for (const key of ['--cellscaffold', '--playwright-package', '--corpus', '--output']) {
    if (!args[key]) throw new Error(`Required: ${key}`);
  }
  const scaffold = path.resolve(args['--cellscaffold']);
  const corpus = path.resolve(args['--corpus']);
  const output = path.resolve(args['--output']);
  const { chromium } = createRequire(path.resolve(args['--playwright-package']))('@playwright/test');
  fs.mkdirSync(output, { recursive: false });
  const assets = new Map([
    ['/css/porthole-webo.css', [path.join(scaffold, 'Public/css/porthole-webo.css'), 'text/css']],
    ['/js/skeleton-runtime.js', [path.join(scaffold, 'Public/js/skeleton-runtime.js'), 'application/javascript']],
  ]);
  const assetHashes = Object.fromEntries([...assets].map(([url, [file]]) =>
    [url, crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')]));
  const browser = await chromium.launch({ headless: true });
  const results = [];
  try {
    for (const name of fs.readdirSync(corpus).sort()) {
      const dir = path.join(corpus, name);
      if (!fs.existsSync(path.join(dir, 'skeleton.json'))) continue;
      const read = file => JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
      const skeleton = read('skeleton.json');
      const root = read('root.json');
      const viewport = read('viewport.json');
      const surface = read('surface.json');
      const context = await browser.newContext({ viewport, deviceScaleFactor: 2, colorScheme: 'light' });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(String(error)));
      await page.route('**/*', async route => {
        const url = new URL(route.request().url());
        if (url.origin !== 'http://skeleton-parity.test') return route.abort();
        if (url.pathname === '/') {
          return route.fulfill({contentType: 'text/html', body: `<!doctype html><html><head>
            <meta charset="utf-8"><link rel="stylesheet" href="/css/porthole-webo.css">
            <style>body { background: ${surface.backgroundHex}; }
              .parity-frame { padding: ${surface.padding}px; }
              #root { max-width: ${surface.contentMaxWidth}px; margin: 0 auto; }
            </style></head><body><main class="parity-frame"><div id="root"></div></main>
            <script src="/js/skeleton-runtime.js"></script></body></html>`});
        }
        const asset = assets.get(url.pathname);
        return asset ? route.fulfill({path: asset[0], contentType: asset[1]}) : route.abort();
      });
      await page.goto('http://skeleton-parity.test/');
      await page.evaluate(({skeleton, root}) => {
        window.__parityActions = [];
        window.__parityRenderer = window.HavenSkeletonRuntime.createRenderer({
          rootElement: document.getElementById('root'), skeleton,
          onAction: (...args) => window.__parityActions.push(args),
        });
        window.__parityRenderer.update(root);
      }, {skeleton, root});
      await page.evaluate(() => document.fonts.ready);
      const images = await page.locator('#root img').evaluateAll(async nodes => Promise.all(nodes.map(async node => {
        let decodeError = null;
        try { await node.decode(); } catch (error) { decodeError = String(error); }
        const result = {naturalWidth: node.naturalWidth, naturalHeight: node.naturalHeight,
          box: node.getBoundingClientRect().toJSON(), decodeError, sampledRGBA: []};
        if (!decodeError && node.naturalWidth > 0 && node.naturalHeight > 0) {
          const canvas = document.createElement('canvas');
          canvas.width = node.naturalWidth; canvas.height = node.naturalHeight;
          const context = canvas.getContext('2d');
          try {
            context.drawImage(node, 0, 0);
            result.sampledRGBA = [[.25,.25],[.75,.25],[.25,.75],[.75,.75]].map(([x,y]) =>
              [...context.getImageData(Math.floor(x*canvas.width), Math.floor(y*canvas.height), 1, 1).data]);
          } catch (error) { result.sampleError = String(error); }
        }
        return result;
      })));
      for (const img of images) {
        if (img.decodeError || !img.naturalWidth || !img.naturalHeight || img.box.width <= 0 || img.box.height <= 0)
          errors.push('Image failed to decode or has no visible area');
      }
      const expectedRasterPath = path.join(dir, 'expected-raster.json');
      if (fs.existsSync(expectedRasterPath)) {
        const expectedRaster = JSON.parse(fs.readFileSync(expectedRasterPath));
        for (const expected of expectedRaster) {
          if (!images.some(img => img.sampledRGBA.some(pixel =>
            pixel[3] > 240 && expected.rgb.every((value, i) => Math.abs(pixel[i] - value) <= expected.tolerance))))
            errors.push(`Missing image sample color ${expected.rgb.join(',')}`);
        }
      }
      const content = await page.locator('#root').innerText();
      const fieldValues = await page.locator('#root input, #root textarea').evaluateAll(nodes => nodes.map(n => n.value));
      const visible = [content, ...fieldValues].join('\n');
      const expected = read('expected-text.json');
      const missingExpectedText = expected.filter(value => !visible.includes(value));
      const geometry = await page.locator('#root').evaluate(node => ({
        box: node.getBoundingClientRect().toJSON(), scrollWidth: node.scrollWidth, clientWidth: node.clientWidth,
      }));
      const controls = await page.locator('#root button, #root input, #root textarea').evaluateAll(nodes => nodes.map(node => {
        const style = getComputedStyle(node);
        return {tag: node.tagName, text: node.textContent, box: node.getBoundingClientRect().toJSON(),
          font: style.font, color: style.color, background: style.background, padding: style.padding,
          border: style.border, borderRadius: style.borderRadius, boxSizing: style.boxSizing};
      }));
      await page.screenshot({path: path.join(output, name + '.png'), fullPage: false});
      const result = {name, host: 'porthole-webo.css light baseline', viewport, deviceScaleFactor: 2,
        materialized: false, styleNormalizationApplied: false, content, fieldValues, expectedTextCount: expected.length,
        missingExpectedText, errors, geometry, controls, images, assetHashes};
      fs.writeFileSync(path.join(output, name + '.json'), JSON.stringify(result, null, 2) + '\n');
      results.push(result);
      await context.close();
    }
  } finally { await browser.close(); }
  const failed = results.filter(r => r.errors.length || r.missingExpectedText.length).map(r => r.name);
  const rasterOnlyNames = results.filter(r => r.expectedTextCount === 0).map(r => r.name);
  fs.writeFileSync(path.join(output, 'summary.json'), JSON.stringify({rendered: results.length, failed, rasterOnlyNames, assetHashes}, null, 2) + '\n');
  console.log(JSON.stringify({rendered: results.length, failed, output}));
  if (!results.length || failed.length) process.exitCode = 1;
}
main().catch(error => { console.error(error); process.exitCode = 1; });
