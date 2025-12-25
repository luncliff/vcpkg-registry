---
title: Diagram Support
description: Using Mermaid and Graphviz diagrams in documentation
---

## Mermaid Diagrams

This documentation site has built-in support for [Mermaid](https://mermaid.js.org/) diagrams. You can create flowcharts, sequence diagrams, class diagrams, and more using simple text-based syntax.

### Example: Flowchart

```mermaid
graph TD
    A[Start] --> B{Is vcpkg installed?}
    B -->|Yes| C[Clone registry]
    B -->|No| D[Install vcpkg]
    D --> C
    C --> E[Create port]
    E --> F[Test installation]
    F --> G[Update baseline]
    G --> H[End]
```

### Example: Sequence Diagram

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Port as Port Files
    participant VCPKG as vcpkg CLI
    participant Build as Build System
    
    Dev->>Port: Create portfile.cmake
    Dev->>Port: Create vcpkg.json
    Dev->>VCPKG: vcpkg install --overlay-ports
    VCPKG->>Port: Read manifest
    VCPKG->>Build: Execute build
    Build-->>VCPKG: Artifacts
    VCPKG-->>Dev: Installation complete
```

## Graphviz Diagrams

For more complex diagrams that require Graphviz, we recommend the following approaches:

### Approach 1: Pre-render to SVG (Recommended)

1. Install Graphviz locally: `apt install graphviz` or `brew install graphviz`
2. Create your `.dot` file with your diagram definition
3. Render to SVG: `dot -Tsvg input.dot -o output.svg`
4. Place the SVG file in `src/assets/` directory
5. Import and use in your MDX file:

```mdx
---
title: My Page
---

import MyDiagram from '../../assets/output.svg';

<img src={MyDiagram.src} alt="My diagram" />
```

### Approach 2: Client-side Rendering

For dynamic Graphviz rendering, you can use `@hpcc-js/wasm`:

1. Install the package: `npm install @hpcc-js/wasm`
2. Create a custom Astro component that wraps the WASM renderer
3. Import and use the component in your pages

**Note:** This approach requires JavaScript to be enabled in the browser and may impact initial page load time.

### Example Graphviz Syntax

```dot
digraph G {
    rankdir=LR;
    node [shape=box];
    
    "vcpkg-registry" -> "Port Directory";
    "Port Directory" -> "portfile.cmake";
    "Port Directory" -> "vcpkg.json";
    "vcpkg.json" -> "Dependencies";
    "portfile.cmake" -> "Build Logic";
    "Build Logic" -> "Install Artifacts";
}
```

For now, we recommend using **Approach 1** (pre-rendering to SVG) for the best performance and compatibility. Mermaid diagrams should be used for most common diagram needs as they are natively supported and render efficiently.

## Best Practices

1. **Use Mermaid when possible**: It's built-in, fast, and works everywhere
2. **Keep diagrams simple**: Complex diagrams can be hard to maintain
3. **Add alt text**: Always provide descriptive alt text for accessibility
4. **SVG for complex graphs**: Use pre-rendered SVG for intricate Graphviz diagrams
5. **Document your diagrams**: Include the source `.dot` or `.mmd` files in version control

## Resources

- [Mermaid Documentation](https://mermaid.js.org/)
- [Graphviz Documentation](https://graphviz.org/documentation/)
- [Mermaid Live Editor](https://mermaid.live/)
