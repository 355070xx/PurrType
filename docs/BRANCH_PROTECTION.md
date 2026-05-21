# Branch Protection Policy

The public repository should protect `main` before accepting outside changes.
Apply these controls to `main` through branch protection or repository rulesets:

- Require pull requests before merging.
- Require the `Release preflight` status check from the `CI` workflow.
- Require the branch to be up to date before merging.
- Block force pushes.
- Block branch deletion.
- Require conversation resolution before merge.
- Keep direct pushes to `main` disabled except for emergency owner recovery.

Until GitHub enforcement is enabled, release-candidate branches must stay as draft pull requests until:

- `make release-preflight` passes locally.
- GitHub Actions `Release preflight` passes on the PR.
- Manual GUI install and typing smoke tests are recorded in the PR.
- Checksums and provenance status are recorded in the PR.
- If prebuilt binary artifacts are published, signing and notarization status is recorded in the PR.
- Product-facing docs are checked for scope accuracy: current modes are `Sucheng`, `New Sucheng`, `Cangjie`, `Pinyin`, plus automatic raw English pass-through; English spelling suggestions must be described as candidate-only and not autocorrect.
