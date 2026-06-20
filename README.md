# Entovist Legal Documents

This repository contains the legal documents for Entovist, a software product operated by **Mahdi Ghorban Pour - Digitexia**.

## Current Documents

| Document | Current Version | Changelog |
| -------- | --------------- | --------- |
| Terms of Service | [Version 1.0.0](terms-of-service/Entovist-Terms-of-Service.md) | [History](terms-of-service/CHANGELOG.md) |
| Privacy Policy | [Version 1.0.0](privacy-policy/Entovist-Privacy-Policy.md) | [History](privacy-policy/CHANGELOG.md) |
| Data Processing Agreement | [Version 1.0.0](dpa/Entovist-DPA.md) | [History](dpa/CHANGELOG.md) |

## Repository Structure

Each document has its own directory containing:

- An unversioned canonical file representing the current published version
- A `CHANGELOG.md` containing its release history and versioning policy, where applicable
- An `archive/` directory containing immutable snapshots of released versions

```text
<document>/
├── Entovist-<Document>.md
├── CHANGELOG.md
└── archive/
    └── Entovist-<Document>-v1.0.0.md
```

The unversioned filenames provide stable publication targets. Versioned archive files preserve the exact content of each release.

## Release Process

1. Prepare and review the change in the unversioned canonical document.
2. Update its version, effective date, last-updated date, and status metadata.
3. Create an identical versioned snapshot in the document's `archive/` directory.
4. Add the release to the document's changelog and link it to the archived snapshot.
5. Verify that the canonical document and archived snapshot are byte-identical at release time.
6. Commit the release without modifying any previously archived version.

## Archive Policy

Files under an `archive/` directory are immutable release records. Corrections require a new document version and a new archived snapshot; an existing archived file must not be edited or replaced.
