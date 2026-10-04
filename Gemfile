# Local preview of the docs site: bundle exec jekyll serve --source docs
# GitHub Pages builds docs/ with its own gem set and ignores this file.
source "https://rubygems.org"

gem "jekyll", "~> 4.4"

group :jekyll_plugins do
  gem "jekyll-remote-theme"
  gem "jekyll-seo-tag"
  gem "jekyll-include-cache"
  # GitHub Pages turns these on without _config.yml listing them. Without
  # jekyll-default-layout, pages that set no layout render with no theme.
  gem "jekyll-default-layout"
  gem "jekyll-optional-front-matter"
  gem "jekyll-readme-index"
  gem "jekyll-relative-links"
  gem "jekyll-titles-from-headings"
end

# No longer bundled with Ruby 3.4+, but Jekyll 4.4 and its deps still load them.
gem "base64"
gem "bigdecimal"
gem "csv"
gem "logger"
