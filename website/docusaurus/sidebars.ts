import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */
const sidebars: SidebarsConfig = {
  // Sidebar for guides and main documentation
  guideSidebar: [
    {
      type: 'category',
      label: 'Getting Started',
      items: ['guides/intro', 'guides/setup'],
    },
    {
      type: 'category',
      label: 'How-To Guides',
      items: [
        'guides/guide-create-port',
        'guides/guide-create-port-build',
        'guides/guide-create-port-download',
        'guides/guide-update-port',
        'guides/guide-update-version-baseline',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      items: ['guides/references', 'guides/troubleshooting'],
    },
  ],

  // Sidebar for GitHub Copilot prompts
  promptsSidebar: [
    {
      type: 'category',
      label: 'Copilot Prompts',
      items: [
        'prompts/intro',
        'prompts/check-environment',
        'prompts/search-port',
        'prompts/create-port',
        'prompts/install-port',
        'prompts/check-port-upstream',
        'prompts/update-port',
        'prompts/update-version-baseline',
        'prompts/review-port',
      ],
    },
  ],
};

export default sidebars;
