const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync(require('node:path').join(__dirname, '../assets/blockly/index.html'), 'utf8');

test('mobile and Web replies identify each start and contain only current XML', () => {
  let xml = '<xml><block type="forward"/></xml>';
  const mobile = [], web = [];
  const channel = { postMessage: json => mobile.push(JSON.parse(json)) };
  const context = {
    workspace: {},
    Blockly: { Xml: { workspaceToDom: () => ({}), domToText: () => xml } },
    window: { BlocklyCallback: channel, parent: {
      postMessage: (json, origin) => web.push({ message: JSON.parse(json), origin }),
    } },
    BlocklyCallback: channel,
  };
  vm.createContext(context);
  const get = html.match(/function getCommandsJson\(\) \{[\s\S]*?\n    \}/)[0];
  const send = html.match(/window\.sendCommandsToFlutter = function\(bridgeId, targetOrigin, requestId\) \{[\s\S]*?\n    \}/)[0];
  vm.runInContext(get + ';' + send, context);
  context.window.sendCommandsToFlutter('editor', 'https://app.test', 1);
  xml = '<xml><block type="jump_up"/></xml>';
  context.window.sendCommandsToFlutter('editor', 'https://app.test', 2);
  for (const replies of [mobile, web.map(item => item.message)]) {
    assert.deepEqual(replies.map(item => item.requestId), [1, 2]);
    assert.equal(JSON.parse(replies[1].json).xml, xml);
    assert.equal(replies[1].bridgeId, 'editor');
  }
  assert.equal(web[1].origin, 'https://app.test');
});
