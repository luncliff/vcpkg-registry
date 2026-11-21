# llama.cpp Feature Enhancement Plan

## Goal

Expand `llama-cpp` feature coverage without exposing CMake options whose required
libraries, host tools, or vendor SDKs cannot be supplied by the registry.

This plan uses [the llama.cpp/ggml research](./llama-cpp-ggml-research.md) as
the source-of-truth for upstream CMake options and the vcpkg port catalog for
dependency availability.

## Current feature additions

| Feature | CMake option | vcpkg dependency | Initial triplet coverage |
|---|---|---|---|
| `blas` | `GGML_BLAS=ON`, `GGML_BLAS_VENDOR=OpenBLAS` | `openblas` | Windows, Linux, macOS |
| `llamafile` | `GGML_LLAMAFILE=ON` | None | Windows, Linux, macOS |
| `openvino` | `GGML_OPENVINO=ON` | `openvino[cpu]`, `opencl` | OpenVINO-supported x64/arm64 triplets; excludes Windows ARM64 and x86 |
| `rpc` | `GGML_RPC=ON` | None beyond platform sockets | Windows, Linux, macOS |
| `webgpu` | `GGML_WEBGPU=ON` | `dawn` | Windows, Linux, macOS |

Existing features remain:

| Feature | CMake option | Dependency / support |
|---|---|---|
| `cuda` | `GGML_CUDA` | `cuda`; x64 Windows and x64/arm64 Linux |
| `metal` | `GGML_METAL` | Apple SDK; macOS and iOS |
| `opencl` | `GGML_OPENCL` | `opencl`; uses acquired Python for embedded kernels |
| `openmp` | `GGML_OPENMP` | Compiler runtime |
| `tools` | `LLAMA_BUILD_TOOLS`, `LLAMA_BUILD_SERVER`, `LLAMA_OPENSSL`, `LLAMA_SUBPROCESS` | cpp-httplib[openssl], miniaudio, stb |

## Platform matrix

| Area | Windows x64 | Windows arm64 | Linux x64 | Linux arm64 | macOS | Android/iOS |
|---|---:|---:|---:|---:|---:|---:|
| CUDA | Implemented | Unsupported by CUDA port | Implemented | Implemented | Unsupported | Unsupported |
| OpenCL | Implemented | Implemented | Implemented | Implemented | Implemented | Candidate |
| Metal | Unsupported | Unsupported | Unsupported | Unsupported | Implemented | iOS implemented; other Apple systems future |
| BLAS/OpenBLAS | New | New | New | New | New | Future |
| llamafile | New | New | New | New | New | Future |
| RPC | New | New | New | New | New | Candidate |
| OpenVINO | New | Excluded | New | New | Candidate | Candidate |
| WebGPU/Dawn | New | New | New | New | New | Candidate |

Android and Apple support expressions must be validated with real ggml backend
code and available SDK/toolchain ports before widening the initial expressions.

## Dependency discoveries

### Implementable with current vcpkg ports

- **OpenBLAS:** `openblas` 0.3.x supplies CMake-discoverable BLAS for
  `GGML_BLAS_VENDOR=OpenBLAS`.
- **OpenVINO:** `openvino` supplies runtime and threading targets and has a
  `cpu` feature. ggml also directly links `OpenCL::OpenCL`.
- **Dawn:** `dawn` supplies the `dawn::webgpu_dawn` target expected by
  `ggml-webgpu`.
- **Vulkan toolchain:** `vulkan`, `spirv-headers`, and `shaderc` exist. `shaderc`
  installs host `glslc`; this backend still needs integration work before
  exposing a manifest feature.
- **KleidiAI:** a `kleidiai` port exists for ARM64, but upstream ggml v1.0.0
  currently performs its own `FetchContent`, so the vcpkg dependency alone is
  not sufficient.

### No additional package required

- **RPC:** implemented with ggml's transport sources and platform sockets. Optional
  RDMA discovery remains a separate enhancement.
- **llamafile:** implemented inside the ggml CPU backend.

### SDK or implementation blockers

