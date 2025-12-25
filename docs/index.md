---
layout: home

hero:
  name: "vcpkg-registry"
  text: "Custom Vcpkg Registry"
  tagline: "한글로 쓴 Vcpkg 설명서 - Learn Vcpkg with Korean language support"
  image:
    src: /logo.svg
    alt: vcpkg-registry
  actions:
    - theme: brand
      text: 시작하기
      link: /vcpkg-for-kor
    - theme: alt
      text: 가이드 보기
      link: /guide-create-port
    - theme: alt
      text: GitHub
      link: https://github.com/luncliff/vcpkg-registry

features:
  - icon: 📦
    title: Custom Ports
    details: Overlay ports for vcpkg package manager with specialized configurations for Android, iOS, and more.
  - icon: 🔧
    title: Build Configurations
    details: Custom triplets for cross-platform builds including Android NDK and iOS Simulator SDK.
  - icon: 📝
    title: Comprehensive Guides
    details: Step-by-step guides in Korean for creating, updating, and troubleshooting vcpkg ports.
  - icon: 🔍
    title: Built-in Search
    details: Fast local search functionality to quickly find documentation and code examples.
  - icon: 🌏
    title: Bilingual Support
    details: Documentation available in Korean with plans for English localization.
  - icon: 🚀
    title: Easy Integration
    details: Use with vcpkg's classic mode or manifest mode for seamless package management.
---

## Quick Start

새롭게 정리하고 있습니다.
당분간은 이전처럼 [vcpkg-for-kor.md](./vcpkg-for-kor.md)를 참고해주세요.

### Installation

```bash
# Clone the registry
git clone https://github.com/luncliff/vcpkg-registry

# Use with overlay ports
vcpkg install --overlay-ports="vcpkg-registry/ports" <package-name>
```

### Popular Guides

- [Create Port Guide](/guide-create-port) - Add new vcpkg ports
- [Update Port Guide](/guide-update-port) - Update existing ports
- [Troubleshooting](/troubleshooting) - Common issues and solutions
