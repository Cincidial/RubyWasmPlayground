# frozen_string_literal: true

require 'json'
require 'pp'
require 'eidolon'

magick_config = 'MAGICK_CONFIGURE_PATH="image_magick_config/"'
`mkdir -p build_temp`
`mkdir -p artifacts`

# Clone the repo
`git clone https://github.com/Pokemon-Tectonic-Team/Pokemon-Tectonic-Content.git build_temp/game_data`

# Build output
tileset_atlas_artifact_name = 'tileset_atlas.png'
sprite_atlas_artifact_name = 'sprite_atlas.png'

atlas_meta_hash = { icon: { common_width: 64, common_height: 64, atlas_name: sprite_atlas_artifact_name }, front: { atlas_name: sprite_atlas_artifact_name } }
tileset_atlas_file_path = 'build_temp/tileset_atlas.png'
sprite_atlas_file_path = 'build_temp/sprite_atlas.png'
json_file_path = 'build_temp/build_processed_data.json'

# Parse rxdata
tile_layers_freq = {}
map_data = {}
used_tiles = {}
map_infos_file = {}
tile_sets_file = {}

# rubocop:disable Security/MarshalLoad
Eidolon.build('RGSS') do
    Dir.glob('build_temp/game_data/**/*.rxdata') do |path|
        next if path == 'build_temp/game_data/Data/PkmnAnimations.rxdata'
        next if path.include?('Prototype Maps')

        filename = File.basename(path, '.*')
        file_data = File.open(path, 'rb') { |data| Marshal.load(data) }

        if filename[-3..].to_i.positive? # This is a MapXYZ.rxdata file
            map_id = filename[-3..].to_i

            parsed = { name: 'placeholder', items: [], tiles: [], tileset: file_data.tileset_id, width: file_data.width, height: file_data.height }
            used_tiles[file_data.tileset_id] ||= {}

            file_data.events.each_value do |event|
                event.pages.each do |page|
                    page.list.each do |cmd|
                        cmd.parameters.each do |param|
                            next unless param.is_a?(String) && (param.include?('pbItemBall') || param.include?('pbReceiveItem'))

                            is_gift = param.include?('pbReceiveItem')
                            func_params = param[/\((.*?)\)/, 1] # For example pbItemBall(:HYPERPOTION,1)
                            func_params_split = func_params.split(',')
                            id = func_params_split[0][1..] # The id in the param starts with ':'
                            count = func_params_split.length > 1 ? func_params_split[1].to_i : 1 # Parse the count or assume 1 if it's not there
                            parsed[:items].push(is_gift: is_gift, id: id, count: count)
                        end
                    end
                end
            end
            for y in 0...file_data.height
                parsed[:tiles].push([])
                for x in 0...file_data.width
                    bottom_layer = file_data.data[x, y, 0]
                    middle_layer = file_data.data[x, y, 1]
                    top_layer = file_data.data[x, y, 2]

                    used_tiles[file_data.tileset_id][bottom_layer] = true
                    used_tiles[file_data.tileset_id][middle_layer] = true
                    used_tiles[file_data.tileset_id][top_layer] = true

                    layers_key = [bottom_layer, middle_layer, top_layer].join(',')
                    tile_layers_freq[layers_key] ||= 0
                    tile_layers_freq[layers_key] += 1
                    parsed[:tiles].last.push(layers_key)
                end
            end
            map_data[map_id] = parsed
        elsif filename == 'MapInfos'
            map_infos_file = file_data
        elsif filename == 'Tilesets'
            file_data.each do |tileset|
                next if tileset.nil?

                tile_sets_file[tileset.id] = tileset
            end
        end
    end

    map_infos_file.each do |k, v|
        map_data[k][:name] = v.name
    end
end
# rubocop:enable Security/MarshalLoad

