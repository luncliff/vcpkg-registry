---
name: Port Request
about: Request a new vcpkg port or an update to an existing one.
title: 'Port Request - [Project Name] [Version]'
labels: ''
assignees: ''

---
## Request

### 1. What do you want to use with vcpkg?
A clear and concise description of what the port is, including a link to the upstream repository or project homepage. We recommend one port per issue, but multiple related ports are allowed.

- **Upstream URL:** [e.g., https://github.com/owner/repo]
- **Project Name:** [e.g., My Awesome Library]

### 2. Is this a new port or an update to an existing one?
- [ ] New port (not in this registry yet)
- [ ] Update existing port in this registry

### 3. Target version
Specify the version you want to use (e.g., a release tag, commit hash, or "latest").

- **Version:** [e.g., 1.2.3]

### 4. Target platforms / triplets (optional but helpful)
List the platforms you need this port for.

- **Triplets:** [e.g., `x64-windows`, `x64-linux`, `arm64-android`]

### 5. How will you use this library?
A short description of your use case.

### 6. Known build information (optional)
- **Build System:** [e.g., CMake, Meson, Autotools, other]
- **Does upstream support vcpkg?** [Yes/No/Unknown]

### References

* [GitHub Copilot Skills](../../.github/skills/)
* [Create Port Guide](../../docs/guide-create-port.md)
* [Update Port Guide](../../docs/guide-update-port.md)
* [search-port skill](../../.github/skills/search-port/SKILL.md)
* [create-port skill](../../.github/skills/create-port/SKILL.md)
* [update-port skill](../../.github/skills/update-port/SKILL.md)
* [install-port skill](../../.github/skills/install-port/SKILL.md)
* [review-port skill](../../.github/skills/review-port/SKILL.md)
