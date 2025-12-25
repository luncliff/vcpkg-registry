const syntaxHighlight = require("@11ty/eleventy-plugin-syntaxhighlight");
const markdownIt = require("markdown-it");
const markdownItAttrs = require("markdown-it-attrs");

module.exports = function(eleventyConfig) {
  // Add syntax highlighting plugin
  eleventyConfig.addPlugin(syntaxHighlight);

  // Configure markdown-it with attributes support
  let markdownLibrary = markdownIt({
    html: true,
    breaks: false,
    linkify: true
  }).use(markdownItAttrs);
  
  eleventyConfig.setLibrary("md", markdownLibrary);

  // Pass through assets and static files
  eleventyConfig.addPassthroughCopy("docs/assets");
  eleventyConfig.addPassthroughCopy("docs/**/*.png");
  eleventyConfig.addPassthroughCopy("docs/**/*.jpg");
  eleventyConfig.addPassthroughCopy("docs/**/*.jpeg");
  eleventyConfig.addPassthroughCopy("docs/**/*.gif");
  eleventyConfig.addPassthroughCopy("docs/**/*.svg");

  // Add a custom collection for documentation pages
  eleventyConfig.addCollection("docs", function(collectionApi) {
    return collectionApi.getFilteredByGlob("docs/**/*.md");
  });

  // Configure BrowserSync for live reload
  eleventyConfig.setBrowserSyncConfig({
    ui: false,
    ghostMode: false
  });

  return {
    dir: {
      input: "docs",
      output: "_site",
      includes: "_includes",
      layouts: "_layouts",
      data: "_data"
    },
    templateFormats: ["md", "njk", "html"],
    markdownTemplateEngine: "njk",
    htmlTemplateEngine: "njk",
    dataTemplateEngine: "njk"
  };
};
