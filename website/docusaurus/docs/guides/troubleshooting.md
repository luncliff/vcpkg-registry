# Troubleshooting: Port Installation & Build Errors

This guide helps diagnose and fix common issues when creating or updating ports. It serves as a central troubleshooting hub in the workflow:
- **Create port** → Install port → **Troubleshoot** → Update port
- **Update port** → Install port → **Troubleshoot**
- **Check environment** → **Troubleshoot**

Related prompts: `/install-port`, `/check-environment`, `/review-port`

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

### Linker Errors

When encountering linker errors:

Resources:
- [LINK.exe Options](https://learn.microsoft.com/en-us/cpp/build/reference/linker-options)
- [Clang Command Line Reference](https://clang.llvm.org/docs/ClangCommandLineReference.html)

### vcpkg-Specific Issues

Common vcpkg pitfalls:

- **Triplet mismatches**: Ensure consistent triplet usage
- **Overlay ports conflicts**: Check overlay port priority
- **Feature flag issues**: Verify feature dependencies
- **Version baseline**: Confirm version entries are up-to-date

## Alternative Approach: Embedded CMakeLists.txt

When patch files become too complex or frequently fail to apply due to upstream changes, you can use the **embedded CMakeLists.txt approach** as demonstrated in [ports like `farmhash`](../ports/farmhash/).

#### How It Works

1. **Download Original**: Download the original CMakeLists.txt from the target version
   ```bash
   curl -o "ports/port-name/CMakeLists.txt" "https://raw.githubusercontent.com/OWNER/REPO/vX.Y.Z/CMakeLists.txt"
   ```

2. **Embed and Modify**: Place the file directly in your port directory and modify it in-place to work with vcpkg dependencies

3. **Copy in Portfile**: Use `file(COPY)` to overwrite the original during build:
   ```cmake
   # Copy our modified CMakeLists.txt
   file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")
   ```

#### Benefits
- **Easier Maintenance**: Direct file editing instead of complex patch management
- **Clearer Review**: Developers can see exact changes in the embedded file
- **No Patch Failures**: Eliminates patch application context mismatches
- **Rapid Prototyping**: Faster iteration during port development

#### ⚠️ **Important Warning for Upstream Contributions**

> **This approach is primarily for experimental/private registries.** 
> 
> If you plan to contribute the port to **microsoft/vcpkg upstream**, you **MUST** convert the embedded CMakeLists.txt changes back to proper patch files before submitting. The vcpkg upstream strongly prefers patch files over embedded source files for the following reasons:
> 
> - **Maintainability**: Patches show exactly what changed
> - **Upstream Compatibility**: Easier to review and maintain
> - **Standards Compliance**: Follows vcpkg contribution guidelines
> - **Conflict Reduction**: Minimizes merge conflicts with upstream changes
> 
> **Conversion Process**: Use `git diff` or `diff` tools to generate proper patch files from your embedded changes before submitting to upstream.

#### When to Use This Approach
- ✅ Complex build systems with frequent CMakeLists.txt changes
- ✅ Experimental ports in private registries  
- ✅ Rapid prototyping and testing
- ✅ When traditional patches repeatedly fail to apply
