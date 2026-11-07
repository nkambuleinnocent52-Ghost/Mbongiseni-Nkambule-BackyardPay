{{flutter_js}}
{{flutter_build_config}}

// Retire the previous offline cache so a newly deployed app uses current files.
// This never clears authentication storage or rental records.
async function retirePreviousFlutterCache() {
  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      for (const registration of registrations) {
        const worker = registration.active || registration.waiting || registration.installing;
        if (worker && new URL(worker.scriptURL).pathname.endsWith('/flutter_service_worker.js')) {
          await registration.unregister();
        }
      }
    }
    if ('caches' in window) {
      for (const key of await caches.keys()) {
        if (['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest'].includes(key)) await caches.delete(key);
      }
    }
  } catch (_) {
    // Browsers may deny cache access; online startup can still proceed.
  }
}
(async () => {
  await retirePreviousFlutterCache();
  try {
    await _flutter.loader.load({
      onEntrypointLoaded: async (initializer) => {
        try {
          const runner = await initializer.initializeEngine();
          await runner.runApp();
        } catch (error) {
          window.backyardPayStartup?.failed();
          console.error('BackyardPay engine startup failed', error);
        }
      },
    });
  } catch (error) {
    window.backyardPayStartup?.failed();
    console.error('BackyardPay loader failed', error);
  }
})();
