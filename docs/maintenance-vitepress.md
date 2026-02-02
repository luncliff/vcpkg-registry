# VitePress Maintenance Guide

VitePress 기반 문서 시스템의 유지보수 가이드입니다.

## Overview

### Purpose and Scope

이 문서는 vcpkg-registry의 VitePress 문서 시스템을 관리하는 메인테이너를 위한 가이드입니다.

### Why VitePress?

MkDocs 대신 VitePress를 선택한 이유:
- Vue.js 생태계와의 통합
- 뛰어난 성능 (Vite 기반 HMR)
- 내장 검색 기능 (MiniSearch)
- 한국어 UI 완전 지원
- Markdown 확장 기능

자세한 비교는 [MkDocs vs VitePress](./mkdocs-vs-vitepress)를 참고하세요.

## Architecture

### File Structure

```
docs/
├── .vitepress/
│   ├── config.mts           # Main configuration
│   ├── theme/               # (Future) Custom components
│   └── dist/                # Build output
├── public/
│   └── logo.svg
├── index.md                 # Home page (layout: home)
├── vcpkg-for-kor.md        # Legacy Korean guide
├── kr/                      # Korean tutorials (NEW)
│   ├── 01-beginner-00-intro.md
│   ├── 02-beginner-10-setup.md
│   ├── ...
│   ├── 11-intermediate-00-overview.md
│   └── 90-reference-folder-layout.md
├── guide-*.md               # Port creation/update guides
├── references.md
├── troubleshooting.md
└── maintenance-vitepress.md # This file
```

### Navigation Structure

- **nav**: Top navigation bar
  - Home, 튜토리얼 (Beginner/Intermediate), References, Guides
- **sidebar**: Left sidebar
  - Introduction
  - Korean Tutorials - Beginner (6 lessons)
  - Korean Tutorials - Intermediate (6 lessons)
  - Guides (Port/Version/Troubleshooting)
  - Development (Prompts/Checklist)
  - VitePress Maintenance

### URL Conventions

- Clean URLs: `.html` 확장자 제거 (`cleanUrls: true`)
- 내부 링크: `/path/to/page` (leading `/`, no extension)
- Language-specific: `/kr/NN-track-step-slug`
- Future English: `/en/NN-track-step-slug` (준비 중)

## Running Docs Locally

### Prerequisites

- Node.js 20 이상
- npm (package.json에 VitePress 의존성 정의됨)

### Commands

```bash
# Install dependencies
npm install

# Start development server (hot reload)
npm run docs:dev
# → http://localhost:5173

# Build for production
npm run docs:build
# → Output: docs/.vitepress/dist

# Preview production build
npm run docs:preview
```

### Common Tasks

#### Adding a New Page

1. `docs/` 폴더에 Markdown 파일 생성
2. `.vitepress/config.mts`의 `sidebar`에 링크 추가
3. 필요시 `nav`에도 추가

#### Editing Navigation

`docs/.vitepress/config.mts`:
- `themeConfig.nav`: 상단 내비게이션
- `themeConfig.sidebar`: 사이드바 메뉴

#### Markdown Features

VitePress는 다음 기능을 지원합니다:
- 컨테이너 (`::: info`, `::: warning`, `::: danger`, `::: details`)
- Code groups
- Badge
- 수식 (KaTeX) - 설정 필요 시
- Custom components (Vue) - `.vitepress/theme/` 사용

## CI & Deployment

### GitHub Actions Workflow

`.github/workflows/vitepress.yml`:

```yaml
- Build: ubuntu-latest, Node 20, npm ci, npm run docs:build
- Upload: actions/upload-pages-artifact (docs/.vitepress/dist)
- Deploy: actions/deploy-pages@v4
```

### GitHub Pages Configuration

Repository Settings → Pages:
- **Source**: GitHub Actions
- **Branch**: 자동 (Actions artifact 기반)
- **Custom domain**: 필요 시 설정

### Base URL Configuration

`docs/.vitepress/config.mts`:

```ts
// Project page: https://luncliff.github.io/vcpkg-registry/
base: '/vcpkg-registry/',

// User/Org root or custom domain
// base: '/',
```

::: warning
`base` 변경 시 모든 asset URL과 링크를 확인하세요.
:::

## Advanced Configuration

### Shiki Syntax Highlighting

현재 설정:
```ts
markdown: {
  theme: {
    light: 'github-light',
    dark: 'github-dark'
  },
  lineNumbers: false,
}
```

**Known Issues**:
- `pwsh`, `dot`, `pc` 언어는 Shiki가 기본 지원하지 않음 → 경고 발생 (무시 가능)
- 필요 시 `shiki` 언어팩을 추가하거나 code block에서 `bash` 등으로 대체

### Theme Customization

향후 커스텀 컴포넌트 추가 시:

1. `.vitepress/theme/index.ts` 생성
2. Vue 컴포넌트를 `.vitepress/theme/components/`에 배치
3. 등록 후 Markdown에서 사용

예: `<TrackProgress track="Beginner" step="2" total="6" />`

