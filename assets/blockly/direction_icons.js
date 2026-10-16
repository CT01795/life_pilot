// Vector arrows stay sharp when Blockly scales blocks on smaller screens.
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.LifePilotDirectionIcon = factory();
  }
})(globalThis, function () {
  const rotations = { right: 0, down: 90, left: 180, up: 270 };
  return function directionIcon(direction) {
    if (!Object.prototype.hasOwnProperty.call(rotations, direction)) {
      throw new Error('Unknown block direction');
    }
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36">' +
      '<rect x="1" y="1" width="34" height="34" rx="6" fill="#ffffff" stroke="#102a43" stroke-width="2"/>' +
      '<path d="M5 14H19V6L31 18L19 30V22H5Z" fill="#102a43" transform="rotate(' +
      rotations[direction] + ' 18 18)"/></svg>';
    return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  };
});
