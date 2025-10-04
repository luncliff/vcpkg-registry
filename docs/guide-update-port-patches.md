# Guide: Patch Maintenance for Port Updates

This document covers patch management strategies during port updates, including conflict resolution and the embedded CMakeLists.txt approach. It complements the main [port update guide](./guide-update-port.md).

## 1. Patch Management Overview

When updating ports, existing patches may:
- Apply cleanly to the new version ✅
- Fail to apply due to context changes ⚠️
- Become obsolete (upstream fixed the issue) ♻️
- Need updates for new issues 🆕

## 2. Patch Application Testing

### Quick Patch Test
```powershell
# Test if existing patches still work
vcpkg install --overlay-ports=ports port-name

# If this fails with patch errors, patches need attention
```

### Manual Patch Verification
```powershell
# Extract source to inspect patch application
vcpkg install --overlay-ports=ports port-name --keep-sources

# Navigate to source directory
cd buildtrees/port-name/src/version-hash/

# Apply patches manually to test
git apply ../../../ports/port-name/fix-cmake.patch
```

## 3. Patch Update Strategies

### Strategy 1: Update Existing Patches

When patches fail due to line number changes or minor context differences:

1. **Extract the source:**
```powershell
vcpkg install --overlay-ports=ports port-name --keep-sources
cd buildtrees/port-name/src/
```

2. **Create a clean working directory:**
```powershell
git init
git add .
git commit -m "Upstream source"
```

3. **Try applying the old patch:**
```powershell
git apply --reject ../../../ports/port-name/old-patch.patch
```

4. **Fix rejections manually and create updated patch:**
```powershell
# Edit files to fix .rej files
git add .
git commit -m "Apply fixes"
git format-patch HEAD~1 --stdout > ../../../ports/port-name/updated-patch.patch
```

### Strategy 2: Remove Obsolete Patches

Check if the patch is still needed:

1. **Test without the patch:**
```cmake
# Comment out patch in portfile.cmake
# vcpkg_apply_patches(
#     SOURCE_PATH ${SOURCE_PATH}
#     PATCHES
#         fix-cmake.patch
# )
```

2. **If build succeeds, remove the patch:**
```powershell
# Remove patch file
Remove-Item ports/port-name/fix-cmake.patch

# Update portfile.cmake to remove patch reference
# Commit the changes
```

### Strategy 3: Create New Patches

For new issues introduced in the updated version:

1. **Identify the issue** (build failure, missing features, etc.)

2. **Create fix in source:**
```powershell
# Navigate to source directory
cd buildtrees/port-name/src/version-hash/

# Make your changes
# ...

# Create patch
git add .
git commit -m "Fix new issue"
git format-patch HEAD~1 --stdout > ../../../ports/port-name/fix-new-issue.patch
```

3. **Update portfile.cmake:**
```cmake
vcpkg_apply_patches(
    SOURCE_PATH ${SOURCE_PATH}
    PATCHES
        existing-patch.patch
        fix-new-issue.patch  # Add new patch
)
```

## 4. Embedded CMakeLists.txt Approach

### When to Use

The embedded CMakeLists.txt approach is valuable when:
- Patches become complex and frequently fail
- Multiple CMakeLists.txt changes are needed
- Upstream CMakeLists.txt changes frequently
- You're prototyping fixes rapidly

### Implementation Steps

1. **Download the original CMakeLists.txt:**
```powershell
$Version = "v2.1.3"
$Url = "https://raw.githubusercontent.com/owner/repo/$Version/CMakeLists.txt"
curl -o "ports/port-name/CMakeLists.txt" $Url
```

2. **Modify the embedded file directly:**
```cmake
# Example modifications in ports/port-name/CMakeLists.txt
cmake_minimum_required(VERSION 3.15)

# Add vcpkg-specific fixes
find_package(PkgConfig REQUIRED)
find_package(OpenSSL REQUIRED)

# Original content with modifications...
```

3. **Copy embedded file in portfile.cmake:**
```cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO owner/repo
    REF v2.1.3
    SHA512 abc123...
)

# Copy our modified CMakeLists.txt
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_TESTING=OFF
)
```

### Example: farmhash Port

The `farmhash` port demonstrates this approach:

```
ports/farmhash/
├── CMakeLists.txt     # Embedded and modified
├── portfile.cmake     # Uses file(COPY) to overwrite
└── vcpkg.json
```

```cmake
# In portfile.cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/farmhash
    REF v1.1
    SHA512 sha512hash...
)

# Overwrite with our version
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()
```

### Benefits of Embedded Approach

