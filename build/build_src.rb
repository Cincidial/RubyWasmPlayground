# frozen_string_literal: true

`mkdir -p artifacts`

# Collect all the html templates and js
html_index_file_content = File.read('../src/index.html')
html_template_files_content = Dir.glob('../src/templates/*.html').map { |path| File.read(path) }.join("\n")
js_files_content = Dir.glob('../src/js/*.js').map { |path| File.read(path) }.join("\n")

# Write to the index.html and src.js files
File.write('artifacts/index.html', html_index_file_content.sub('#REPLACE_WITH_TEMPLATES#', html_template_files_content))
File.write('artifacts/src.js', js_files_content)

# Copy over the website icon
`cp ../icon.png artifacts/icon.png`