### i18n Configuration

현재 상태:
- `locales.root`: 한국어 (기본)
- `locales.en`: 준비됨 (주석 처리)

English 트랙 추가 시:
1. `docs/en/` 폴더 생성
2. `config.mts`의 `locales.en` 활성화
3. `themeConfig` 내 `locales.en.nav`, `locales.en.sidebar` 정의

### SEO & Analytics

현재 메타 태그:
```ts
head: [
  ['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }],
  ['meta', { name: 'theme-color', content: '#5f67ee' }],
  ['meta', { property: 'og:type', content: 'website' }],
  // ...
]
```

Google Analytics 추가 시:
```ts
head: [
  ['script', { async: true, src: 'https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX' }],
  ['script', {}, `window.dataLayer = ...`]
]
```

## Known Issues & Troubleshooting

### Build Warnings

1. **Dead links to files outside docs**: `ignoreDeadLinks: true` 설정으로 무시
2. **Shiki language not found** (`pwsh`, `dot`, `pc`): 무시 가능, 또는 다른 언어로 대체
3. **Missing sitemap**: VitePress 1.6+ built-in sitemap 사용 가능 (설정 필요)

### Dev Server Issues

- **Port 충돌**: `--port 5174` 등으로 변경
- **HMR 미작동**: 브라우저 캐시 삭제 후 재시작
- **Import 오류**: `node_modules` 삭제 후 `npm ci` 재실행

### Search Not Working

- Local search는 빌드 후 자동 생성됨
- Dev 모드에서도 작동하지만, 인덱스는 페이지 로드 시마다 재생성

## Tutorial Structure Guidelines

### Korean Tutorial Convention

- **경로**: `docs/kr/NN-track-step-slug.md`
- **번호**: 01–06 (Beginner), 11–16 (Intermediate), 90+ (Reference)
- **Flat 구조**: 서브폴더 없음
- **파일명**: ASCII, 한글은 H1 title에만 사용

### Visual Indicator Pattern

각 튜토리얼 상단:

```markdown
::: info 튜토리얼 진행 상황
**Beginner 트랙 · 2 / 6 단계**

1. [Vcpkg 소개](./01-beginner-00-intro)
2. **설치 및 설정** ← 현재
3. 첫 패키지 설치
4. Triplet 기초
5. CMake 연동
6. Manifest 입문
:::
```

### Frontmatter (선택)

대부분 문서는 frontmatter 없이 H1만 사용:
```markdown
# Vcpkg 설치 및 설정

내용...
```

필요 시:
```yaml
---
title: Custom Title
outline: [2, 3]
---
```

### Navigation Links

문서 끝에 다음 단계 링크 추가:
```markdown
## 다음 단계

👉 [다음: 첫 패키지 설치](./03-beginner-20-first-package)
```

## Adding New Tracks

### English Tutorial (Future)

1. `docs/en/` 폴더 생성
2. 동일한 번호 체계 사용 (01–06, 11–16)
3. `config.mts` 수정:
   ```ts
   locales: {
     root: { label: '한국어', lang: 'ko' },
     en: {
       label: 'English',
       lang: 'en',
       link: '/en/',
       themeConfig: {
         nav: [ /* English nav */ ],
         sidebar: [ /* English sidebar */ ]
       }
     }
   }
   ```

### Content Localization Checklist

- [ ] Nav/Sidebar labels
- [ ] Search translations
- [ ] Footer text
- [ ] Outline label
- [ ] Doc footer (prev/next)
- [ ] 404 page

## Change Management

### When Adding Plugins

1. `package.json`에 추가
2. `config.mts`에서 설정
3. **이 문서(maintenance-vitepress.md)에 기록**
4. 빌드 테스트 (`npm run docs:build`)

### When Changing Theme

1. `.vitepress/theme/index.ts` 수정
2. Custom CSS는 `.vitepress/theme/custom.css`에
3. 기존 스타일과의 충돌 확인

### When Updating VitePress Version

1. `npm outdated vitepress`
2. Breaking changes 확인 (VitePress changelog)
3. `package.json` 버전 업데이트
4. `npm install`
5. 빌드 테스트 및 dev 서버 확인

## History & Legacy Docs

### Background Documents

이 문서는 다음 파일들을 통합/대체합니다:
- `vitepress-quickstart.md` - 로컬 실행 가이드 (일부 유지)
- `vitepress-experiment.md` - 초기 실험 개요
- `vitepress-enhancements.md` - 고급 기능 제안
- `VITEPRESS-SUMMARY.md` - 실험 요약

### Migration History

- **2024**: MkDocs → VitePress 실험 시작
- **Branch**: `copilot/experiment-vitepress` → main 병합
- **Jan 2026**: Korean Tutorial 구조 도입, 이 maintenance 문서 작성

## References

- [VitePress Official Docs](https://vitepress.dev/)
- [VitePress GitHub](https://github.com/vuejs/vitepress)
- [Shiki Themes](https://shiki.style/themes)
- [GitHub Pages with Actions](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site#publishing-with-a-custom-github-actions-workflow)
