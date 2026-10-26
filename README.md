# Will Lambert — Personal portfolio

**[Portfolio](https://will-lambert-portfolio.vercel.app)** · **[Projects](https://will-lambert-portfolio.vercel.app/archive.html)** · **[AI channel](https://will-lambert-portfolio.vercel.app/channel.html)** · **[Updates](https://will-lambert-portfolio.vercel.app/updates.html)**

A personal portfolio for an SDSU entrepreneurship student building with AI. It brings together 58 documented products, tools, games, prototypes, and experiments, plus a résumé and dated updates about the work.

Built with semantic HTML, CSS, vanilla JavaScript, and a Python static-site generator. No analytics, external font requests, database, or paid service is required to run the portfolio.

## Run locally

Requires Python 3.9+; Node is optional for JavaScript syntax checks.

```sh
python3 scripts/build.py
python3 scripts/check-site.py
python3 scripts/package-site.py
python3 -m http.server 4198 --bind 127.0.0.1 --directory dist
```

Open http://127.0.0.1:4198. Serve `dist`, which contains only public files. Project pages and updates remain readable without JavaScript. JavaScript adds search, filters, sorting, grid/list switching, and theme preference. The homepage leads with nine visual case studies, a Daily Orb channel feature, and the complete collection. Both collections default to an image grid and support a compact list. Each project has an image: 22 have actual interface or gameplay captures, one has labeled marketing artwork, and 35 have labeled explanatory project maps. Project pages offer expandable galleries with keyboard navigation.

## Edit projects

`data/categories.json` defines the seven project types, their display names, descriptions, and order. The homepage and Projects page include every type; the full collection groups entries into labeled sections. Search and stage filters hide empty sections, and sorting applies within each type. Category keys stay stable so existing shared URLs keep working.

`data/projects.json` is the reviewed catalog. Each entry has a stable ID, name, category, stage, summary, role, tags, and scope-review date. Case studies add the idea, approach, outcome, next steps, and evidence boundaries. Demo links lead to previews, which may have a narrower scope than the local project.

```sh
python3 scripts/add-project.py --name 'Project name' --summary 'Who it helps and how.' --category 'Everyday tools' --status 'Prototype' --source 'Reviewed README' --step 'Choose an input' --step 'Documented interaction' --step 'Review the result'
python3 scripts/build.py
```

For real captures, use `--image assets/example.jpg --caption 'What this capture shows'` instead of the three map steps. Review images for private data, describe their provenance, and set `media_kind` accurately. Every gallery item needs `src`, `caption`, and `kind`. `scripts/project_maps.py` generates diagrams from the three documented `workflow` steps; diagrams must never be presented as working product screenshots.

## AI channel

`data/channel.json` holds The Daily Orb destinations and selected published episodes. Update the curated review date when changing the selection; this is not an automatic upload feed. The channel page loads YouTube thumbnails and connects the embedded player only after a click. Direct YouTube watch links remain available. The portfolio links to the Daily Orb site, briefing, and directory; third-party directory entries are not claimed as Will’s projects.

The review date records when scope was documented, not a claim that every feature was tested on that date. `Built` does not automatically mean production-ready. Credit upstream work and describe AI assistance clearly.

## Publish an update

Updates support **Build log**, **Check-in**, **Notes**, and **News**. News should include a source link and separate the source's facts from personal commentary.

```sh
python3 scripts/add-update.py --title 'What I worked on' --summary 'A short, specific introduction.' --type 'Check-in' --paragraph 'What changed, what I learned, and what comes next.'
```

This creates an unpublished entry in `data/updates.json`. Review its wording, date, links, and privacy before setting `published` to `true`. Rebuild to generate its permanent page, Updates listing, homepage card, RSS item, and sitemap entry. Draft bodies and source JSON are excluded from the deployed website. Do not commit private drafts to a public repository; the public source export must include only reviewed, published entries.

## Public résumé

`resume/Will-Lambert-Resume.pdf` is the public one-page edition. It omits a phone number and student identifier. Its source is `scripts/build_resume.py` and requires ReportLab. Visually review the one-page PDF after edits.

## Verification and deployment

```sh
python3 scripts/prepare-vercel.py
python3 scripts/check-site.py --deployment
cd dist
vercel deploy --prebuilt --prod --yes --scope willywonka773202-clouds-projects
```

`site_files.py` is the shared publication allowlist. Packaging removes stale generated content and excludes internal notes, environment files, audits, backups, and unpublished posts. The Vercel Build Output API supplies a real 404 response. Deployment remains manual; updating source must not silently publish new personal information.

Before release, verify desktop and mobile navigation, project search and stage filters, both collection layouts, Updates filters, résumé access, and theme switching. HTTP success from a linked app is not an end-to-end functionality guarantee.

## Design and credit

The monochrome editorial direction was inspired by [Louis Raillé](https://louisraille.fr/). Project imagery includes documented screenshots, saved in-game views of Sword Soul and Bloomwake, explicitly labeled project maps, and SlimeFlip marketing artwork. No project image is presented as a fresh runtime test. Big Shoulders Display, Bodoni Moda, and Martian Mono are self-hosted with their SIL Open Font Licenses in `assets/fonts/`.

Public source visibility does not grant a new license to third-party assets or the separate projects described here. Their licenses and attribution remain their own. This repository is a presentation of the work, not a distribution of all 58 projects.
