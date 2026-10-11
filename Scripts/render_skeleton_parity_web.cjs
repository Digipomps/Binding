// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors
// Render the SAME frozen skeleton/root as SkeletonSnapshotRenderXCTest.
// Reproduce the standard Porthole host styles and its product classification.
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
    ['/css/admin-skeleton.css', [path.join(scaffold, 'Public/css/admin-skeleton.css'), 'text/css']],
    ['/js/skeleton-runtime.js', [path.join(scaffold, 'Public/js/skeleton-runtime.js'), 'application/javascript']],
  ]);
  const assetHashes = Object.fromEntries([...assets].map(([url, [file]]) =>
    [url, crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')]));
  const hostSource = fs.readFileSync(path.join(scaffold, 'Public/js/porthole-webo.js'), 'utf8');
  const productStart = hostSource.indexOf('function isProductSurfaceConfigurationName(');
  const productEnd = hostSource.indexOf('\nfunction ', productStart + 1);
  if (productStart < 0 || productEnd < 0) throw new Error('Porthole product classification missing');
  const classifyProduct = new Function('configuration', 'const portholeWebState = {bootstrap: {configuration}};'
    + hostSource.slice(productStart, productEnd) + '; return isProductSurfaceConfigurationName(configuration.name);');
  assetHashes['/js/porthole-webo.js (host classification)'] = crypto.createHash('sha256').update(hostSource).digest('hex');
  const browser = await chromium.launch({ headless: true });
  const results = [];
  try {
    for (const name of fs.readdirSync(corpus).sort()) {
      const dir = path.join(corpus, name);
      if (!fs.existsSync(path.join(dir, 'skeleton.json'))) continue;
      const read = file => JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
      const skeleton = read('skeleton.json');
      const configurationFile = path.join(dir, 'configuration.json');
      const configuration = fs.existsSync(configurationFile) ? read('configuration.json') : {name, skeleton};
      const productClass = classifyProduct(configuration) ? ' product-view' : '';
      const root = read('root.json');
      const viewport = read('viewport.json');
      const surface = read('surface.json');
      const context = await browser.newContext({ viewport, deviceScaleFactor: 2, colorScheme: 'light' });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(String(error)));
      await page.route('**/*', async route => {
        const url = new URL(route.request().url());
        if (url.origin !== 'http://skeleton-parity.test') {
          // The Spatial Registry catalog explicitly specifies this public tile source.
          if (route.request().method() === 'GET' && url.origin === 'https://tile.openstreetmap.org'
              && /^\/\d+\/\d+\/\d+\.png$/.test(url.pathname)) return route.continue();
          return route.abort();
        }
        if (url.pathname === '/') {
          return route.fulfill({contentType: 'text/html', body: `<!doctype html><html><head>
            <meta charset="utf-8"><link rel="stylesheet" href="/css/porthole-webo.css"><link rel="stylesheet" href="/css/admin-skeleton.css">
            <style>body { background: ${surface.backgroundHex}; }
              .parity-frame { border: 0; border-radius: 0; height: ${viewport.height}px; }
              #root { max-width: ${surface.contentMaxWidth + 2 * surface.padding}px; margin: 0 auto; padding: ${surface.padding}px; }
            </style></head><body><main class="parity-frame canvas view-mode${productClass}"><div id="root" class="skeleton-host"></div></main>
            <script src="/js/skeleton-runtime.js"></script></body></html>`});
        }
        let asset = assets.get(url.pathname);
        // Optional map runtime is part of the real host, not a missing feature.
        if (!asset && /^\/vendor\/leaflet\/[a-zA-Z0-9/_.-]+$/.test(url.pathname) && !url.pathname.includes('..')) {
          const file = path.join(scaffold, 'Public', url.pathname);
          if (fs.existsSync(file)) {
            asset = [file, file.endsWith('.css') ? 'text/css' : file.endsWith('.js') ? 'application/javascript' : 'image/png'];
            assetHashes[url.pathname] = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
          }
        }
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
      const interactionFile = path.join(dir, 'interactions.json');
      const tabLabels = fs.existsSync(interactionFile) ? read('interactions.json') : [];
      for (const label of tabLabels) {
        const tab = page.getByRole('tab', {name: label, exact: true});
        if (await tab.count() !== 1 || !(await tab.isVisible())) errors.push(`Tab ${label}: not reachable with captured state`);
        else {
          await tab.click({timeout: 2500}).catch(error => errors.push(`Tab ${label}: ${error.message}`));
          if (await tab.getAttribute('aria-selected') !== 'true') errors.push(`Tab ${label}: not selected after click`);
        }
      }
      const actions = await page.evaluate(() => window.__parityActions.map(([keypath, payload]) => ({keypath, payload})));
      const actionsPath = path.join(dir, 'expected-actions.json');
      const canonicalJSON = value => JSON.stringify(value, (_, item) =>
        item && typeof item === 'object' && !Array.isArray(item)
          ? Object.fromEntries(Object.keys(item).sort().map(key => [key, item[key]])) : item);
      if (fs.existsSync(actionsPath) && canonicalJSON(actions) !== canonicalJSON(read('expected-actions.json')))
        errors.push('Recorded tab actions do not match the declared keypath/payload expectations');
      await page.evaluate(() => document.fonts.ready);
      if (JSON.stringify(skeleton).includes('"Visualization"')) {
        await page.waitForFunction(() => !document.querySelector('.skeleton-visualization-map')
          || document.querySelector('.leaflet-container, .skeleton-visualization-fallback'), {timeout: 10000}).catch(error => errors.push(String(error)));
      }
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
      const selectedTexts = await page.locator('#root select').evaluateAll(nodes =>
        nodes.map(node => [...node.selectedOptions].map(option => option.textContent.trim()).join(', ')));
      const selectionPath = path.join(dir, 'expected-selection.json');
      if (fs.existsSync(selectionPath)) {
        const expectedSelection = JSON.parse(fs.readFileSync(selectionPath));
        if (JSON.stringify(selectedTexts) !== JSON.stringify(expectedSelection))
          errors.push(`Expected selected options ${JSON.stringify(expectedSelection)}, saw ${JSON.stringify(selectedTexts)}`);
      }
      const visible = [content, ...fieldValues].join('\n');
      const expected = read('expected-text.json');
      const missingExpectedText = expected.filter(value => !visible.includes(value));
      const geometry = await page.locator('#root').evaluate(node => ({
        box: node.getBoundingClientRect().toJSON(), scrollWidth: node.scrollWidth, clientWidth: node.clientWidth,
      }));
      if (geometry.scrollWidth > geometry.clientWidth + 1)
        errors.push(`Horizontal overflow: ${geometry.scrollWidth}px exceeds ${geometry.clientWidth}px`);
      const diagnostics = await page.locator('.skeleton-visualization-fallback').allTextContents();
      for (const diagnostic of diagnostics) {
        // Empty-state text shares the fallback class; it is not a load failure.
        if (/could not|unsupported|not supported|requires|failed|error|mangler/i.test(diagnostic))
          errors.push(`Renderer diagnostic: ${diagnostic}`);
      }
      const controls = await page.locator('#root button, #root input, #root textarea').evaluateAll(nodes => nodes.map(node => {
        const style = getComputedStyle(node);
        return {tag: node.tagName, text: node.textContent, box: node.getBoundingClientRect().toJSON(),
          font: style.font, color: style.color, background: style.background, padding: style.padding,
          border: style.border, borderRadius: style.borderRadius, boxSizing: style.boxSizing};
      }));
      await page.screenshot({path: path.join(output, name + '.png'), fullPage: false});
      const result = {name, host: 'Porthole light host: porthole-webo.css + admin-skeleton.css; actual product classification', productClass, viewport, deviceScaleFactor: 2,
        navigationBaseURL: 'http://skeleton-parity.test/',
        materialized: false, styleNormalizationApplied: false, content, fieldValues, expectedTextCount: expected.length,
        missingExpectedText, errors, geometry, controls, diagnostics, images, selectedTexts, actions, assetHashes};
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
