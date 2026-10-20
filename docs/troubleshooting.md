# Troubleshooting: Port Installation & Build Errors

This guide helps diagnose and fix common issues when creating or updating ports. It serves as a central troubleshooting hub in the workflow:
- **Create port** → Install port → **Troubleshoot** → Update port
- **Update port** → Install port → **Troubleshoot**
- **Check environment** → **Troubleshoot**

Related prompts: `/install-port`, `/check-environment`, `/search-if-known-issue`, `/review-port`

## Check for Known Issues Before Patching

When a port build or installation fails, use
[search-if-known-issue](../.github/skills/search-if-known-issue/SKILL.md):

1. Capture the failing command, resolved port version, and first causal diagnostic from the build logs.
2. Check the actual build host and target configuration, including triplets, compiler, toolchain, and SDK versions.
3. Search open and closed GitHub issues and PRs in vcpkg, the upstream project, and relevant dependency repositories.
4. Verify candidate reports and fixes against the observed version, diagnostic, and environment.
5. Use an applicable fix or hand off to local diagnosis and patching when the completed search finds no match.
   Verify the remedy with the original installation configuration.

Record search access gaps explicitly; an unavailable search remains blocked rather than a completed no-match result.

## Common Error Categories

### CMake Configuration Errors

When encountering CMake configuration issues:

- Check CMake version compatibility
- Verify required CMake modules are available
- Review `CMakeLists.txt` for platform-specific logic
- Use `-DCMAKE_VERBOSE_MAKEFILE=ON` for detailed output

Resources:
- [CMake Documentation](https://cmake.org/cmake/help/latest/)

### Compiler Errors

When encountering compiler errors:

- Verify compiler version meets minimum requirements
- Check for platform-specific code paths
- Review compiler flags in portfile and triplet
- Consider adding patches for compatibility fixes

Resources:
- [MSVC Compiler Options](https://learn.microsoft.com/en-us/cpp/build/reference/compiler-options)
- [Clang User Manual](https://clang.llvm.org/docs/UsersManual.html)
- [GCC Manual](https://gcc.gnu.org/onlinedocs/gcc-15.2.0/gcc/)

### Linker Errors

When encountering linker errors:

Resources:
- [LINK.exe Options](https://learn.microsoft.com/en-us/cpp/build/reference/linker-options)
- [Clang Command Line Reference](https://clang.llvm.org/docs/ClangCommandLineReference.html)
- [LLD Linker Documentation](https://lld.llvm.org/)
- [GCC Link Options](https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html)

### ONNX Runtime with CUDA 13.4 on Windows

Install the GPU features using the registry overlays:

```powershell
vcpkg install "onnxruntime[cuda,tensorrt]:x64-windows" `
  --overlay-ports=.\ports --overlay-triplets=.\triplets `
  --x-buildtrees-root=.\buildtrees --x-packages-root=.\packages `
  --x-install-root=.\installed
```

CUDA, cuDNN, and TensorRT use system SDK installations. Set `CUDA_PATH`,
`CUDNN_ROOT_DIR` (when cuDNN is outside the standard NVIDIA installation
directory), and `TENSORRT_HOME` to those installations. Include the variables in
`VCPKG_KEEP_ENV_VARS` so vcpkg's build environment can access them. At runtime,
include the installed package's `bin` directory and the SDK DLL directories in
`PATH`; use `debug\bin` for a Debug consumer. Keep
`onnxruntime_providers_shared.dll`, `onnxruntime_providers_cuda.dll`, and
`onnxruntime_providers_tensorrt.dll` beside the loaded `onnxruntime.dll`.
When vcpkg's CMake app-local deployment copies `onnxruntime.dll` beside an
executable, also deploy these dynamically loaded provider DLLs from the matching
Release or Debug `bin` directory. Listing the original directory in `PATH` alone
does not satisfy ONNX Runtime's provider lookup beside the loaded runtime.

The registry's Abseil port includes two CUDA/MSVC compatibility patches:

- Explicit `HashStateBase` friend specializations fix `C3856`, `C2098`, and
  `C2059` in Abseil hash headers. See
  [microsoft/onnxruntime#28736](https://github.com/microsoft/onnxruntime/pull/28736)
  and [abseil/abseil-cpp#2185](https://github.com/abseil/abseil-cpp/issues/2185).
- Explicit hash-container base types and distinct template parameter names fix
  `C2248` involving the private `Hash`, `Eq`, and `Alloc` aliases. See
  [conda-forge/abseil-cpp-feedstock#118](https://github.com/conda-forge/abseil-cpp-feedstock/pull/118).

For an existing installation, upgrade `abseil:x64-windows` with `vcpkg upgrade
--no-dry-run` and the same overlay and root options before retrying ONNX Runtime.
This also rebuilds installed consumers of Abseil; `vcpkg install` alone retains
already-installed dependency versions.

The ONNX Runtime CUDA patch also replaces `std::clamp` in the shared sparse
attention indexer grid-size helper with an equivalent bounded expression.
With CUDA 13.4.92 and MSVC 14.51, the original expression causes NVCC to emit
`Terminator found in the middle of a basic block!` and
`Invalid instruction with no BB` while compiling both sparse attention
indexer implementations. The replacement preserves the grid range `[1, 65535]`.

### vcpkg-Specific Issues

Common vcpkg pitfalls:

- **Triplet mismatches**: Ensure consistent triplet usage
- **Overlay ports conflicts**: Check overlay port priority
- **Feature flag issues**: Verify feature dependencies
- **Version baseline**: Confirm version entries are up-to-date
