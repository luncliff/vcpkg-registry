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
      text: 입문 튜토리얼 시작하기
      link: /kr/01-beginner-00-intro
    - theme: alt
      text: 중급 튜토리얼
      link: /kr/11-intermediate-00-overview
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

Vcpkg를 처음 사용하신다면 단계별 튜토리얼을 추천합니다:

- 👉 **[Beginner 트랙](./kr/01-beginner-00-intro)** - Vcpkg 기초부터 CMake 연동까지
- 👉 **[Intermediate 트랙](./kr/11-intermediate-00-overview)** - 버전 관리, Triplet 심화, 문제 해결

기존 단일 페이지 가이드를 원하신다면: [레거시 가이드](./blog/vcpkg-for-kor)

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
