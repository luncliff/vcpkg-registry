# llama.cpp and ggml: Architecture and Relationship

This document summarizes the roles of the
[ggml](https://github.com/ggml-org/ggml) and
[llama.cpp](https://github.com/ggml-org/llama.cpp) projects.

## Summary

| Project | Primary role | What it provides |
|---|---|---|
| ggml | Tensor and accelerator runtime | Tensors, computation graphs, memory allocation, quantization, GGUF support, and hardware backends |
| llama.cpp | LLM/MLLM inference framework | Model loading, model architectures, tokenization, sampling, KV caches, CLI, server, and integrations |

The short mental model is:

```text
llama-server / llama-cli / bindings / applications
                         |
                 llama.cpp model API
                         |
                ggml tensors and graphs
                         |
      CPU / CUDA / Metal / Vulkan / other backends
```

## ggml

ggml is a standalone tensor library for machine learning. It aims to be portable,
efficient, lightweight, and usable with minimal setup.

Its responsibilities include:

- Tensor types and tensor operations
- Lazy computation graphs
- Graph memory planning and allocation
- Quantized tensor formats
- GGUF reading support
- Hardware backend abstraction
- Device memory management
- CPU SIMD kernels
- CUDA, Metal, Vulkan, HIP, SYCL, RPC, OpenCL, WebGPU, and other backend implementations
- Flash-attention and other accelerator-specific optimizations

The core ggml repository describes itself as a plain C/C++ implementation
without dependencies and supports x86, ARM, RISC-V, LoongArch, PowerPC,
s390x, and WebAssembly. Optional backends add vendor SDK or framework
dependencies; the core remains independent of a particular model format or
transformer architecture.

### ggml design

A ggml application normally follows this sequence:

1. Create tensors.
2. Build a computation graph from tensor operations.
3. Allocate tensor and graph memory.
4. Select CPU or accelerator buffers and backends.
5. Schedule graph operations.
6. Execute the graph.
7. Read the output tensor.

Important public abstractions include:

- `ggml_tensor`: a tensor shape, type, data, source, and operation
- `ggml_cgraph`: a collection of tensors and graph execution information
- `ggml_gallocr` and related allocators: graph memory allocation
- `ggml_backend`: an execution and memory-management interface
- `ggml_backend_sched`: scheduling across multiple backends
- `ggml_backend_reg`: backend discovery and registration
- GGUF types: serialized model metadata and tensor data

ggml does not normally know that it is executing Llama, Gemma, or Qwen.
Those model-specific concepts belong above ggml.

### ggml repository layout

The ggml repository is organized around its library and backend implementations:

- `include/`: public tensor, allocation, backend, GGUF, and backend API headers
- `src/`: core implementation and hardware-specific backend directories
- `src/ggml-cpu/`: CPU backend and architecture-specific kernels
- `src/ggml-cuda/`: CUDA backend
- `src/ggml-metal/`: Metal backend
- `src/ggml-vulkan/`: Vulkan backend
- `src/ggml-hip/`: HIP/ROCm backend
- `tests/`: core tests
- `examples/`: standalone library examples
- `docs/`: format and project documentation

## llama.cpp

llama.cpp is an inference framework for large language models and multimodal
models. It is built on top of ggml.

Its responsibilities include:

- Loading and validating GGUF model files
- Mapping GGUF tensors to model layers
- Implementing model-specific architectures
- Loading tokenizer vocabulary and metadata
- Building model-specific ggml computation graphs
- Context and KV-cache management
- Recurrent, hybrid, sliding-window, and other memory implementations
- Logit processing and sampling
- Chat templates and prompt formatting
- Grammar and constrained generation
- Multi-GPU, tensor, and layer split strategies
- Embeddings and reranking
- Vision, audio, speech, and text-to-speech integrations
- CLI and HTTP server tools
- Model conversion and quantization utilities

llama.cpp is therefore a consumer and assembler of ggml primitives. It turns
those primitives into the behavior of an entire inference model.

### llama.cpp design

A typical llama.cpp inference flow is:

```text
GGUF file
  -> llama_model_loader
  -> llama_model
  -> architecture-specific graph construction
  -> llama_context and KV cache
  -> ggml computation graph
  -> backend scheduler
  -> CPU or accelerator kernel
  -> logits
  -> llama_sampler
  -> next token
```

Important layers include:

- **Public C API:** `include/llama.h`
- **Model loader:** GGUF parsing, tensor mapping, model metadata, and memory mapping
- **Model implementations:** architecture-specific classes under `src/models/`
- **Graph construction:** model layers and attention/feed-forward operations expressed as ggml graphs
- **Context:** decode state and batch management
- **Memory:** KV, recurrent, hybrid, and sparse cache implementations
- **Vocabulary:** tokenization and detokenization
- **Sampler:** temperature, top-p, top-k, min-p, Mirostat, penalties, and related algorithms
- **Applications:** CLI, server, completion tools, tests, examples, and app UI

The public [llama.h](https://github.com/ggml-org/llama.cpp/blob/master/include/llama.h)
header includes ggml headers directly. This is a consequence of the tight
relationship: llama.cpp APIs expose and use ggml concepts where those concepts
are relevant to loading, evaluating, and configuring models.

### llama.cpp repository layout

Key directories and files include:

- `include/llama.h`: public C inference API
- `src/`: llama.cpp core implementation
- `src/models/`: model architecture implementations
- `src/llama-model.cpp`: architecture dispatch and model construction
- `src/llama-context.cpp`: context and execution state
- `src/llama-graph.cpp`: graph helpers
- `src/llama-kv-cache*.cpp`: KV and memory implementations
- `common/`: command-line and shared application utilities
- `tools/`: CLI, server, multimodal, and helper tools
- `examples/`: examples and proof-of-concept programs
- `ggml/`: ggml sources mirrored for standalone llama.cpp builds
- `vendor/`: third-party and vendor integration targets
- `grammars/`: GBNF grammar support and examples
- `docs/`: build, deployment, hardware, and development documentation

## Relationship

llama.cpp depends on ggml as a lower-level library.

The llama.cpp top-level CMake configuration:

- Adds ggml as a subdirectory in a normal standalone build.
- Links the public `llama` target to `ggml`.
- Overrides selected ggml build defaults.
- Can use an externally installed ggml when
  `LLAMA_USE_SYSTEM_GGML=ON` is enabled.
- Builds the same high-level llama.cpp targets with or without tools,
  tests, server, app, examples, and standalone multimodal libraries.

The llama.cpp repository currently contains its own ggml source tree under
`ggml/`, mirroring the standalone ggml repository for integrated builds.
This does not make llama.cpp and ggml equivalent projects. ggml remains the
general tensor runtime, while llama.cpp is the model-focused application
layer.

The ggml repository explicitly directs contributors making core library or
CMake changes to open their pull request in llama.cpp. The project favors
llama.cpp's broader build coverage and integration testing, while the change
can later be synchronized to the standalone ggml repository.

Compatibility is therefore generally tested most strongly as a coordinated
llama.cpp/ggml pair. Mixing llama.cpp with an arbitrary standalone ggml version
is not guaranteed to work.

## Dependencies

### ggml dependencies

The core ggml build requires:

- CMake
- C compiler
- C++ compiler
- POSIX threads
- C11
- C++17

Optional feature dependencies include:

- CUDA and NVIDIA toolkits
- ROCm/HIP
- Vulkan
- Apple Metal
- Apple Accelerate
- BLAS implementations
- SYCL/oneAPI
- OpenCL
- OpenVINO
- RPC support
- CANN
- WebGPU
- MUSA
- Vendor NPU SDKs

CPU instruction-specific kernels may be enabled for AVX, AVX-512, AMX,
AArch64 SIMD, RISC-V, and other architectures.

### llama.cpp dependencies

llama.cpp depends on:

- ggml
- POSIX threads

Optional llama.cpp features add:

- OpenSSL for HTTPS support
- LLGuidance for structured output
- Subprocess support for tools and server router mode

The server and multimodal implementation may use third-party libraries
acknowledged in the llama.cpp repository, including:

- `cpp-httplib`
- `stb`
- `nlohmann/json`
- `miniaudio`
- `subprocess.h`

The exact third-party set can vary as llama.cpp adds or removes features.
The repository and CMake options are the authoritative source.

## CMake build options

The lists below summarize `option(...)` declarations in the upstream top-level
CMake files at the repository state used for this research.
Options inherited from CMake, such as `CMAKE_BUILD_TYPE`, are included only
when they have project-specific meaning.
The results were surveyed in parallel against the llama.cpp and ggml upstream
master CMake files.

### llama.cpp options

- `LLAMA_BUILD_IS_DEV=ON`: Appends `-dev` to the llama.cpp version for development and nightly builds.
- `LLAMA_USE_SYSTEM_GGML=OFF`: Finds and links an externally installed `libggml` instead of building the mirrored ggml sources.
- `LLAMA_WASM_MEM64=ON`: Enables 64-bit memory addressing in WebAssembly builds.
- `LLAMA_WASM_SINGLE_FILE=OFF`: Embeds the WebAssembly build into a single JavaScript output file.
- `LLAMA_BUILD_HTML=ON`: Builds the WebAssembly HTML page.
- `BUILD_SHARED_LIBS=...`: Builds llama.cpp and ggml libraries as shared libraries on most platforms and static libraries on MinGW or Emscripten.
- `LLAMA_ALL_WARNINGS=ON`: Enables the project-wide compiler warning set.
- `LLAMA_ALL_WARNINGS_3RD_PARTY=OFF`: Enables warnings from third-party source code.
- `LLAMA_FATAL_WARNINGS=OFF`: Treats warnings as compilation errors.
- `LLAMA_SANITIZE_THREAD=OFF`: Builds with the ThreadSanitizer.
- `LLAMA_SANITIZE_ADDRESS=OFF`: Builds with the AddressSanitizer.
- `LLAMA_SANITIZE_UNDEFINED=OFF`: Builds with the UndefinedBehaviorSanitizer.
- `LLAMA_BUILD_COMMON=standalone`: Builds shared command-line and application utilities used by llama.cpp tools.
- `LLAMA_BUILD_TESTS=standalone`: Builds the llama.cpp test suite.
- `LLAMA_BUILD_TOOLS=standalone`: Builds CLI and supporting tools.
- `LLAMA_BUILD_EXAMPLES=standalone`: Builds examples and proof-of-concept programs.
- `LLAMA_BUILD_SERVER=standalone`: Builds the llama-server HTTP application.
- `LLAMA_BUILD_APP=standalone`: Builds the unified llama.cpp application binary.
- `LLAMA_BUILD_UI=OFF`: Embeds Llama Chat in llama-server.
- `LLAMA_USE_PREBUILT_UI=ON`: Downloads a prebuilt UI bundle when a UI build is available.
- `LLAMA_CONNECT=OFF`: Includes the llama-connect tool for downloading a prebuilt binary.
- `LLAMA_TOOLS_INSTALL=...`: Installs built tools; this defaults to `OFF` on iOS and otherwise follows `LLAMA_STANDALONE`.
- `LLAMA_TESTS_INSTALL=ON`: Installs test binaries.
- `LLAMA_OPENSSL=ON`: Enables OpenSSL for HTTPS support.
- `LLAMA_SUBPROCESS=...`: Enables subprocess support except on iOS, Android, Emscripten, and WASI, where it defaults to `OFF`.
- `LLAMA_LLGUIDANCE=OFF`: Adds LLGuidance support for grammar and structured-output generation.
- `LLAMA_BUILD_MTMD=OFF`: Builds the multimodal library (`mtmd`) as a standalone target.

llama.cpp also recognizes deprecated compatibility options:

- `LLAMA_CUBLAS` maps to `GGML_CUDA`.
- `LLAMA_CUDA` maps to `GGML_CUDA`.
- `LLAMA_METAL` maps to `GGML_METAL`.
- `LLAMA_METAL_EMBED_LIBRARY` maps to `GGML_METAL_EMBED_LIBRARY`.
- `LLAMA_NATIVE` maps to `GGML_NATIVE`.
- `LLAMA_RPC` maps to `GGML_RPC`.
- `LLAMA_SYCL` maps to `GGML_SYCL`.
- `LLAMA_SYCL_F16` maps to `GGML_SYCL_F16`.
- `LLAMA_CANN` maps to `GGML_CANN`.
- `LLAMA_CURL` is deprecated and ignored after emitting a warning.

### ggml options

#### General and build behavior

- `BUILD_SHARED_LIBS=...`: Builds ggml libraries as shared or static libraries according to platform defaults.
- `GGML_BACKEND_DL=OFF`: Builds compatible backends as dynamically loaded shared libraries.
- `GGML_STATIC=OFF`: Selects static linkage behavior for ggml targets.
- `GGML_NATIVE=platform-dependent`: Optimizes the build for the current host CPU.
- `GGML_LTO=OFF`: Enables link-time optimization.
- `GGML_CCACHE=ON`: Uses ccache for compilation when it is available.
- `GGML_ALL_WARNINGS=ON`: Enables the project-wide compiler warning set.
- `GGML_ALL_WARNINGS_3RD_PARTY=OFF`: Enables warnings from third-party source code.
- `GGML_GPROF=OFF`: Builds with gprof instrumentation.
- `GGML_FATAL_WARNINGS=OFF`: Treats warnings as compilation errors.
- `GGML_SANITIZE_THREAD=OFF`: Builds with the ThreadSanitizer.
- `GGML_SANITIZE_ADDRESS=OFF`: Builds with the AddressSanitizer.
- `GGML_SANITIZE_UNDEFINED=OFF`: Builds with the UndefinedBehaviorSanitizer.
- `GGML_BUILD_TESTS=standalone`: Builds ggml tests.
- `GGML_BUILD_EXAMPLES=standalone`: Builds ggml examples.
- `GGML_WASM_SINGLE_FILE=ON`: Embeds standalone ggml WebAssembly output into a single JavaScript file.
- `GGML_CPU_ALL_VARIANTS=OFF`: Builds multiple CPU backend variants for runtime dispatch when dynamic backends are enabled.

#### CPU and scheduler options

- `GGML_CPU=ON`: Builds and enables the CPU backend.
- `GGML_SCHED_NO_REALLOC=OFF`: Disallows runtime reallocations in ggml graph allocation for debugging.
- `GGML_CPU_HBM=OFF`: Enables memkind support for CPU high-bandwidth memory.
- `GGML_CPU_REPACK=ON`: Converts supported weight formats to optimized runtime representations.
- `GGML_CPU_KLEIDIAI=OFF`: Enables KleidiAI kernels when applicable.
- `GGML_NATIVE` also controls whether architecture-specific instruction options are manually enabled.
- `GGML_SSE42=...`: Enables SSE 4.2 CPU kernels.
- `GGML_AVX=...`: Enables AVX CPU kernels.
- `GGML_AVX_VNNI=OFF`: Enables AVX-VNNI CPU kernels.
- `GGML_AVX2=...`: Enables AVX2 CPU kernels.
- `GGML_BMI2=...`: Enables BMI2 CPU instructions.
- `GGML_AVX512=OFF`: Enables AVX-512F CPU kernels.
- `GGML_AVX512_VBMI=OFF`: Enables AVX512-VBMI CPU kernels.
- `GGML_AVX512_VNNI=OFF`: Enables AVX512-VNNI CPU kernels.
- `GGML_AVX512_BF16=OFF`: Enables AVX512-BF16 CPU kernels.
- `GGML_FMA=...`: Enables FMA CPU instructions outside MSVC builds.
- `GGML_F16C=...`: Enables F16C CPU instructions outside MSVC builds.
- `GGML_AMX_TILE=OFF`: Enables AMX tile support outside MSVC builds.
- `GGML_AMX_INT8=OFF`: Enables AMX INT8 CPU kernels outside MSVC builds.
- `GGML_AMX_BF16=OFF`: Enables AMX BF16 CPU kernels outside MSVC builds.
- `GGML_LASX=ON`: Enables LoongArch LASX SIMD kernels.
- `GGML_LSX=ON`: Enables LoongArch LSX SIMD kernels.
- `GGML_RVV=ON`: Enables RISC-V RVV vector kernels.
- `GGML_RV_ZFH=ON`: Enables RISC-V Zfh half-precision support.
- `GGML_RV_ZVFH=ON`: Enables RISC-V Zvfh vector half-precision support.
- `GGML_RV_ZICBOP=ON`: Enables RISC-V Zicbop support.
- `GGML_RV_ZIHINTPAUSE=ON`: Enables RISC-V zihintpause support.
- `GGML_RV_ZVFBFWMA=OFF`: Enables RISC-V Zvfbfwma support.
- `GGML_XTHEADVECTOR=OFF`: Enables XTHeadVector support.
- `GGML_VXE=...`: Enables IBM Z vector support.

#### Accelerator and third-party backends

- `GGML_ACCELERATE=ON`: Uses Apple's Accelerate framework.
- `GGML_BLAS=platform-dependent`: Uses a BLAS implementation instead of or alongside the generic backend.
- `GGML_LLAMAFILE=platform-dependent`: Uses llamafile for compatible runtime features.
- `GGML_CUDA=OFF`: Builds the NVIDIA CUDA backend.
- `GGML_MUSA=OFF`: Builds the MUSA accelerator backend.
- `GGML_CUDA_FORCE_MMQ=OFF`: Prefers CUDA MMQ kernels over cuBLAS matrix-multiplication kernels.
- `GGML_CUDA_FORCE_CUBLAS=OFF`: Always prefers cuBLAS over CUDA MMQ kernels.
- `GGML_CUDA_NO_PEER_COPY=OFF`: Disables CUDA peer-to-peer tensor copies.
- `GGML_CUDA_NO_VMM=OFF`: Disables CUDA virtual-memory-management use.
- `GGML_CUDA_FA=ON`: Builds CUDA FlashAttention kernels.
- `GGML_CUDA_FA_ALL_QUANTS=OFF`: Builds FlashAttention kernels for all supported quantized type combinations.
- `GGML_CUDA_GRAPHS=OFF`: Enables CUDA graph capture and reuse.
- `GGML_CUDA_NCCL=ON`: Builds support for NVIDIA NCCL collective communication.
- `GGML_HIP=OFF`: Builds the AMD HIP/ROCm backend.
- `GGML_HIP_GRAPHS=ON`: Enables HIP graph capture and reuse.
- `GGML_HIP_RCCL=OFF`: Builds support for ROCm RCCL collective communication.
- `GGML_HIP_NO_VMM=ON`: Disables HIP virtual-memory-management use.
- `GGML_HIP_MMQ_MFMA=ON`: Enables MFMA MMA kernels for CDNA MMQ operations.
- `GGML_HIP_EXPORT_METRICS=OFF`: Exports HIP kernel performance metrics.
- `GGML_MUSA_GRAPHS=OFF`: Enables MUSA graph support.
- `GGML_MUSA_MUDNN_COPY=OFF`: Enables muDNN-based tensor copies.
- `GGML_VULKAN=OFF`: Builds the Vulkan backend.
- `GGML_VULKAN_CHECK_RESULTS=OFF`: Checks Vulkan operation results for debugging.
- `GGML_VULKAN_DEBUG=OFF`: Enables Vulkan debug output.
- `GGML_VULKAN_MEMORY_DEBUG=OFF`: Enables Vulkan memory debugging.
- `GGML_VULKAN_SHADER_DEBUG_INFO=OFF`: Adds shader debug information to Vulkan builds.
- `GGML_VULKAN_VALIDATE=OFF`: Enables the Vulkan validation layer.
- `GGML_VULKAN_RUN_TESTS=OFF`: Runs Vulkan-specific tests during the build workflow.
- `GGML_WEBGPU=OFF`: Builds the WebGPU backend.
- `GGML_WEBGPU_DEBUG=OFF`: Enables WebGPU debug output.
- `GGML_WEBGPU_CPU_PROFILE=OFF`: Enables CPU profiling for WebGPU operations.
- `GGML_WEBGPU_GPU_PROFILE=OFF`: Enables GPU profiling for WebGPU operations.
- `GGML_WEBGPU_JSPI=ON`: Enables JavaScript Promise Integration for WebAssembly WebGPU builds.
- `GGML_ZDNN=OFF`: Builds the IBM zDNN backend.
- `GGML_VIRTGPU=OFF`: Builds the VirtGPU/Virglrenderer API remoting frontend.
- `GGML_VIRTGPU_BACKEND=OFF`: Builds the VirtGPU/Virglrenderer backend.
- `GGML_METAL=platform-dependent`: Builds the Apple Metal backend.
- `GGML_METAL_NDEBUG=OFF`: Disables Metal debug behavior.
- `GGML_METAL_SHADER_DEBUG=OFF`: Compiles Metal shaders without fast-math optimization for debugging.
- `GGML_METAL_EMBED_LIBRARY=...`: Embeds the compiled Metal library in the executable.
- `GGML_OPENMP=ON`: Enables OpenMP parallelism.
- `GGML_OPENMP_FETCH=OFF`: Fetches an LLVM OpenMP implementation when needed.
- `GGML_RPC=OFF`: Builds the RPC backend for remote tensor execution.
- `GGML_SYCL=OFF`: Builds the Intel SYCL backend.
- `GGML_SYCL_F16=OFF`: Enables 16-bit float SYCL code paths.
- `GGML_SYCL_SUPPORT_XMX=ON`: Builds SYCL XMX/DPAS code paths.
- `GGML_SYCL_GRAPH=ON`: Enables graph capture and reuse in the SYCL backend.
- `GGML_SYCL_HOST_MEM_FALLBACK=ON`: Allows host-memory fallback during SYCL reorder operations.
- `GGML_SYCL_SUPPORT_LEVEL_ZERO_API=ON`: Enables the SYCL Level Zero API.
- `GGML_SYCL_DNN=ON`: Enables oneDNN operations in the SYCL backend.
- `GGML_OPENVINO=OFF`: Builds the OpenVINO backend.
- `GGML_ET=OFF`: Builds the ET experimental backend.
- `GGML_ET_SYSEMU=OFF`: Builds the ET backend through system emulation.
- `GGML_OPENCL=OFF`: Builds the OpenCL backend.
- `GGML_OPENCL_PROFILING=OFF`: Enables OpenCL performance profiling.
- `GGML_OPENCL_EMBED_KERNELS=ON`: Embeds OpenCL kernels in the library.
- `GGML_OPENCL_USE_ADRENO_KERNELS=ON`: Uses optimized kernels for Qualcomm Adreno GPUs.
- `GGML_HEXAGON=OFF`: Enables the Qualcomm Hexagon backend.
- `GGML_ZENDNN=OFF`: Enables the AMD ZenDNN backend.
- `ZENDNN_ROOT=empty`: Supplies the installation path for the AMD ZenDNN dependency.

### Important non-boolean CMake cache settings

- `GGML_BACKEND_DIR`: Overrides the directory used to locate dynamically loaded backends.
- `GGML_CPU_ARM_ARCH`: Sets the target ARM CPU architecture.
- `GGML_CPU_POWERPC_CPUTYPE`: Sets the target PowerPC CPU type.
- `GGML_SCHED_MAX_COPIES=4`: Sets the maximum number of scheduler input copies.
- `GGML_BLAS_VENDOR=Apple|Generic|...`: Selects the BLAS vendor implementation.
- `GGML_CUDA_CCCL_VERSION`: Pins a CCCL source revision when CUDA does not provide the desired bundled CCCL version.
- `GGML_CUDA_FA_QUANTS`: Lists the quantization type combinations for CUDA FlashAttention.
- `GGML_CUDA_COMPRESSION_MODE=size`: Controls CUDA binary compression: none, speed, balance, or size.
- `GGML_METAL_MACOSX_VERSION_MIN`: Sets the minimum macOS deployment version for Metal.
- `GGML_METAL_STD`: Overrides the Metal shading-language compiler standard.
- `GGML_METAL_TARGET_OS=macos`: Selects macOS, iOS, xrOS, or tvOS for the Metal target.
- `GGML_OPENMP_FETCH=OFF`: Controls whether LLVM OpenMP is fetched instead of discovered locally.
- `GGML_SYCL_TARGET=INTEL`: Selects the SYCL target.
- `GGML_SYCL_DEVICE_ARCH`: Overrides the target SYCL device architecture.
- `GGML_OPENCL_TARGET_VERSION=300`: Sets the OpenCL API target version.
- `GGML_VULKAN_SHADERS_GEN_TOOLCHAIN`: Supplies a toolchain file for the Vulkan shader generator.
- `LLAMA_INCLUDE_INSTALL_DIR`, `LLAMA_LIB_INSTALL_DIR`, and `LLAMA_BIN_INSTALL_DIR`: Configure llama.cpp installation directories.
- `GGML_INCLUDE_INSTALL_DIR`, `GGML_LIB_INSTALL_DIR`, and `GGML_BIN_INSTALL_DIR`: Configure ggml installation directories.

## Build and API relationship

At CMake level:

```text
llama -> ggml
llama-common -> llama, ggml, and common utilities
server/tools -> llama-common and llama
llama model libraries -> ggml
```

At source level:

- llama.cpp includes ggml headers.
- llama.cpp links the `llama` target to `ggml`.
- ggml backend selection is controlled by ggml CMake options.
- llama.cpp options map deprecated LLAMA-prefixed backend names to
  GGML-prefixed names.
- `LLAMA_USE_SYSTEM_GGML` allows external ggml discovery through CMake's
  `find_package(ggml)`.

## Scope comparison

| Concern | ggml | llama.cpp |
|---|---|---|
| Tensor operations | Core responsibility | Uses ggml tensors |
| Computation graphs | Core responsibility | Builds model graphs |
| Quantization primitives | Core responsibility | Uses quantization for model loading and conversion |
| GGUF parsing | Tensor metadata and format support | Complete model metadata and tensor interpretation |
| Backend acceleration | Core responsibility | Configures and consumes backends |
| Model architecture | Not included | Core responsibility |
| Tokenization | Not included | Core responsibility |
| Sampling | Not included | Core responsibility |
| KV cache | Generic memory support | Inference-specific cache logic |
| HTTP server | Not included | Tool implementation |
| CLI | Minimal examples | Full application tools |
| Public API | Tensor/backend API | Inference/model API |

## When to use each project

Use ggml when:

- Building a custom tensor runtime or ML framework
- Implementing model operations not tied to llama.cpp
- Writing accelerator kernels or backend integrations
- Benchmarking tensor or graph execution
- Needing a low-level C/C++ backend abstraction

Use llama.cpp when:

- Loading and running GGUF models
- Serving language or multimodal models
- Supporting chat templates and model-specific architectures
- Requiring tokenization, sampling, KV caches, and constrained generation
- Providing a CLI, HTTP API, or language binding
- Deploying optimized local inference

## Conclusion

ggml and llama.cpp form a dependency and abstraction stack rather than two
competing implementations.

ggml answers: "How are tensors computed and executed efficiently on available
hardware?"

llama.cpp answers: "How is a model loaded, decoded, sampled, and exposed to a
user or application?"

The relationship is intentionally close: llama.cpp supplies real-world model
requirements that drive ggml features, while ggml provides the low-level
execution system on which llama.cpp relies.

## Sources

Research sources checked on 2026-11-21:

- [ggml README](https://github.com/ggml-org/ggml#readme)
- [llama.cpp README](https://github.com/ggml-org/llama.cpp#readme)
- [ggml CMake configuration](https://github.com/ggml-org/ggml/blob/master/CMakeLists.txt)
- [llama.cpp CMake configuration](https://github.com/ggml-org/llama.cpp/blob/master/CMakeLists.txt)
- [llama.cpp source CMake configuration](https://github.com/ggml-org/llama.cpp/blob/master/src/CMakeLists.txt)
- [llama.cpp public API](https://github.com/ggml-org/llama.cpp/blob/master/include/llama.h)
- [llama.cpp model implementation](https://github.com/ggml-org/llama.cpp/blob/master/src/llama-model.cpp)
- [ggml source layout](https://github.com/ggml-org/ggml/tree/master/src)
- [llama.cpp repository layout](https://github.com/ggml-org/llama.cpp)
