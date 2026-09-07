(function () {
  "use strict";

  // Real sky, not invented colour. DESIGN.md forbids fabricating a sky for visual
  // completeness, so these are average colours sampled from the CC0 sky photographs
  // the app ships in ios/SkyGrid/Tests/Fixtures — the same averaging the app performs
  // to derive a mosaic tile. Clear, dramatic, overcast and sunset mornings.
  var PALETTE = [
    "#3D7AC0", "#306AAE", "#2661A7", "#3372B9",
    "#543D5A", "#44324F", "#844A56", "#A04E4E",
    "#7C8489", "#999B9E", "#AAADAF", "#687176",
    "#044A8C", "#3C5DA6", "#5F70AD", "#B7A5C6"
  ];

  function buildMosaic() {
    var mosaic = document.getElementById("mosaic");
    if (!mosaic) return;
    var tiles = 45;
    for (var i = 0; i < tiles; i++) {
      var tile = document.createElement("i");
      var color = PALETTE[Math.floor(Math.random() * PALETTE.length)];
      tile.style.setProperty("--tile", color);
      tile.style.setProperty("--delay", (i * 18) + "ms");
      mosaic.appendChild(tile);
    }
  }

  function wireShare() {
    var btn = document.getElementById("share-btn");
    if (!btn) return;
    btn.addEventListener("click", function () {
      var shareData = {
        title: "Sky Grid",
        text: "One photo of the sky each morning. A year, one grid. Available on the App Store:",
        url: window.location.href
      };
      if (navigator.share) {
        navigator.share(shareData).catch(function () {});
      } else if (navigator.clipboard) {
        navigator.clipboard.writeText(window.location.href).then(function () {
          btn.textContent = "Link copied";
          setTimeout(function () { btn.textContent = "Share"; }, 2000);
        });
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    buildMosaic();
    wireShare();
  });
})();
