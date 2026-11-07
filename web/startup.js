'use strict';
(() => {
  const message = document.getElementById('startup-message');
  const retry = document.getElementById('startup-retry');
  let finished = false;
  const timer = window.setTimeout(() => {
    if (!finished) {
      message.textContent = 'Loading is taking longer than expected. Check your connection, then reload.';
      retry.hidden = false;
    }
  }, 30000);
  window.backyardPayStartup = {
    ready() {
      finished = true;
      window.clearTimeout(timer);
      document.getElementById('startup')?.remove();
    },
    failed() {
      if (finished) return;
      window.clearTimeout(timer);
      message.textContent = 'BackyardPay could not start. Check your connection and reload the application.';
      retry.hidden = false;
    },
  };
  retry.addEventListener('click', () => window.location.reload());
  window.addEventListener('flutter-first-frame', () => window.backyardPayStartup.ready(), { once: true });
  window.addEventListener('error', (event) => {
    if (event.target instanceof HTMLScriptElement) window.backyardPayStartup.failed();
  }, true);
})();
