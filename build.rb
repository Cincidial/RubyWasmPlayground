# frozen_string_literal: true

require 'json'

`mkdir -p build_temp`
# `git clone https://github.com/Pokemon-Tectonic-Team/Pokemon-Tectonic-Content.git build_temp/game_data`

# for each git hash to processes, checkout the hash
# Alternativly, make a guide on how to set this up via forking, then each dev can have their own dev branch with hash to checkout. Save on build time

# Prep the icons as they need to be cropped
`mkdir -p build_temp/cropped_icons`
# `mogrify -path build_temp/cropped_icons -crop 64x64+0+0 +repage ./build_temp/game_data/Graphics/Pokemon/Icons/*.png`

# Build Sprite Atlas - Step 1 - Row calculations so we can batch it (also creates the json for slicing the image)
atlas_files_hash = { icon: [], front: [] }
atlas_files_hash[:icon] = Dir.glob('build_temp/cropped_icons/*.png')
atlas_files_hash[:front] = Dir.glob('build_temp/game_data/Graphics/Pokemon/Front/*.png')
atlas_rows = [[]]

atlas_meta_hash = { icon: {}, front: {} }
x = 0
y = 0

atlas_files_hash.each do |k, file_list|
    dimens_list = `identify -format "%f;%w;%h:" #{file_list.join(' ')}`.split(':')
    dimens_hash = {}
    dimens_list.each do |output|
        filename, width, height = output.split(';')
        dimens_hash[File.basename(filename, '.*')] = { width: width.to_i, height: height.to_i }
    end

    max_y = 0
    file_list.each do |path|
        filename = File.basename(path, '.*')
        width = dimens_hash[filename][:width]
        height = dimens_hash[filename][:height]
        atlas_meta_hash[k][filename] = { x: x, y: y, width: width, height: height }

        atlas_rows.last.push(path)
        x += width
        max_y = [max_y, height].max

        if x >= 8192 # May need to set the pixel limit based on the build machine
            x = 0
            y += max_y
            max_y = 0
            atlas_rows.push([])
        end
    end
end
File.write('build_temp/atlas_metadata.json', JSON.pretty_generate(atlas_meta_hash))

# Build Sprite Atlas - Step 2 - Generate the image
atlas_temp_row_file_path = 'build_temp/sprite_atlas_temp_row.png'
atlas_file_path = 'build_temp/sprite_atlas.png'
atlas_rows.each_with_index do |row, i|
    `convert #{row.join(' ')} -background none +append #{atlas_temp_row_file_path}`
    `convert #{i.zero? ? '' : atlas_file_path} #{atlas_temp_row_file_path} -background none -append #{atlas_file_path}`
end


# `rm -r build_temp`
