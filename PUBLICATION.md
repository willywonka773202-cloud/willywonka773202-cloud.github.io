# Public-release checklist

Before sharing a project or publishing an update:

- Confirm the work belongs in the personal portfolio and can be shared.
- State contribution, AI assistance, project stage, and third-party credit.
- Keep credentials, identifiers, private source paths, internal handoffs, and client/company work out of the release.
- Run a secret scan on the proposed source and review its findings. A scanner is not a guarantee.
- Check source, asset, font, model, and dependency licensing before offering open-source reuse.
- Run the documented setup and relevant checks. Test the actual public preview; label configuration limits.
- Review desktop/mobile layout, keyboard navigation, screenshots, broken links, and the public résumé.
- Review the final commit and the deployment allowlist. Do not commit private draft content to a public repository.

The portfolio website uses a positive file allowlist. Publishing the site and publishing its source are separate steps; each needs its own review.

## Public social snapshots

`data/social-metrics.json` contains only verified public-profile totals for The Daily Orb:
- YouTube: `https://www.youtube.com/@thedailyorb` (subscribers, videos, total views in About).
- TikTok: `https://www.tiktok.com/@bertsbuild` (followers and displayed likes).
- X: `https://x.com/theDailyOrb_` (followers and posts).

A weekly Codex follow-up checks these three public profiles. It needs this Mac and the Codex app available to run. It must not invent metrics, read private analytics, collect credentials, or replace an unavailable figure with zero. If any profile cannot be verified, retain the dated snapshot and report the blocker. A missed run therefore leaves the visible date unchanged.

To record a verified snapshot, create a private JSON file matching the most recent snapshot schema and run `python3 scripts/record-social-metrics.py /absolute/path/to/observation.json`. Preserve TikTok's displayed rounded number and `likesApproximate` flag. History is retained; changes appear only after a second observation. Public audience counts are not unique across platforms and must never be summed into a unique-audience claim.

Run `python3 scripts/prepare-vercel.py`, `python3 scripts/check-site.py --deployment`, and `node scripts/test-channel.cjs` sequentially. Use `python3 scripts/export-public.py` to update the dedicated clean public checkout; inspect its diff and run Gitleaks before committing. Never stage the canonical root wholesale. Deploy the prepared `dist` output with the existing Vercel project and verify the production metrics and observation date. The latest-video endpoint refreshes independently from the public YouTube feed.
