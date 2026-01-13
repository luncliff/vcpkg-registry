# ANGLE Port - GN Build System Challenge

## Problem Statement

This port attempts to build ANGLE using its native GN build system as requested. However, after investigation, significant technical blockers have been identified.

## Technical Blockers

### 1. Missing Chromium Build Infrastructure

ANGLE's `.gn` file requires Chromium build infrastructure that is NOT included in GitHub tarballs:

```gn
import("//build/dotfile_settings.gni")
buildconfig = "//build/config/BUILDCONFIG.gn"
```

These files are part of Chromium's build system and are not included in ANGLE's standalone repository.

### 2. Dependency Management

ANGLE uses `gclient` from Chromium's `depot_tools` to fetch numerous third-party dependencies specified in the `DEPS` file. vcpkg does not support this dependency resolution mechanism.

### 3. Build System Complexity

ANGLE's GN build expects:
- Full Chromium `build/` directory with configuration files
- Build overrides for various platforms
- Numerous third-party dependencies fetched via gclient

## Current Status

The port has been created with:
- ✅ Correct source SHA512
- ✅ vcpkg-gn dependency
- ✅ GN configuration structure
- ❌ Will fail during GN gen phase due to missing build files

## Alternatives

1. **Custom CMake Build** (as done in PR #491) - Transcribe GN logic to CMake
2. **Fetch Chromium Build Files** - Download required build infrastructure
3. **Wait for Upstream** - ANGLE may eventually provide standalone GN support

## References

- PR #491: https://github.com/luncliff/vcpkg-registry/pull/491 (used custom CMake)
- ANGLE DevSetup: https://github.com/google/angle/blob/master/doc/DevSetup.md
- Chromium Build System: Required but not accessible via simple tarball

## Conclusion

A pure GN-based vcpkg port for ANGLE is not currently feasible without substantial additional infrastructure or upstream changes.
