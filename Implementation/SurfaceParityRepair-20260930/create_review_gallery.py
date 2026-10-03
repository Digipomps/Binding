#!/usr/bin/env python3
"""Build a local review gallery from real native/web capture artifacts."""
from pathlib import Path
import json
import argparse
import csv
import hashlib

base = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--native', default='native-acceptance-delivery')
parser.add_argument('--web', default='web-acceptance-delivery')
parser.add_argument('--corpus', default='corpus-acceptance-visual')
args = parser.parse_args()
cases = []
for directory in sorted((base / args.corpus).iterdir()):
    if not (directory / 'skeleton.json').exists():
        continue
    name = directory.name
    skeleton_bytes = (directory / 'skeleton.json').read_bytes()
    root_bytes = (directory / 'root.json').read_bytes()
    source, width = name.rsplit('-', 1)
    web_dir = args.web
    native = json.loads((base / args.native / (name + '.json')).read_text())
    web = json.loads((base / web_dir / (name + '.json')).read_text())
    raster = native.get('rasterResults', [])
    passed = (not native['missingExpectedText'] and not web['missingExpectedText'] and not web['errors']
              and all(r['matchingPixels'] >= r['expected']['minimumPixels'] for r in raster))
    cases.append(dict(name=name, source=source, width=width, passed=passed,
                      elementType=next(iter(json.loads(skeleton_bytes))),
                      skeletonSHA256=hashlib.sha256(skeleton_bytes).hexdigest(),
                      rootSHA256=hashlib.sha256(root_bytes).hexdigest(),
                      textCount=native['expectedTextCount'], rasterCount=len(raster),
                      selectedTexts=web.get('selectedTexts', []),
                      overflow=web['geometry']['scrollWidth'] > web['geometry']['clientWidth'],
                      native=args.native + '/' + name + '.png', web=web_dir + '/' + name + '.png'))
with (base / 'parity-matrix.csv').open('w', newline='') as stream:
    fields = ['name', 'elementType', 'width', 'passed', 'textCount', 'rasterCount',
              'overflow', 'selectedTexts', 'skeletonSHA256', 'rootSHA256', 'native', 'web']
    writer = csv.DictWriter(stream, fieldnames=fields, extrasaction='ignore')
    writer.writeheader()
    writer.writerows(cases)
(base / 'capture-evidence-summary.json').write_text(json.dumps({
    'scenarioCount': len(cases), 'checksPassed': sum(c['passed'] for c in cases),
    'textAssertedScenarios': sum(c['textCount'] > 0 for c in cases),
    'rasterAssertedScenarios': sum(c['rasterCount'] > 0 for c in cases),
    'captureOnlyScenarios': [c['name'] for c in cases if not c['textCount'] and not c['rasterCount']],
    'webHorizontalOverflow': [c['name'] for c in cases if c['overflow']],
    'nativeDirectory': args.native, 'webDirectory': args.web, 'corpus': args.corpus,
    'doesNotEstablish': ['pixel identity', 'all element combinations', 'general remote bridge', 'deployment'],
}, indent=2) + '\n')
data = json.dumps(cases).replace('</', '<\\/')
html = '''<!doctype html><html lang="nb"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>HAVEN – flatekontroll</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#edf1f6;color:#172033;font:16px system-ui}
header{padding:24px 28px 16px;max-width:1450px;margin:auto}h1{margin:0 0 10px;font-size:27px}
p{max-width:1000px;line-height:1.5}nav{display:flex;gap:12px;flex-wrap:wrap;align-items:center;padding:12px 0}
select,button{font:inherit;padding:9px 12px;border:1px solid #a5b4c7;border-radius:8px;background:white}
button.active{background:#173140;color:white}main{display:grid;grid-template-columns:1fr 1fr;gap:20px;padding:0 28px 28px}
figure{margin:0;min-width:0}figcaption{padding:10px 0;font-weight:600}.canvas{height:70vh;overflow:auto;background:white;border:1px solid #ced8e5;border-radius:10px}
img{display:block;width:100%;height:auto}a{color:#165a8a}#checks{font-size:14px;margin:8px 0}
@media(max-width:700px){main{grid-template-columns:1fr}.canvas{height:55vh}}
</style><header><h1>HAVEN og Porthole – samme testdata</h1>
<p>70 testscenarier fra 9 publiserte fixtures og 26 elementtyper, i to bredder.
Begge sider bruker samme opprinnelige skeleton og tilstand. Velg en flate og sammenlign de faktiske bildene.</p>
<p><strong>Avgrensning:</strong> Standard lyst Porthole-tema. Innholds- og bildekontroller er automatisert;
de beviser ikke identisk utseende, andre CSS-temaer eller handlinger gjennom den generelle fjernbroen. Lokale komponenthandlinger er testet separat med faktisk Resolver og tilgangskontroll. Native plattformkontroller kan ha andre detaljer.</p>
<nav><label>Flate <select id="scenario"></select></label>
<button data-width="compact" class="active">390 px</button><button data-width="wide">1280 px</button></nav>
<div id="checks"></div><a href="REPORT.md">Resultater og gjenstående arbeid</a></header>
<main><figure><figcaption>HAVEN · BindingSkeletonView · SwiftUI</figcaption><div class="canvas"><a id="native-link"><img id="native" alt="Faktisk native gjengivelse"></a></div></figure>
<figure><figcaption>Web · SkeletonRuntime · Porthole CSS</figcaption><div class="canvas"><a id="web-link"><img id="web" alt="Faktisk webgjengivelse"></a></div></figure></main>
<script>const cases=__DATA__;const select=document.getElementById('scenario');let width='compact';
for(const name of [...new Set(cases.map(x=>x.source))]){const option=document.createElement('option');option.value=name;option.textContent=name;select.append(option)}
select.value='form';function render(){const c=cases.find(x=>x.source===select.value&&x.width===width);
for(const key of ['native','web']){document.getElementById(key).src=c[key];document.getElementById(key+'-link').href=c[key]}
document.getElementById('checks').textContent=(c.passed?'Automatiserte kontroller passert':'En kontroll feilet')+' · '+c.textCount+' tekstforventninger · '+c.rasterCount+' rasterfarger'+(!c.textCount&&!c.rasterCount?' · Kun rasteropptak, krever visuell vurdering':'')+(c.selectedTexts.length?' · Valgt: '+c.selectedTexts.join(', '):'')+(c.overflow?' · Web: horisontalt overløp':'');}
select.addEventListener('change',render);document.querySelectorAll('button[data-width]').forEach(b=>b.addEventListener('click',()=>{width=b.dataset.width;document.querySelectorAll('button').forEach(x=>x.classList.toggle('active',x===b));render()}));render();</script></html>'''
(base / 'PARITY_REVIEW.html').write_text(html.replace('__DATA__', data))
print(json.dumps({'cases': len(cases), 'checksPassed': sum(c['passed'] for c in cases)}))
