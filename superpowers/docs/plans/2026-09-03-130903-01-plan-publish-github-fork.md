# Publish the Apple Silicon modernization fork

**Goal:** Publish the verified Jitouch modernization as the public `kitjub/Jitouch` fork without changing the upstream repository.
**Why planning is required:** Creating a public GitHub repository and pushing code are consequential external actions.
**Acceptance:** The target is a public fork of `JitouchApp/Jitouch`; GPL and original attribution remain intact; the README clearly identifies the work as an unofficial modification and dates it; no personal backup, secret, build output, or user-specific absolute path is tracked; the exact verified commit is fast-forwarded to the fork's default branch; `JitouchApp/Jitouch` remains configured only as `upstream`; stop before pushing if the target already exists with divergent work or any privacy/license check fails. Recovery is possible by retaining the local branch and commit and, if necessary, reverting the new public-preparation commit in the personal fork without rewriting upstream.

### Outcome 1: Public-safe repository contents
- Work: Preserve `LICENSE` and original copyright notices, add a prominent unofficial-fork and modification notice to `README.md`, and use a GitHub-safe commit identity.
- Risks/open questions: The Jitouch name and icon must not imply endorsement by the original authors; personal local paths and settings backups must remain excluded.
- Verify: `git grep`, `git check-ignore`, `git diff --check`, and a staged diff review.

### Outcome 2: Reproducible release candidate
- Work: Verify the source, focused regression suite, arm64 build, bundle metadata, and code signature at the revision that will be published.
- Verify: `make clean test all engine-smoke verify`

### Outcome 3: Public fork delivery
- Work: Create `kitjub/Jitouch` as a public GitHub fork, configure it as `origin`, retain `JitouchApp/Jitouch` as `upstream`, and fast-forward the fork's `main` branch to the verified commit. Do not push to upstream or create an upstream pull request.
- Risks/open questions: Abort if the fork appears with unexpected history or visibility, or if the remote main branch cannot be updated by fast-forward.
- Verify: GitHub repository metadata, remote URLs, remote commit identity, and a clean local worktree.