# Build Tileset Atlas
tileset_width = 256 # Each tileset is 256 pixels wide
tile_width_height = 32
tile_count_per_row = tileset_width / tile_width_height
x_offset = 0
used_tiles.each do |tileset_key, v|
    tileset_name = tile_sets_file[tileset_key].tileset_name
    next if tileset_name == ''

    atlas_meta_hash[tileset_key] = { common_width: 32, common_height: 32, atlas_name: tileset_atlas_artifact_name }
    v.each_key do |k|
        k_calc = k - 384 # 0-384 is auto tile and needs to be treated differently
        x = ((k_calc % tile_count_per_row) * tile_width_height) + x_offset
        y = (k_calc / tile_count_per_row) * tile_width_height
        atlas_meta_hash[tileset_key][k] = { x: x, y: y }
    end

    tileset_path = "build_temp/game_data/Graphics/Tilesets/#{tileset_name}.png"
    `#{magick_config} convert #{x_offset.zero? ? '' : tileset_atlas_file_path} #{tileset_path} -background none +append #{tileset_atlas_file_path}`
    x_offset += tileset_width
end

# Prep the icons as they need to be cropped
`mkdir -p build_temp/cropped_icons`
`mogrify -path build_temp/cropped_icons -crop 64x64+0+0 +repage ./build_temp/game_data/Graphics/Pokemon/Icons/*.png`

# Build Sprite Atlas - Step 1 - Row calculations so we can batch it (also creates the json for slicing the image)
atlas_files_hash = { icon: [], front: [] }
atlas_rows = [[]]
x = 0
y = 0

atlas_files_hash[:icon] = Dir.glob('build_temp/cropped_icons/*.png')
atlas_files_hash[:front] = Dir.glob('build_temp/game_data/Graphics/Pokemon/Front/*.png')

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

        atlas_meta_hash[k][filename] = atlas_meta_hash[k].key?(:common_width) ? { x: x, y: y } : { x: x, y: y, w: width, h: height }
        atlas_rows.last.push(path)
        x += width
        max_y = [max_y, height].max

        # May need to set the pixel limit based on the build machine
        next if x < 8192

        x = 0
        y += max_y
        max_y = 0
        atlas_rows.push([])
    end
end

# Build Sprite Atlas - Step 2 - Generate the image
sprite_atlas_temp_row_file_path = 'build_temp/sprite_atlas_temp_row.png'
atlas_rows.each_with_index do |row, i|
    `convert #{row.join(' ')} -background none +append #{sprite_atlas_temp_row_file_path}`
    `convert #{i.zero? ? '' : sprite_atlas_file_path} #{sprite_atlas_temp_row_file_path} -background none -append #{sprite_atlas_file_path}`
end

# Lazy huffman encode tileset [x,y,z] values to save a bunch of space in the json
tile_new_key_mappings = {}
tile_key_alphabet = [('A'..'Z'), ('a'..'z'), ('0'..'9')].flat_map(&:to_a)
tile_key_counters = [0, -1, -1] # At 62x62x62 possibilities we far exceed our current number of combos
tile_layers_freq.sort_by { |_, v| v }.reverse_each do |k, _|
    first = tile_key_alphabet[tile_key_counters[0]]
    second = tile_key_counters[1] >= 0 ? tile_key_alphabet[tile_key_counters[1]] : ''
    third = tile_key_counters[2] >= 0 ? tile_key_alphabet[tile_key_counters[2]] : ''

    tile_new_key_mappings[k] = [first, second, third].join

    tile_key_counters[0] += 1
    if tile_key_counters[0] >= tile_key_alphabet.count
        tile_key_counters[0] = 0
        tile_key_counters[1] += 1
    end
    if tile_key_counters[1] >= tile_key_alphabet.count
        tile_key_counters[1] = 0
        tile_key_counters[2] += 1
    end
    if tile_key_counters[2] >= tile_key_alphabet.count
        puts 'Error - Run out of keys for map layer encoding'
        exit!(false)
    end
end
map_data.each_value do |v|
    v[:tiles].each do |col|
        for i in (0...col.count)
            col[i] = tile_new_key_mappings[col[i]]
        end
    end
end

# Parse PBS data

# Write atlas and other processed data
processed_data = { atlas_meta: atlas_meta_hash, map_data: map_data, map_huffman_mapping: tile_new_key_mappings.invert }
File.write(json_file_path, JSON.generate(processed_data))

# Move everything into artifacts
`mv #{tileset_atlas_file_path} artifacts/#{tileset_atlas_artifact_name}`
`mv #{sprite_atlas_file_path} artifacts/#{sprite_atlas_artifact_name}`
`mv #{json_file_path} artifacts/build_data.json`
