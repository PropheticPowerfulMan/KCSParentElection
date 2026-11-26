# Election PWA installation and link handling

Each platform keeps its existing app identity: Parent /kcs-parent-election, Student /student-government/. Each has its own manifest, service worker, cache namespace and login start URL. Both explicit login install panels share one native-prompt controller, so prompts cannot be consumed twice.

A standalone window alone is not installation evidence: it may belong to Nexus. Installed-app discovery matches the webapp identity and manifest exactly. Browsers without discovery still show installation instructions. The login controls are always available; installation never grants voting or administration rights.

Nexus election links and cross-platform login links are direct user-activated anchors with target="_blank" rel="noopener noreferrer". No credentials, SSO tokens or tickets are included. This allows browser navigation capture when the destination app is installed and the user has enabled link handling. A website cannot override browser preferences or guarantee native capture on every OS; iOS users can launch the Home Screen icon.

Validation, 26 November 2026:
- TypeScript, production build and unit tests.
- 12 mobile login variants: parent, student and administration x FR/EN x light/dark; visible inline action, keyboard-dismissable centered help, no horizontal overflow.
- Native prompt dismissal, retry and single consumption; foreign standalone window does not hide installation.
- Real Nexus Teacher/Principal/ST workspace links preserve login entry, return path and server role checks.
- Isolated headed Chromium 140: install and launch each electoral app; both report standalone display. With app-window display and link capture enabled in the disposable profile, openerless links from an installed Nexus window are captured into the matching electoral app windows.
