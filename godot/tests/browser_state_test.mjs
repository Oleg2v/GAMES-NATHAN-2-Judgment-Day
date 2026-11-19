import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// Run the exact embedded bridge code against a minimal DOM. Native Godot
// cannot execute JavaScriptBridge, so this catches syntax and guard failures.
const source=readFileSync(new URL('../scripts/game_menu.gd',import.meta.url),'utf8');
const template=source.match(/func _browser_state_script\(\)[\s\S]*?return """([\s\S]*?)""" % JSON\.stringify\(_browser_state\(\)\)/)?.[1];
assert.ok(template,'Embedded browser state script exists');
let checks=0;
for(const lang of ['ru','en','he']) for(const playing of [false,true]){
  const document={body:{dataset:{}},documentElement:{}};
  const script=template.replace('%s',JSON.stringify({playing,lang}));
  vm.runInNewContext(script,{document});
  assert.equal(document.body.dataset.playing,String(playing));
  assert.equal(document.body.dataset.lang,lang);
  assert.equal(document.documentElement.lang,lang);
  checks+=3;
}
const script=template.replace('%s',JSON.stringify({playing:false,lang:'ru'}));
for(const context of [{},{document:{}},{document:{body:null}},{document:{body:{}}}]){
  assert.doesNotThrow(()=>vm.runInNewContext(script,context));
  checks++;
}
console.log(`BROWSER_STATE_TESTS checks=${checks} failures=0`);
