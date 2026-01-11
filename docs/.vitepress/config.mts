import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "한글로 쓴 Vcpkg 설명서",
  description: "Learn Vcpkg package manager with 한글(Korean)",
  lang: 'ko',

  // Base URL for GitHub Pages deployment
  base: '/vcpkg-registry/',

  // Clean URLs (remove .html extension)
  cleanUrls: true,

  // Ignore dead links to files outside docs directory
  ignoreDeadLinks: true,

  // Head tags
  head: [
    ['meta', { name: 'theme-color', content: '#5f67ee' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:locale', content: 'ko' }],
    ['meta', { property: 'og:title', content: '한글로 쓴 Vcpkg 설명서' }],
    ['meta', { property: 'og:site_name', content: '한글로 쓴 Vcpkg 설명서' }],
  ],

  // Markdown configuration
  markdown: {
    theme: {
      light: 'github-light',
      dark: 'github-dark'
    },
    lineNumbers: false,
  },

  // Theme configuration
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config    
    siteTitle: 'Vcpkg Registry',

    nav: [
      { text: 'Home', link: '/' },
      {
        text: '튜토리얼',
        items: [
          { text: '입문 (Beginner)', link: '/kr/01-beginner-00-intro' },
          { text: '중급 (Intermediate)', link: '/kr/11-intermediate-00-overview' },
        ]
      },
      { text: 'References', link: '/references' },
      {
        text: 'Guides',
        items: [
          { text: 'Create Port', link: '/guide-create-port' },
          { text: 'Update Port', link: '/guide-update-port' },
          { text: 'Update Version Baseline', link: '/guide-update-version-baseline' },
          { text: 'Troubleshooting', link: '/troubleshooting' },
        ]
      },
    ],

    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'Getting Started', link: '/kr/01-beginner-00-intro' },
          { text: 'References', link: '/references' },
          { text: 'Legacy Guide', link: '/vcpkg-for-kor' },
        ]
      },
      {
        text: 'Korean Tutorials - Beginner',
        collapsed: false,
        items: [
          { text: '1. Vcpkg 소개', link: '/kr/01-beginner-00-intro' },
          { text: '2. 설치 및 설정', link: '/kr/02-beginner-10-setup' },
          { text: '3. 첫 패키지 설치', link: '/kr/03-beginner-20-first-package' },
          { text: '4. Triplet 기초', link: '/kr/04-beginner-30-triplets-basics' },
          { text: '5. CMake 연동', link: '/kr/05-beginner-40-cmake' },
          { text: '6. Manifest 입문', link: '/kr/06-beginner-50-manifest' },
        ]
      },
      {
        text: 'Korean Tutorials - Intermediate',
        collapsed: false,
        items: [
          { text: '1. 개요', link: '/kr/11-intermediate-00-overview' },
          { text: '2. 버전과 Registry', link: '/kr/12-intermediate-10-versions-registry' },
          { text: '3. Triplet 심화', link: '/kr/13-intermediate-20-triplets-advanced' },
          { text: '4. Per-Port 설정', link: '/kr/14-intermediate-30-per-port-customization' },
          { text: '5. Manifest 실전', link: '/kr/15-intermediate-40-manifest-practice' },
          { text: '6. 문제 해결', link: '/kr/16-intermediate-50-troubleshooting' },
        ]
      },
      {
        text: 'Guides',
        items: [
          { text: 'Create Port', link: '/guide-create-port' },
          { text: 'Create Port - Build', link: '/guide-create-port-build' },
          { text: 'Create Port - Download', link: '/guide-create-port-download' },
          { text: 'Update Port', link: '/guide-update-port' },
          { text: 'Update Version Baseline', link: '/guide-update-version-baseline' },
          { text: 'Troubleshooting', link: '/troubleshooting' },
        ]
      },
      {
        text: 'Development',
        items: [
          { text: 'Prompt Designs', link: '/prompt-designs' },
          { text: 'Review Checklist', link: '/review-checklist' },
          { text: 'Pull Request Template', link: '/pull_request_template' },
        ]
      },
      {
        text: 'VitePress Maintenance',
        collapsed: true,
        items: [
          { text: 'Maintenance Guide', link: '/maintenance-vitepress' },
          { text: 'Quick Start', link: '/vitepress-quickstart' },
          { text: 'Overview', link: '/vitepress-experiment' },
          { text: 'Enhancements Guide', link: '/vitepress-enhancements' },
          { text: 'MkDocs vs VitePress', link: '/mkdocs-vs-vitepress' },
        ]
      }
    ],

    // Social links
    socialLinks: [
      { icon: 'github', link: 'https://github.com/luncliff/vcpkg-registry' }
    ],

    // Edit link
    editLink: {
      pattern: 'https://github.com/luncliff/vcpkg-registry/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    },

    // Footer
    footer: {
      message: 'CC0 1.0 Public Domain',
      copyright: 'Copyright © 2024-present luncliff'
    },

    // Search
    search: {
      provider: 'local',
      options: {
        locales: {
          root: {
            translations: {
              button: {
                buttonText: '검색',
                buttonAriaLabel: '검색'
              },
              modal: {
                noResultsText: '결과를 찾을 수 없습니다',
                resetButtonTitle: '초기화',
                footer: {
                  selectText: '선택',
                  navigateText: '이동',
                  closeText: '닫기'
                }
              }
            }
          }
        }
      }
    },

    // Outline
    outline: {
      level: [2, 3],
      label: '목차'
    },

    // Last updated
    lastUpdated: {
      text: '최종 업데이트',
      formatOptions: {
        dateStyle: 'short',
        timeStyle: 'short'
      }
    },

    // Doc footer
    docFooter: {
      prev: '이전',
      next: '다음'
    },

    // Dark mode
    darkModeSwitchLabel: '테마',
    lightModeSwitchTitle: '라이트 모드로 전환',
    darkModeSwitchTitle: '다크 모드로 전환',
    sidebarMenuLabel: '메뉴',
    returnToTopLabel: '맨 위로',

    // External link icon
    externalLinkIcon: true,
  },

  // Locales configuration for i18n (future expansion)
  locales: {
    root: {
      label: '한국어',
      lang: 'ko',
    },
    // Future: Add English locale
    // en: {
    //   label: 'English',
    //   lang: 'en',
    //   link: '/en/',
    // }
  }
})
