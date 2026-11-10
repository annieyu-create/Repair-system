# Repository Guidelines

## Project Structure & Module Organization

This workspace currently contains `報修需求筆記.txt`, the requirements for a small repair-request registration demo. No application source, tests, dependency manifest, or build configuration exists yet. Read this note before implementing features; preserve its Traditional Chinese terminology.

Planned deliverables include a web form and request list, Supabase tables and access rules, an Excel field catalog, a six-slide proposal, and a Word user guide. As implementation begins, group application code in `src/`, tests in `tests/`, static assets in `public/`, documents in `docs/`, and database migrations in `supabase/migrations/`. These are proposed locations, not existing directories.

## Build, Test, and Development Commands

There are currently no build, development, lint, or test commands. Do not assume `npm test` or another toolchain is available. When selecting a stack, document installation, local startup, build, and verification commands in a README and commit the dependency lockfile.

## Coding Style & Naming Conventions

No formatter or linter is configured. Adopt one consistent style with the first implementation and document its commands. Use two-space indentation for web code and descriptive names such as `RepairRequestForm` and `request_status`. Keep user-facing labels in Traditional Chinese and align categories, urgency levels, and statuses with the requirements note.

## Testing Guidelines

No testing framework or coverage threshold exists. Add tests alongside implemented behavior, using descriptive names such as `repair-request.test.ts` if TypeScript is chosen. Verify required fields, successful submissions, list rendering, automatic timestamps, and database permissions. Demonstrate that anonymous users can insert and read records but cannot update or delete them.

## Commit & Pull Request Guidelines

This directory is not currently a Git repository, so no historical commit convention can be inferred. Once initialized, use short imperative messages, for example `Add repair request form`. Pull requests should explain the change, reference relevant requirements, report verification performed, and include screenshots for interface changes.

## Security & Scope

Use fictional names and locations only. Enable Supabase row-level security before exposing data. Never commit service-role keys or secrets. The demo permits public inserts and reads; status updates, authentication, and notifications require clarified scope before implementation.
