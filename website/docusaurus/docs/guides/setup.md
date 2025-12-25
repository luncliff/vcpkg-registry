---
id: setup
title: Setup vcpkg
sidebar_position: 2
---

# Setup vcpkg

Follow the official [Getting Started Guide](https://learn.microsoft.com/en-us/vcpkg/get_started/get-started) to setup your environment.
Don't forget to check [the vcpkg environment variables](https://github.com/microsoft/vcpkg/blob/master/docs/users/config-environment.md) are correct.

## Required Environment Variables

- `VCPKG_ROOT` to integrate with toolchains. For example, `C:\vcpkg` or `/usr/local/shared/vcpkg`
- `PATH` to run `vcpkg` CLI program.

## Testing the Installation

Use `vcpkg help` command to get descriptions and test the CLI executable works.  
Commonly used commands can be checked with:

```bash
vcpkg help install
vcpkg help remove
vcpkg help search
```

## Using This Registry

To use this custom registry, you'll need to configure your vcpkg installation to use this overlay registry. See the [vcpkg registries documentation](https://learn.microsoft.com/en-us/vcpkg/consume/git-registries) for detailed instructions.

### Configuration Example

Add the following to your `vcpkg-configuration.json`:

```json
{
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/luncliff/vcpkg-registry",
      "baseline": "<commit-hash>",
      "packages": ["*"]
    }
  ]
}
```

## Next Steps

Once you have vcpkg set up, you can:

- [Create a new port](guide-create-port)
- [Update an existing port](guide-update-port)
- Check the [Troubleshooting Guide](troubleshooting) if you run into issues
