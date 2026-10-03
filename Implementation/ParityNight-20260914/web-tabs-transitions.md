### Result
[{"name":"initial","text":"ALPHA TAB\nBETA TAB\nSECOND PANEL"},{"name":"empty","text":""},{"name":"missing","text":"One\nTwo\nSECOND PANEL"},{"name":"refreshed","text":"ALPHA TAB\nBETA TAB\nFIRST PANEL"}]
### Ran Playwright code
```js
await (async (page) => { const results=await page.evaluate(()=> { const root=document.querySelector('main'); window.parityRenderer.destroy?.(); const skeleton={Tabs:{tabsKeypath:'tabs',activeTabStateKeypath:'active',idKeypath:'id',labelKeypath:'title',panels:[{id:'one',content:[{Text:{text:'FIRST PANEL'}}]},{id:'two',content:[{Text:{text:'SECOND PANEL'}}]}]}}; const renderer=window.HavenSkeletonRuntime.createRenderer({rootElement:root,skeleton,onAction:async()=>{throw new Error('No transport in comparison')}}); const rows=[{id:'one',title:'ALPHA TAB'},{id:'two',title:'BETA TAB'}]; const cases=[{name:'initial',data:{tabs:rows,active:'two'}},{name:'empty',data:{tabs:[]}},{name:'missing',data:{}},{name:'refreshed',data:{tabs:rows,active:'one'}}]; const results=cases.map(c=>{renderer.update(c.data);return{name:c.name,text:root.innerText}}); renderer.destroy?.(); return results;}); return results; })(page);
```