- **Easier maintenance:** Direct file editing vs complex patch management
- **Clearer review:** Developers see exact changes in embedded file
- **No patch failures:** Eliminates patch application context mismatches  
- **Rapid prototyping:** Faster iteration during development

### ⚠️ Important Warning

> **This approach is primarily for experimental/private registries.**
> 
> If you plan to contribute to **microsoft/vcpkg upstream**, you **MUST** convert embedded changes back to proper patch files before submitting. The upstream strongly prefers patches for:
> - **Maintainability:** Patches show exactly what changed
> - **Upstream compatibility:** Easier to review and maintain
> - **Standards compliance:** Follows vcpkg contribution guidelines

## 5. Patch File Management

### Naming Conventions
```
ports/port-name/
├── fix-cmake.patch           # General CMake fixes
├── fix-msvc-build.patch      # MSVC-specific fixes
├── fix-dependencies.patch    # Dependency-related fixes
├── disable-tests.patch       # Test disabling
└── fix-install-paths.patch   # Installation path fixes
```

### Patch Documentation
Include comments in portfile.cmake explaining patch purposes:
```cmake
vcpkg_apply_patches(
    SOURCE_PATH ${SOURCE_PATH}
    PATCHES
        fix-cmake.patch          # Fix CMake version requirements
        disable-tests.patch      # Disable tests for vcpkg build
        fix-msvc-warnings.patch  # Fix MSVC C4996 warnings
)
```

## 6. Common Patch Scenarios

### CMake Configuration Issues
```cmake
# Common fixes needed in CMakeLists.txt
# Before (problematic)
find_package(PkgConfig)

# After (vcpkg-friendly)  
find_package(PkgConfig REQUIRED)
find_package(OpenSSL REQUIRED)
target_link_libraries(target OpenSSL::SSL OpenSSL::Crypto)
```

### Build System Modernization
```cmake
# Update old CMake patterns
# Before
include_directories(${OPENSSL_INCLUDE_DIR})
target_link_libraries(target ${OPENSSL_LIBRARIES})

# After
target_link_libraries(target OpenSSL::SSL OpenSSL::Crypto)
```

### Installation Path Fixes
```cmake
# Fix installation paths for vcpkg
install(TARGETS mytarget
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)
```

## 7. Patch Testing Workflow

### Individual Patch Testing
```powershell
# Test each patch individually
# Comment out all but one patch in portfile.cmake
vcpkg install --overlay-ports=ports port-name

# Gradually uncomment patches to find conflicts
```

### Cross-Platform Testing
```powershell
# Test patches on different platforms
vcpkg install --overlay-ports=ports --triplet x64-windows port-name
vcpkg install --overlay-ports=ports --triplet x64-linux port-name
vcpkg install --overlay-ports=ports --triplet x64-osx port-name
```

## 8. Patch Conflict Resolution

### Common Conflict Types

#### Line Number Shifts
```diff
# Patch expects line 15, but change is now at line 18
# Solution: Update line numbers in patch

-@@ -15,7 +15,7 @@
+@@ -18,7 +18,7 @@
```

#### Context Changes
```diff
# Surrounding code changed
# Solution: Update context lines in patch

# Old context
 int main() {
-    old_function();
+    new_function();
 }

# New context  
 int main(int argc, char** argv) {
-    old_function();
+    new_function();
 }
```

#### File Moves/Renames
```diff
# File was moved/renamed upstream
# Update patch to reference new location

# Before
--- a/src/oldfile.cpp
+++ b/src/oldfile.cpp

# After
--- a/src/newpath/newfile.cpp  
+++ b/src/newpath/newfile.cpp
```

## 9. Best Practices

### Patch Creation
- **Minimal changes:** Only patch what's necessary for vcpkg
- **Clear purpose:** Each patch should have a single, clear purpose
- **Test thoroughly:** Verify patches work across platforms
- **Document rationale:** Explain why each patch is needed

### Patch Maintenance
- **Regular review:** Check if patches are still needed with each update
- **Upstream contributions:** Consider contributing fixes upstream
- **Version tracking:** Note which versions each patch applies to
- **Fallback plans:** Have embedded CMakeLists.txt ready for complex cases

### Repository Organization
- **Consistent naming:** Use descriptive patch file names
- **Clean history:** Remove obsolete patches promptly
- **Documentation:** Comment patch purposes in portfile.cmake
- **Testing notes:** Document any platform-specific patch behavior

## 10. Related Resources

- [Main Port Update Guide](./guide-update-port.md)
- [Version Management Guide](./guide-update-port-versioning.md)
- [vcpkg Patch Documentation](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_apply_patches)
- [Git Patch Documentation](https://git-scm.com/docs/git-apply)
- [Example: farmhash port](../ports/farmhash/)