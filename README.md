# KCS Parent Election

Production-oriented bilingual-ready election MVP for Kinshasa Christian School. The platform provides a branded voter journey, three-office ballot, administration, monitoring, reports, and a privacy-preserving Supabase data model.

## Architecture

Next.js App Router renders the responsive PWA. Supabase PostgreSQL is the security authority. Voter identity and anonymous ballot data live in separate tables; no voter identifier is stored on ballots or choices. The `submit_ballot` RPC locks the voter row, validates the election window and all choices, inserts the whole ballot, marks the voter as voted, and commits atomically. Concurrent submissions therefore yield exactly one accepted ballot.

## Local setup

1. Install Node.js 20+ and run `npm install`.
2. Copy `.env.example` to `.env.local` and set the Supabase values.
3. Create a Supabase project, then run `supabase/migrations/001_initial.sql` in the SQL editor or with `supabase db push`.
4. Run `npm run dev` and open http://localhost:3000.

## Security model

- RLS is enabled on all sensitive tables. Ballots and choices have no client policies.
- Vote submission is granted only to the server service role and occurs in one locked transaction.
- Submitted ballot rows are immutable by trigger; administrators receive no vote-edit UI.
- PINs are bcrypt hashes and are destroyed after voting. Apply rate limits at the API/edge layer and track attempts in `login_attempts`.
- Admin authorization is database-enforced with SUPER_ADMIN, ELECTION_ADMIN, and OBSERVER roles.
- Receipts contain only an anonymous confirmation code and time.
- Interim results default to off. Ties must be displayed as requiring an official decision.

Never expose `SUPABASE_SERVICE_ROLE_KEY` to the browser. Production authentication and import endpoints should be deployed as server routes or Supabase Edge Functions. CSV/XLSX rows must be previewed, validated, and deduplicated by voter code and student ID before insertion.

## Election operation

Create an election, its three positions, candidates, voters, and admin roles. Keep status DRAFT while editing. Schedule or explicitly switch to OPEN only inside the configured window. Closing sets CLOSED; verify totals, then publish results. Never correct individual ballot rowscancel and rerun under school policy if integrity is disputed.

## Deployment

Deploy Next.js to Vercel, configure the five environment variables, and point the custom domain to Vercel. Configure Supabase allowed URLs, backups, PITR, MFA for admins, CAPTCHA/rate limits, storage policies, and log retention.

## Verification checklist

Run `npm run lint`, `npm run typecheck`, `npm test`, and `npm run build`. Before election day, perform concurrency tests against a staging Supabase project, restore testing, role/RLS penetration checks, mobile/network-interruption tests, accessibility checks, and a complete mock election with signed result certification.

## Themes and languages

The global controls persist the KCS Nexus-inspired moon theme and the sun theme in localStorage. English and French apply across public, voter, candidacy, result, and administration routes.

## Parent candidacy on GitHub Pages

The candidacy page validates the parent form locally and composes an email directly to kinshasachristianschool@gmail.com. No personal information passes through an unapproved form relay. The parent must attach their photo and press Send in their email application. For automatic server-side delivery, deploy the Next.js app to Vercel with an approved transactional-email provider and server-held credentials.

