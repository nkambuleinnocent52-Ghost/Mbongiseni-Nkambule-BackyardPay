# BackyardPay 1.0.1 (build 2): rebuilt Netlify release

7 November 2026. This release follows the owner's request to repair and rebuild the application, rather than continue the manual submission workflow.

## Changes

- Replaced the empty template entry page with an accessible, branded startup screen, external stylesheet and external startup scripts. Missing scripts and slow startup have a visible explanation and reload button.
- Added a Content Security Policy limiting executable scripts to this site's files. The compiler uses Flutter's `--csp` option; WebAssembly compilation is allowed for Flutter's renderer, while general JavaScript string evaluation is not allowed by the page policy. Connections are limited to the site and the existing Supabase project. No inline executable HTML or remote application script is added.
- Disabled Flutter's offline service worker installation and retired only the previous Flutter cache/worker. Browser authentication/local storage and Supabase records are preserved.
- Added Netlify no-cache headers for the entry/compiled application and an SPA fallback, plus MIME, frame and permission headers. This addresses stale-release and direct-route deployment failures.
- Cleaned the generated build directory, resolved dependencies using the existing lockfile, and produced a new release from source. The installed Flutter 3.47.5 framework commit `6a19cca56475dbfba1478ee68d7bd0c2ef891da1` matches the official Flutter GitHub tag. The source checkout has no SDK modifications. Fetching the public Linux release manifest returned HTTP 404, so no archive-manifest verification is claimed.
- Added packaging validation: every entry asset must exist, scripts must match the expected external-script list, archive paths and file types are checked, and the ZIP contains a per-file SHA-256 manifest. The web ZIP contains `index.html` at its root. Original research ZIPs remain unchanged for comparison.

## Validation

- All 34 Flutter tests passed after dependency resolution and the clean build.
- Release JavaScript build passed with CSP compilation and local rendering resources.
- Startup browser checks passed: 390px launch, no CSP errors, removal of the temporary HTML after startup, old Flutter cache removal with local storage preserved, and an understandable error/retry when the bootstrap request is blocked.
- The two-session browser contract checks exercise accounts, property/room, payment report/review, balance refresh, PDF download, session restoration and password recovery under the new policy. They use simulated Supabase transport; they do not prove hosted database or email configuration.
- Archive integrity and independent ClamAV scan results are recorded alongside this release. ClamAV 1.5.4 uses database 28171 dated 1 November 2026 in the available scanner image; a negative result is not a Microsoft Defender verdict.

The original `BackyardPay-Research-web.zip` was reported by Windows Defender as `Trojan:Script/Wacatac.B!ml`, identifying its index page. Inspection found that page matched its source, but did not establish a root cause or a false-positive verdict. This release makes functional startup, policy, cache and packaging changes; it is not the old ZIP renamed to circumvent a detection. Do not restore the quarantined old archive. There is no claim that Microsoft reviewed or cleared either artifact. Let Windows check the new download normally and do not bypass a new block.

## Owner deployment

1. Download `BackyardPay-Netlify-web.zip` from the repository's downloads folder, keeping Windows/browser protection enabled.
2. If that download passes the browser's normal checks, upload it to the existing Netlify project's manual Deploys area. Alternatively extract it and upload the folder whose immediate contents include `index.html`.
3. Open the published site and refresh. Use existing email/password accounts. No new Supabase migration or Auth/SMTP change is introduced by 1.0.1; the previously supplied Research Update is still required for its database features.

The app records received payments; it does not transfer or bank-verify money. Real hosted account/file/GPS checks still require the actual deployment. No Visual Studio access is needed for this release.

## Reproduce

With the pinned Flutter version available, Python 3 installed and dependencies accessible, run `FLUTTER_BIN=/path/to/flutter tool/build_netlify.sh`. Serve `build/web` and run `node tool/web_startup_test.cjs` and `node tool/browser_smoke.cjs` with Playwright/Chromium installed. Packaging does not publish to Netlify.
