import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "한글로 쓴 Vcpkg 설명서",
  description: "Learn Vcpkg package manager with 한글(Korean)",
  lang: 'ko',
  
  // Base URL for GitHub Pages deployment
  // base: '/vcpkg-registry/',
  
  // Clean URLs (remove .html extension)
  cleanUrls: true,
  
  // Ignore dead links to files outside docs directory
  ignoreDeadLinks: true,
  
  // Head tags
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }],
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
    
    logo: '/logo.svg',
    
    siteTitle: 'Vcpkg Registry',
    
    nav: [
      { text: 'Home', link: '/vcpkg-for-kor' },
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
          { text: 'Getting Started', link: '/vcpkg-for-kor' },
          { text: 'References', link: '/references' },
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
        text: 'VitePress Experiment',
        collapsed: true,
        items: [
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
