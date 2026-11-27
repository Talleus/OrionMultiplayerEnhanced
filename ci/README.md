# GitHub Actions template

`github-checks.yml` runs the synthetic unit tests and Python compilation check.
Local release validation is recorded in `docs/TESTING.md`.

The publishing OAuth credential does not have GitHub's `workflow` scope, so this
file is included as a template rather than an active Actions workflow. No GitHub
Actions run is claimed for this release.

To enable it with an account authorized to manage workflows, place this file at
`.github/workflows/check.yml` through GitHub or an appropriately authorized Git
credential, then commit it. The job needs only `contents: read`.
