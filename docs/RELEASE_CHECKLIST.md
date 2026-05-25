# Release Checklist

Use this checklist before creating any release tag or GitHub release.

## Required Gates

- [ ] `make verify` passes.
- [ ] Lint is clean.
- [ ] Parameter sweep is clean.
- [ ] Documentation is updated.
- [ ] License collateral is checked.
- [ ] Supported parameter matrix is updated.

## Release Notes

- [ ] `VERSION` is updated from `0.1.0-dev` to the release version.
- [ ] `CHANGELOG.md` has a dated release section.
- [ ] `docs/PARAMETERS.md` matches the release-supported parameter matrix.
- [ ] `docs/TIMING_CONTRACT.md` matches the released public interface behavior.
- [ ] `docs/GAP_ANALYSIS.md` contains only unresolved gaps.
- [ ] No release tag is created until all required gates pass.
