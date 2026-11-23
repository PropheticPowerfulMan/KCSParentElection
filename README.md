# KCS Orbit elections

The parent committee and student government use the existing Nexus identity registry and the Nexus/PostgreSQL election API. No separate voter password or Supabase connection is used by the deployed application.

## Workspaces
- Root: parent committee. /student-government/: student government.
- Sign in with an existing institutional email/access code and password.
- The Nexus SuperAdmin signs in at /admin/login/ and can grant election manager or observer permission under **Permissions**.
- Administrators prepare a draft, dates within a published school year, offices, class/section scope, eligible people and approved candidates. Opening voting and publishing results require explicit decisions.
- One server-confirmed participation receipt per account per election. A parent account with several children still casts one complete ballot for its applicable offices. Current institutional class/section links determine eligibility.
- The atomic vote transaction validates every choice and the server clock. Duplicate requests return the original receipt. Immutable database triggers protect recorded ballots and choices.
- Participation records are stored separately from ballot choices. This is not a claim of cryptographic end-to-end verifiability.
- Live counts are hidden unless explicitly allowed. Published results preserve ties; historical closure totals are retained.

## Development and deployment
Node 20, pnpm 9. Set NEXT_PUBLIC_NEXUS_API_URL from .env.example.
Run pnpm install --frozen-lockfile, pnpm test, pnpm typecheck, pnpm build.
GitHub Pages deploys out/ on the existing custom domain. The Nexus API must contain the additive 20261123210000_school_election_platform migration before this frontend is published.
The existing PWA identity is preserved. Updates require user confirmation and do not automatically interrupt an unfinished ballot. Casting a vote requires an online server acknowledgement.

## Legacy data
The supabase/ directory and unused integration sources are retained as historical migration evidence. The deployed routes do not import them. Existing Supabase data has not been deleted or imported. A verified administrative export is required to migrate private legacy voter/ballot history; no votes are recreated from guessed totals. The previous Nexus student-election tables were empty at the initial cutover audit and remain untouched.

## Validation
Run integration voting tests only on isolated clones with synthetic accounts and no live message providers. Verify wrong-role access, class/section boundaries, concurrent duplicates, closed windows, immutable ballots, draft-only edits and equality of participation/ballot totals. Never cast production test votes.
