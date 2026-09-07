(function () {
  "use strict";

  var PALETTE = [
    "#F4A261", "#E76F51", "#6B8CAE", "#A8DADC",
    "#F2CC8F", "#81B29A", "#E9C46A", "#457B9D",
    "#F1FAEE", "#E07A5F", "#3D5A80", "#98C1D9"
  ];

  function buildMosaic() {
    var mosaic = document.getElementById("mosaic");
    if (!mosaic) return;
    var tiles = 45;
    for (var i = 0; i < tiles; i++) {
      var tile = document.createElement("i");
      var color = PALETTE[Math.floor(Math.random() * PALETTE.length)];
      tile.style.setProperty("--tile", color);
      tile.style.setProperty("--delay", (Math.random() * 5).toFixed(2) + "s");
      mosaic.appendChild(tile);
    }
  }

  function isValidEmail(value) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
  }

  function wireForm(formId, statusId) {
    var form = document.getElementById(formId);
    var status = document.getElementById(statusId);
    if (!form || !status) return;

    form.addEventListener("submit", function (event) {
      event.preventDefault();

      var honeypot = form.querySelector('input[name="company"]');
      if (honeypot && honeypot.value) {
        // Bot filled the hidden field — pretend success, do nothing.
        showStatus(status, "You're on the list.", "success");
        form.reset();
        return;
      }

      var emailInput = form.querySelector('input[type="email"]');
      var email = (emailInput.value || "").trim();

      if (!isValidEmail(email)) {
        showStatus(status, "That doesn't look like a valid email.", "error");
        emailInput.focus();
        return;
      }

      var button = form.querySelector("button");
      button.disabled = true;
      showStatus(status, "Adding you…", "");

      fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email })
      })
        .then(function (res) {
          if (!res.ok) throw new Error("request-failed");
          return res.json();
        })
        .then(function () {
          showStatus(status, "You're on the list. We'll email you the moment Sky Grid is live.", "success");
          form.reset();
        })
        .catch(function () {
          showStatus(status, "Something went wrong — please try again in a moment.", "error");
        })
        .finally(function () {
          button.disabled = false;
        });
    });
  }

  function showStatus(el, message, kind) {
    el.textContent = message;
    el.className = "form-status" + (kind ? " " + kind : "");
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
    wireForm("waitlist-form", "form-status");
    wireForm("waitlist-form-2", "form-status-2");
    wireShare();
  });
})();
