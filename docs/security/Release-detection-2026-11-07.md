# Release detection investigation — 7 November 2026

Status: unresolved Microsoft Defender detection. Deployment of the research web ZIP is paused. Do not bypass Defender, rename/repackage the archive to evade detection, or treat this report as security clearance.

## Exact artifact

- Archive: `downloads/BackyardPay-Research-web.zip`
- SHA-256: `74a03aeaad86d4e9d919e3410ae98e431578ad221cc0fc68a7c69ad853d383a2`
- Windows finding reported by the owner: `Trojan:Script/Wacatac.B!ml`, affecting the archive's `index.html`.
- `index.html` SHA-256: `a0a1fcc5757323733d7271e4a8a864ce2a1a398db9cd4993de6d0e31f9bf6f88`

## Investigation performed

The ZIP passes archive integrity checks. Its index exactly matches `web/index.html` after Flutter's normal base-href substitution. It loads `flutter_bootstrap.js`; no extra inline program was found in that HTML. Eighteen packaged rendering files match the installed Flutter SDK. These checks establish local correspondence, not independently verified SDK provenance or absence of malware.

An independent ClamAV scan of the exact archive completed successfully in a disposable container, with the release mounted read-only and container networking disabled. No project file was submitted to an external scanning service.

- Image: `clamav/clamav:stable`, digest `sha256:6d87c712e3391e13c1ba6e05dfb074d4b1ddb5a6834b23bb9da990d2a4ef042a`.
- Engine: 1.5.4. Signature database: 28171, 1 November 2026 (six days before this investigation; not the latest live Defender signatures).
- Result: archive OK; infected files 0; 106.80 MiB scanned after archive processing.

A negative result from another engine does not overturn Defender's detection. Defender is not available in this Linux workspace. The downloaded copy on the user's computer has not been independently hashed here. Microsoft's file-specific review remains outstanding.

## Next release gate

Keep the original blocked download quarantined. Obtain a Microsoft review of the exact flagged artifact, or investigate a confirmed cause and verify a corrected build. Do not publish the unresolved artifact merely through a different transport. After release acceptance, Netlify deployment can be automated from GitHub to avoid repeated manual ZIP handling.

The computer's full scan checks that computer. It is separate from review of this release; application tests, documentation and preparation of deployment configuration can continue while it runs.
