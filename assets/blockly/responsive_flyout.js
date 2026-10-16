// Use Blockly's own sizing/positioning so visual and drag coordinates agree.
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory;
  } else {
    root.LifePilotHalfWidthFlyout = factory(root.Blockly);
  }
})(globalThis, function (Blockly) {
  return class LifePilotHalfWidthFlyout extends Blockly.VerticalFlyout {
    getCompactWidth() {
      const target = this.getTargetWorkspace();
      const width = target && target.getInjectionDiv().clientWidth;
      return width > 0 && width < 600 ? width / 2 : null;
    }

    getWidth() {
      return this.getCompactWidth() ?? super.getWidth();
    }

    getFlyoutScale() {
      const baseScale = super.getFlyoutScale();
      const halfWidth = this.getCompactWidth();
      const contents = this.getContents();
      if (halfWidth === null || !contents.length) return baseScale;
      const widest = contents.reduce((width, item) => Math.max(
        width, item.getElement().getBoundingRectangle().getWidth()
      ), 0);
      // Include margins, connector tabs and the flyout's native scrollbar.
      const padding = this.MARGIN * 1.5 + 16;
      const available = Math.max(1, halfWidth - Blockly.Scrollbar.scrollbarThickness);
      return Math.min(baseScale, 0.8, available / (widest + padding));
    }
  };
});
