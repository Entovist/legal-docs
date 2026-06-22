# Entovist Legal Documents

This repository contains the legal documents for Entovist, a software product operated by **Mahdi Ghorban Pour - Digitexia**.

## Current Documents

| Document | Markdown | PDF | Changelog |
| -------- | -------- | --- | --------- |
| Terms of Service | [Version 1.0.0](terms-of-service/Entovist-Terms-of-Service.md) | [Download](terms-of-service/Entovist-Terms-of-Service.pdf) | [History](terms-of-service/CHANGELOG.md) |
| Privacy Policy | [Version 1.1.0](privacy-policy/Entovist-Privacy-Policy.md) | [Download](privacy-policy/Entovist-Privacy-Policy.pdf) | [History](privacy-policy/CHANGELOG.md) |
| Data Processing Agreement | [Version 1.0.0](dpa/Entovist-DPA.md) | [Download](dpa/Entovist-DPA.pdf) | [History](dpa/CHANGELOG.md) |

## Repository Structure

Each document has its own directory containing:

- An unversioned canonical file representing the current published version
- A generated PDF matching the canonical Markdown document
- A `CHANGELOG.md` containing its release history and versioning policy, where applicable
- An `archive/` directory containing immutable Markdown and PDF snapshots of released versions

```text
<document>/
├── Entovist-<Document>.md
├── Entovist-<Document>.pdf
├── CHANGELOG.md
└── archive/
    ├── Entovist-<Document>-v1.0.0.md
    └── Entovist-<Document>-v1.0.0.pdf
```

The unversioned filenames provide stable publication targets. Versioned archive files preserve the exact content and generated PDF of each release.

## Building PDFs

PDFs are generated from Markdown using the shared stylesheet at `assets/pdf.css`. The build requires Node.js with npm and Microsoft Edge, or another Chromium-compatible browser specified through `PDF_BROWSER`. Renderer versions are pinned in `package-lock.json`.

Install the build dependencies:

```powershell
npm ci
```

Build all documents:

```powershell
./scripts/build-pdfs.ps1
```

Build one document:

```powershell
./scripts/build-pdfs.ps1 -Document privacy-policy
```

The script reads the title and version from each document's YAML metadata and places them in a stable footer with `Page X of Y`. If the corresponding Markdown snapshot does not exist, it creates one. If an archived snapshot exists but differs from the canonical document, the build fails and requires a version increment. Existing archived PDFs are never regenerated or overwritten.

## Release Process

1. Prepare and review the change in the unversioned canonical document.
2. Update its version, effective date, last-updated date, and status metadata.
3. Run `./scripts/build-pdfs.ps1` to create the Markdown snapshot and generate the canonical and archived PDFs.
4. Add the release to the document's changelog and link both archived formats.
5. Verify that the canonical and archived Markdown files are byte-identical and that the canonical and archived PDFs are byte-identical.
6. Commit the release without modifying any previously archived version.

## Archive Policy

Files under an `archive/` directory are immutable release records. Corrections require a new document version and new Markdown and PDF snapshots; an existing archived file must not be edited, regenerated, or replaced.
