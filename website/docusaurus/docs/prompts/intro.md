---
id: intro
title: GitHub Copilot Prompts
sidebar_position: 1
---

# GitHub Copilot Prompts

This section contains specialized GitHub Copilot prompts for working with this vcpkg registry.

## Available Prompts

The following prompts are available to assist with common vcpkg registry tasks:

### Environment & Setup
- [Check Environment](check-environment) - Verify your development environment is correctly configured

### Port Discovery
- [Search Port](search-port) - Search for ports in upstream vcpkg or this registry

### Port Creation
- [Create Port](create-port) - Create a new vcpkg port
- [Install Port](install-port) - Install and test a port

### Port Maintenance
- [Check Port Upstream](check-port-upstream) - Check for upstream updates
- [Update Port](update-port) - Update an existing port to a new version
- [Update Version Baseline](update-version-baseline) - Update the version baseline after port changes

### Port Review
- [Review Port](review-port) - Review port configuration and quality

## Using These Prompts

These prompts are designed to work with GitHub Copilot Chat. They follow the structured approach defined in the Copilot Instructions.

### Workflow Example

A typical port creation workflow would use prompts in this order:

1. `/search-port` - Find if the library already exists
2. `/create-port` - Create the new port
3. `/install-port` - Test the installation
4. `/review-port` - Review the implementation
5. `/update-version-baseline` - Update the registry baseline

## Related Documentation

- [Create Port Guide](../guides/guide-create-port)
- [Update Port Guide](../guides/guide-update-port)
- [Troubleshooting Guide](../guides/troubleshooting)
