const { test } = require('node:test');
const assert = require('node:assert/strict');
const Blockly = require('../assets/blockly/blockly_compressed.js');
const Flyout = require('../assets/blockly/responsive_flyout.js')(Blockly);

function fixture(width, blockWidth = 240, scale = 0.8) {
  const flyout = Object.create(Flyout.prototype);
  flyout.targetWorkspace = {
    scale,
    getInjectionDiv: () => ({ clientWidth: width }),
  };
  flyout.width_ = 275;
  // Normally initialized by Blockly's constructor (skipped in this DOM-free fixture).
  flyout.MARGIN = 8;
  flyout.getContents = () => [{
    getElement: () => ({
      getBoundingRectangle: () => ({ getWidth: () => blockWidth }),
    }),
  }];
  return flyout;
}

for (const width of [288, 344, 432, 599]) {
  test(`toolbox reserves exactly half of a ${width}px editor`, () => {
    const flyout = fixture(width);
    assert.equal(flyout.getWidth(), width / 2);
    const scale = flyout.getFlyoutScale();
    assert.ok(scale > 0 && scale <= 0.8);
    const content = (240 + flyout.MARGIN * 1.5 + 16) * scale;
    assert.ok(content + Blockly.Scrollbar.scrollbarThickness <= width / 2 + 0.001);
  });
}

test('larger blocks shrink further instead of taking over the workspace', () => {
  assert.ok(fixture(344, 500).getFlyoutScale() < fixture(344, 150).getFlyoutScale());
});

test('wide desktop editor retains Blockly natural sizing', () => {
  const flyout = fixture(800, 240, 1);
  assert.equal(flyout.getWidth(), 275);
  assert.equal(flyout.getFlyoutScale(), 1);
});

test('orientation changes recalculate the split without changing blocks', () => {
  const flyout = fixture(344);
  const content = flyout.getContents();
  assert.equal(flyout.getWidth(), 172);
  flyout.targetWorkspace.getInjectionDiv = () => ({ clientWidth: 500 });
  assert.equal(flyout.getWidth(), 250);
  assert.equal(flyout.getContents()[0].getElement().getBoundingRectangle().getWidth(),
    content[0].getElement().getBoundingRectangle().getWidth());
});

test('zooming out cannot make the toolbox scale larger than the workspace', () => {
  assert.ok(fixture(344, 150, 0.3).getFlyoutScale() <= 0.3);
});