| Backend | Required dependency | vcpkg result / blocker |
|---|---|---|
| HIP | ROCm HIP, hipBLAS, rocBLAS | No matching complete vcpkg ROCm SDK |
| SYCL | Intel oneAPI SYCL, MKL, oneDNN | Libraries exist, but no complete host compiler/toolchain port |
| CANN | Ascend toolkit | Vendor SDK required |
| MUSA | Moore Threads toolkit | Vendor SDK required |
| Hexagon | Qualcomm Hexagon SDK and tools | Vendor SDK plus signing inputs required |
| zDNN | IBM zDNN | No compatible port |
| ZenDNN | AMD ZenDNN | No compatible port |
| VirtGPU | libdrm, API remoting, backend implementation | Incomplete vcpkg dependency coverage |

## Phased implementation

### Phase 1: Validate the new manifest features

1. Build `blas`, `llamafile`, `rpc`, `openvino`, and `webgpu` independently on
   `x64-windows`.
2. Build representative no-CUDA combinations to catch transitive target issues.
3. Build `arm64-windows` for `blas`, `llamafile`, `rpc`, and `webgpu`.
4. Build `x64-linux` and `arm64-linux` for `blas`, `rpc`, `openvino`, and
   `webgpu`.
5. Keep all feature packages opt-in and non-default.

### Phase 2: Make Vulkan reproducible

1. Add target dependencies on `vulkan` and `spirv-headers`.
2. Add a host-only `shaderc` dependency for `glslc`.
3. Map `GGML_VULKAN` in `vcpkg_check_features`.
4. Pass `Vulkan_GLSLC_EXECUTABLE` from the host-installed `shaderc` tools.
5. Patch or stabilize upstream `vulkan-shaders-gen` output handling. The
   generated shader issue must be fixed before this becomes public.
6. Validate Windows, Linux, and Android first; add macOS only when the Vulkan
   loader/MoltenVK policy is defined.

### Phase 3: Integrate KleidiAI without FetchContent

1. Replace upstream ggml's KleidiAI `FetchContent` block with CMake target
   discovery against the vcpkg `kleidiai` port.
2. Verify the expected package target names and config file.
3. Add the `kleidiai` feature only for ARM64 targets.
4. Test Windows ARM64 ClangCL, Linux ARM64, Android ARM64, and macOS ARM64.

### Phase 4: Add controlled CPU features

1. Add `cpu-hbm` after identifying a portable vcpkg `memkind` dependency.
2. Consider a `lto` feature for supported compilers.
3. Do not expose individual AVX, AVX-512, RISC-V, or LoongArch flags as vcpkg
   features; those are triplet/compiler policies and belong in the triplet or
   target-specific default logic.

### Phase 5: UI and application surfaces

1. Keep prebuilt UI disabled by default to prevent network downloads.
2. Add a dedicated `ui` feature only if UI assets are acquired from an immutable,
   checksummed vcpkg download.
3. Do not install tests by default. Add a CI-only validation path instead.
4. Keep `tools` as the supported end-user executable feature.

## Required portfile work

- Acquire Python for `opencl` or `webgpu`.
- Keep host tool dependencies marked `"host": true`.
- Set `GGML_BLAS_VENDOR=OpenBLAS` only when `blas` is enabled.
- Keep static linkage metadata synchronized through `GGML_STATIC`.
- Keep CUDA, Vulkan, and Dawn toolchain setup feature-gated.
- Preserve separate llama.cpp and ggml source acquisition and patch roots.

## Validation commands

Representative commands:

```powershell
vcpkg install --overlay-ports .\ports 'llama-cpp[blas]:x64-windows'
vcpkg install --overlay-ports .\ports 'llama-cpp[llamafile]:x64-windows'
vcpkg install --overlay-ports .\ports 'llama-cpp[rpc]:x64-windows'
vcpkg install --overlay-ports .\ports 'llama-cpp[openvino]:x64-windows'
vcpkg install --overlay-ports .\ports 'llama-cpp[webgpu]:x64-windows'
```

For each feature:

1. Confirm configure consumes the intended CMake option.
2. Build Debug and Release.
3. Run post-build validation.
4. Link a consumer through installed CMake config files.
5. Confirm the generated backend library is installed.
6. Confirm no vendored source or remote `FetchContent` bypass remains.

## Acceptance criteria

- Every public manifest feature maps to a real CMake option.
- Every external dependency is represented in `vcpkg.json`.
- Every `supports` expression matches the dependency and backend.
- No feature performs network downloads during configuration or build.
- No system-only SDK is hidden behind an apparently portable vcpkg feature.
- Baseline/version files are updated only after the port commits.
