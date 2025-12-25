---
id: workflow-diagrams
title: Workflow Diagrams
sidebar_position: 10
---

# vcpkg-registry Workflows

This page demonstrates Mermaid diagram support in Docusaurus and documents key workflows.

## Port Creation Workflow

The following diagram shows the typical workflow for creating a new port:

```mermaid
graph TD
    A[Start: Need New Library] --> B{Port Exists?}
    B -->|No| C[Search Upstream vcpkg]
    C --> D{Found?}
    D -->|Yes| E[Use Upstream]
    D -->|No| F[Create Port]
    F --> G[Write vcpkg.json]
    G --> H[Write portfile.cmake]
    H --> I[Test Build]
    I --> J{Build Success?}
    J -->|No| K[Debug Issues]
    K --> I
    J -->|Yes| L[Update Version Baseline]
    L --> M[Submit PR]
    M --> N[End]
    B -->|Yes| O{Custom Needed?}
    O -->|Yes| F
    O -->|No| E
    E --> N
```

## Port Update Workflow

When updating an existing port to a new version:

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Port as Port Files
    participant Build as Build System
    participant Registry as Version Registry
    
    Dev->>Port: Check current version
    Dev->>Port: Update version in vcpkg.json
    Dev->>Port: Update SHA512 in portfile.cmake
    Dev->>Build: Test build
    Build-->>Dev: Build result
    alt Build Success
        Dev->>Registry: Run registry-add-version.ps1
        Registry-->>Dev: Update versions/*.json
        Dev->>Dev: Commit changes
    else Build Failure
        Dev->>Port: Fix issues
        Dev->>Build: Test again
    end
```

## Prompt Workflow

GitHub Copilot prompts follow this workflow:

```mermaid
graph LR
    A[User Task] --> B{Task Type?}
    B -->|New Port| C[/search-port]
    C --> D[/create-port]
    D --> E[/install-port]
    E --> F[/review-port]
    B -->|Update Port| G[/check-port-upstream]
    G --> H[/update-port]
    H --> E
    F --> I[/update-version-baseline]
    I --> J[Complete]
    H --> J
```

## Navigation Graph

This graph shows how the documentation is organized:

```mermaid
graph TB
    subgraph "Main Docs"
        Intro[Introduction]
        Setup[Setup Guide]
        Intro --> Setup
    end
    
    subgraph "How-To Guides"
        Create[Create Port]
        CreateBuild[Create Port - Build]
        CreateDownload[Create Port - Download]
        Update[Update Port]
        Baseline[Update Baseline]
        
        Create --> CreateBuild
        Create --> CreateDownload
        Update --> Baseline
    end
    
    subgraph "Reference"
        Refs[References]
        Troubleshoot[Troubleshooting]
    end
    
    subgraph "Prompts"
        CheckEnv[Check Environment]
        SearchPort[Search Port]
        CreatePrompt[Create Port Prompt]
        InstallPort[Install Port]
        ReviewPort[Review Port]
        UpdatePrompt[Update Port Prompt]
        BaselinePrompt[Update Baseline Prompt]
        
        CheckEnv --> SearchPort
        SearchPort --> CreatePrompt
        CreatePrompt --> InstallPort
        InstallPort --> ReviewPort
        ReviewPort --> BaselinePrompt
    end
    
    Setup --> Create
    Setup --> Update
    Create --> Refs
    Update --> Refs
    Refs --> Troubleshoot
```

## Related Documentation

- [Create Port Guide](guide-create-port)
- [Update Port Guide](guide-update-port)
- [Troubleshooting](troubleshooting)
