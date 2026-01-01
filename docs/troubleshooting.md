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
- [GCC Manual](https://gcc.gnu.org/onlinedocs/gcc-15.2.0/gcc/)

### Linker Errors

When encountering linker errors:

Resources:
- [LINK.exe Options](https://learn.microsoft.com/en-us/cpp/build/reference/linker-options)
- [Clang Command Line Reference](https://clang.llvm.org/docs/ClangCommandLineReference.html)
- [LLD Linker Documentation](https://lld.llvm.org/)
- [GCC Link Options](https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html)

### vcpkg-Specific Issues

Common vcpkg pitfalls:

- **Triplet mismatches**: Ensure consistent triplet usage
- **Overlay ports conflicts**: Check overlay port priority
- **Feature flag issues**: Verify feature dependencies
- **Version baseline**: Confirm version entries are up-to-date
