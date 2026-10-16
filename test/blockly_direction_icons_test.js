const { test } = require('node:test');
const assert = require('node:assert/strict');
const directionIcon = require('../assets/blockly/direction_icons.js');

for (const [direction, rotation] of Object.entries({ right: 0, down: 90, left: 180, up: 270 })) {
  test(`${direction} uses a large high-contrast vector arrow in the correct direction`, () => {
    const uri = directionIcon(direction);
    assert.ok(uri.startsWith('data:image/svg+xml;charset=utf-8,'));
    const svg = decodeURIComponent(uri.substring(uri.indexOf(',') + 1));
    assert.ok(svg.includes('width="36" height="36"'));
    assert.ok(svg.includes('fill="#ffffff"'));
    assert.ok(svg.includes('fill="#102a43"'));
    assert.ok(svg.includes(`rotate(${rotation} 18 18)`));
  });
}

test('unknown directions are not silently displayed as a different arrow', () => {
  assert.throws(() => directionIcon('unknown'), /Unknown block direction/);
});
