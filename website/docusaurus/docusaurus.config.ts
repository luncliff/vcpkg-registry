import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'vcpkg-registry',
  tagline: 'Custom vcpkg ports and registry',
  favicon: 'img/favicon.ico',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: 'https://luncliff.github.io',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/vcpkg-registry/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'luncliff', // Usually your GitHub org/user name.
  projectName: 'vcpkg-registry', // Usually your repo name.

  onBrokenLinks: 'warn', // Changed to 'warn' for prototype - many links to external docs

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'ko'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/luncliff/vcpkg-registry/tree/main/website/docusaurus/',
        },
        blog: false, // Disable blog for now
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/docusaurus-social-card.jpg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'vcpkg-registry',
      logo: {
        alt: 'vcpkg-registry Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'guideSidebar',
          position: 'left',
          label: 'Guides',
        },
        {
          type: 'docSidebar',
          sidebarId: 'promptsSidebar',
          position: 'left',
          label: 'Prompts',
        },
        {
          type: 'localeDropdown',
          position: 'right',
        },
        {
          href: 'https://github.com/luncliff/vcpkg-registry',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Guides',
              to: '/docs/guides/intro',
            },
            {
              label: 'Prompts',
              to: '/docs/prompts/intro',
            },
          ],
        },
        {
          title: 'vcpkg Resources',
          items: [
            {
              label: 'vcpkg Documentation',
              href: 'https://learn.microsoft.com/en-us/vcpkg/',
            },
            {
              label: 'vcpkg GitHub',
              href: 'https://github.com/microsoft/vcpkg',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/luncliff/vcpkg-registry',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} vcpkg-registry. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
    algolia: {
      // Placeholder for Algolia DocSearch
      // To enable: create account at https://docsearch.algolia.com/apply/
      appId: process.env.ALGOLIA_APP_ID || 'YOUR_APP_ID',
      apiKey: process.env.ALGOLIA_API_KEY || 'YOUR_API_KEY',
      indexName: process.env.ALGOLIA_INDEX_NAME || 'vcpkg-registry',
      contextualSearch: true, // Enable locale-aware search
    },
  } satisfies Preset.ThemeConfig,

  markdown: {
    mermaid: true, // Enable Mermaid diagrams
  },
  themes: ['@docusaurus/theme-mermaid'],
};

export default config;
