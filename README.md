# Will Lambert — Personal portfolio

**[Portfolio](https://will-lambert-portfolio.vercel.app)** · **[Projects](https://will-lambert-portfolio.vercel.app/archive.html)** · **[Updates](https://will-lambert-portfolio.vercel.app/updates.html)**

A personal portfolio for an SDSU entrepreneurship student building with AI. It brings together 57 documented products, tools, games, prototypes, and experiments, plus a résumé and dated updates about the work.

Built with semantic HTML, CSS, vanilla JavaScript, and a Python static-site generator. No analytics, external font requests, database, or paid service is required to run the portfolio.

## Run locally

Requires Python 3.9+; Node is optional for JavaScript syntax checks.

```sh
python3 scripts/build.py
python3 scripts/check-site.py
python3 scripts/package-site.py
python3 -m http.server 4198 --bind 127.0.0.1 --directory dist
```

Open http://127.0.0.1:4198. Serve `dist`, which contains only public files. Project pages and updates remain readable without JavaScript. JavaScript adds search, filters, sorting, the project gallery, theme preference, and pausable terrain motion.

## Edit projects

`data/projects.json` is the reviewed catalog. Each entry has a stable ID, name, category, stage, summary, role, tags, and scope-review date. Case studies add the idea, approach, outcome, next steps, and evidence boundaries. Demo links lead to previews, which may have a narrower scope than the local project.

```sh
python3 scripts/add-project.py --name 'Project name' --summary 'Who it helps and how.' --category 'Everyday tools' --status 'Prototype' --source 'Reviewed README'
python3 scripts/build.py
```

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

Before release, verify desktop and mobile navigation, project search and stage filters, both layouts, Updates filters, résumé access, reduced motion, and theme switching. HTTP success from a linked app is not an end-to-end functionality guarantee.

## Design and credit

The monochrome editorial direction was inspired by [Louis Raillé](https://louisraille.fr/). The terrain canvas is original procedural artwork and project imagery consists of documented screenshots. Big Shoulders Display, Bodoni Moda, and Martian Mono are self-hosted with their SIL Open Font Licenses in `assets/fonts/`.

Public source visibility does not grant a new license to third-party assets or the separate projects described here. Their licenses and attribution remain their own. This repository is a presentation of the work, not a distribution of all 57 projects.
