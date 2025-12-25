// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import rehypeMermaid from 'rehype-mermaid';

// https://astro.build/config
export default defineConfig({
	site: 'https://luncliff.github.io',
	base: '/vcpkg-registry',
	markdown: {
		rehypePlugins: [
			[rehypeMermaid, { strategy: 'img-svg' }]
		],
	},
	integrations: [
		starlight({
			title: 'vcpkg-registry',
			description: 'Custom vcpkg ports registry with overlay support',
			defaultLocale: 'root',
			locales: {
				root: {
					label: 'English',
					lang: 'en',
				},
				ko: {
					label: '한국어',
					lang: 'ko',
				},
			},
			social: [
				{ 
					icon: 'github', 
					label: 'GitHub', 
					href: 'https://github.com/luncliff/vcpkg-registry' 
				}
			],
			sidebar: [
				{
					label: 'Guides',
					items: [
						{ label: 'Create Port', slug: 'guides/create-port' },
						{ label: 'Update Port', slug: 'guides/update-port' },
						{ label: 'Update Version Baseline', slug: 'guides/update-version-baseline' },
						{ label: 'Troubleshooting', slug: 'guides/troubleshooting' },
					],
				},
				{
					label: 'Build Patterns',
					items: [
						{ label: 'Port Build Guide', slug: 'guides/create-port-build' },
						{ label: 'Port Download Guide', slug: 'guides/create-port-download' },
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'External References', slug: 'reference/references' },
						{ label: 'Prompt Designs', slug: 'reference/prompt-designs' },
						{ label: 'Review Checklist', slug: 'reference/review-checklist' },
						{ label: 'Diagram Support', slug: 'reference/diagrams' },
					],
				},
			],
			customCss: [
				// Optional: Add custom styles if needed
			],
			expressiveCode: {
				themes: ['github-dark', 'github-light'],
			},
		}),
	],
});
