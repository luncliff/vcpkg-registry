# Guide: Planning & Creating a New Port

This document gives the **end-to-end workflow** for adding a new port to this registry. Use it as a checklist and follow the linked focused guides for deeper details.

Companion documents:
- Source acquisition patterns: `guide-new-port-download.md`
- Build & installation patterns: `guide-new-port-build.md`

## 1. High-Level Phases

| Phase | Goal | Output |
|-------|------|--------|
| 1. Research | Understand upstream & requirements | Work notes (optional) |
| 2. Acquisition Draft | Fetch source reproducibly | `portfile.cmake` (download section) |
| 3. Build Draft | Configure/install artifacts | Full `portfile.cmake` implementation |
| 4. Manifest Finalization | Describe port metadata | `vcpkg.json` with version + dependencies |
| 5. Test & Iterate | Ensure clean install for target triplets | Working install, logs reviewed |
| 6. Version Registration | Add to registry baseline | Updated `versions/*` + commit |
| 7. Documentation | Record special decisions | Notes in work-note.md (optional) |

## 2. Phase Details & Checklist

### Phase 1: Research
- Identify upstream repository URL & license.
- Determine build system (CMake, Meson, custom, binary-only).
- List runtime/build dependencies → map to existing ports via `vcpkg search`.
- Decide which platforms (triplets) you will initially validate.

Questions to answer:
- Is the project header-only? Build optional tools? Provides pkg-config or CMake configs?
- Are there bundled third-party sources that should be removed to avoid duplication?

### Phase 2: Acquisition Draft
See `guide-new-port-download.md`.
- Choose helper: `vcpkg_from_github` / `vcpkg_from_gitlab` / `vcpkg_from_sourceforge` / `vcpkg_download_distfile`.
- Use `SHA512 0` initially to obtain real hash.
- Remove vendored dependencies (if any) using `file(REMOVE_RECURSE ...)`.
- Add minimal `vcpkg.json` skeleton (name, version, description, homepage, license, tool dependencies like `vcpkg-cmake`).

### Phase 3: Build Draft
See `guide-new-port-build.md`.
- Add build helper calls (`vcpkg_cmake_configure` / `vcpkg_configure_meson` / relocation logic).
- Map optional features using `vcpkg_check_features` or Meson boolean conversion.
- Disable tests/examples unless required (`-DBUILD_TESTING=OFF`).
- Run install helpers, then fix metadata: `vcpkg_cmake_config_fixup`, `vcpkg_fixup_pkgconfig`.
- Copy any executables with `vcpkg_copy_tools`.

### Phase 4: Manifest Finalization
- Select one version field (`version`, `version-string`, `version-semver`, or `version-date`).
- Add feature blocks (only if they affect build inputs/outputs).
- Host-only dependencies (build tools) must include `{ "host": true }`.
- Remove unnecessary fields; keep it concise.

### Phase 5: Test & Iterate
Run overlay install to isolate from builtin ports:
```pwsh
vcpkg install --overlay-ports=ports mylib
```
Validate:
- Correct SHA512 (update if mismatch reported).
- No unexpected files in `packages/<port>` (e.g. stray `.pdb` when not on Windows).
- License file present under `share/<port>/`.
- Config files load: try a consumer CMake project or inspect `share/<port>/*.cmake` after fixup.

Optional multi-triplet checks:
```pwsh
vcpkg install --overlay-ports=ports --triplet x64-windows mylib
vcpkg install --overlay-ports=ports --triplet x64-linux   mylib
```

### Phase 6: Version Registration
Commit port before adding version entries (a clean git state is required for tooling):
```pwsh
git add ports/mylib
git commit -m "[mylib] add v1.2.3"

./scripts/registry-format.ps1 -VcpkgRoot $env:VCPKG_ROOT -RegistryRoot (Get-Location)
./scripts/registry-add-version.ps1 -PortName mylib -VcpkgRoot $env:VCPKG_ROOT -RegistryRoot (Get-Location)

git add versions
git commit -m "[mylib] version metadata v1.2.3"
```

### Phase 7: Documentation (Optional but Recommended)
Create/update `work-note.md` (ignored by git) to record:
- Upstream tag/commit & rationale.
- Applied patches and short justification.
- Removed bundled components.
- Known caveats (platform exclusions, tool feature not enabled, etc.).

## 3. Example Minimal Port Structure
```
ports/mylib/
  vcpkg.json
  portfile.cmake
  fix-config.patch        (optional)
```

## 4. Quality Review Checklist

Review your work with the [Contributor Checklist](../.github/pull_request_template.md)

## 5. Troubleshooting Quick Map
| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Hash mismatch | Upstream changed / wrong archive | Recompute SHA512; pin commit |
| Missing CMake config | Upstream installs elsewhere | Adjust `CONFIG_PATH` or patch install rules |
| Duplicate headers in debug | Forgot cleanup step | Remove `debug/include` after install |
| find_package fails | Config file not adjusted | Ensure `vcpkg_cmake_config_fixup` with correct path |
| Meson ignoring external deps | Bundled subprojects overshadow | Remove or patch `subprojects/` |
| Binary-only port has debug validation error | Debug dir empty / missing | Remove debug dir or add required artifacts |

## 6. When to Use Embedded CMakeLists Strategy
- Upstream build scripts unstable / patch churn high.
- You need rapid prototyping before crafting minimal patches.
- Remember to convert to patch form if contributing upstream.

## 7. Next Steps
Proceed to either:
- Deepen acquisition options → `guide-new-port-download.md`
- Tune build & packaging → `guide-new-port-build.md`

---
Happy porting!
