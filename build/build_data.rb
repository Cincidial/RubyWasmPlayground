# frozen_string_literal: true

require 'json'
require 'pp'
require 'eidolon'
run_img_cmds = true

magick_config = 'MAGICK_CONFIGURE_PATH="image_magick_config/"'
`mkdir -p build_temp`
`mkdir -p artifacts`

############# Clone the repo
`git clone https://github.com/Pokemon-Tectonic-Team/Pokemon-Tectonic-Content.git build_temp/game_data`

############# Build output
tileset_atlas_artifact_name = 'tileset_atlas.png'
sprite_atlas_artifact_name = 'sprite_atlas.png'

atlas_meta_hash = { # The tilesets use a different atlas, but everything defined here is going to have the same one
    icon: { w: 64, h: 64, atlas_name: sprite_atlas_artifact_name },
    front: { w: 160, h: 160, atlas_name: sprite_atlas_artifact_name },
    item: { w: 48, h: 48, atlas_name: sprite_atlas_artifact_name },
    trainer: { w: 160, h: 160, atlas_name: sprite_atlas_artifact_name },
    overworld: { w: 64, h: 256, atlas_name: sprite_atlas_artifact_name } # Take the first vertical column so that we can use the directional sprites
}
tileset_atlas_file_path = 'build_temp/tileset_atlas.png'
sprite_atlas_file_path = 'build_temp/sprite_atlas.png'
json_file_path = 'build_temp/build_processed_data.json'

############# Parse rxdata
# MANUAL STEP: Encounter tiles are mapped via their terrarin tags, which are further mapped to the string ID the PBS data uses
#   - Terrain tag id to first mapping string: https://github.com/Pokemon-Tectonic-Team/Pokemon-Tectonic-Content/blob/17ab40cb718188ec6d10b34a1b07c929ec7dd1a0/Plugins/Chasm%20Game%20Data/Static%20Data/TerrainTag.rb
#   - Mapping string to PBS: https://github.com/Pokemon-Tectonic-Team/Pokemon-Tectonic-Content/blob/17ab40cb718188ec6d10b34a1b07c929ec7dd1a0/Plugins/Chasm%20Other/WildPokemon/EncounterChecks.rb#L200
encounter_tile_terrain_mapping = {
    2 => 'Land', # Grass
    10 => 'LandTall', # Tall Grass
    17 => 'Mud', # Mud
    18 => 'Puddle', # Puddle
    19 => 'LandSparse', # Sparse Grass
    20 => 'DarkCave', # Dark Cave
    21 => 'FlowerGrass', # Flowery Grass
    22 => 'FlowerGrass2', # Flowery Grass 2
    23 => 'LandTinted', # Tinted Grass
    24 => 'SewerFloor', # Sewer Floor
    25 => 'SewerWater', # Sewer Water
    28 => 'FishingContest', # Fishing Contest
    33 => 'ActiveWater', # Active Water
    34 => 'Cloud', # Dark Cloud
    44 => 'WaterGrass' # Water Grass
}

tile_layers_freq = {}
map_data = {}
tile_data = {}
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
            parsed_map = {
                name: 'placeholder',
                events: {}, # Key = x + (y * width). All entries have a 'type' member, indicating the type of event. Each entry here is a list
                tiles: [],
                tileset: file_data.tileset_id,
                width: file_data.width,
                height: file_data.height
            }
            used_tiles[file_data.tileset_id] ||= {}

            file_data.events.each_value do |event|
                coordinate_key = event.x + (event.y * parsed_map[:width])
                has_processed_name = false

                event.pages.each do |page|
                    parsed_event = parsed_map[:events][coordinate_key] ||= {
                        tile_id_graphic: page.graphic.tile_id, # When this is 0 the overworld graphic should be used, otherwise use the tile
                        overworld: page.graphic.character_name,
                        direction: page.graphic.direction, # 2 => South, 4 => West, 6 => East, 8 => North
                        cmds: []
                    }

                    if !has_processed_name && event.name.include?('resetfollower') # I think this means "use the overworld sprite of the trainers first mon"
                        func_params = event.name[/\((.*?)\)/, 1] || '' # For example resetfollower(:LINEBACKER,\"Josh\").
                        func_params_split = func_params.split(',') || ''

                        if func_params_split.length >= 2
                            parsed_cmd = {}
                            parsed_cmd[:type] = 'trainer_follower_mon'
                            trainer_type = func_params_split[0][1..] # The id in the param starts with ':'
                            trainer_name = func_params_split[1][/"(.*?)"/, 1]
                            trainer_extra = func_params_split.length >= 3 ? func_params_split[2] : nil

                            parsed_cmd[:k] = "#{trainer_type},#{trainer_name}"
                            parsed_cmd[:k] += ",#{trainer_extra}" if trainer_extra

                            parsed_event[:cmds].push(parsed_cmd)
                            has_processed_name = true
                        end
                    end

                    page.list.each do |cmd|
                        parsed_cmd = {}
                        cmd.parameters.each do |param|
                            next unless param.is_a?(String)

                            type_item = param.include?('pbItemBall') ? 'item' : nil
                            type_item_gift = param.include?('pbReceiveItem') ? 'item_gift' : nil
                            type_berry = param.include?('pbPickBerry') ? 'berry' : nil

                            if type_item || type_item_gift || type_berry
                                func_params = param[/\((.*?)\)/, 1] # For example pbItemBall(:HYPERPOTION,1)
                                func_params_split = func_params.split(',')

                                parsed_cmd[:type] = type_item || type_item_gift || type_berry
                                parsed_cmd[:id] = func_params_split[0][1..] # The id in the param starts with ':'
                                parsed_cmd[:count] = func_params_split.length > 1 ? func_params_split[1].to_i : 1 # Parse the count or assume 1 if it's not there
                            elsif param.include?('pbTrainerBattle')
                                func_params = param[/\((.*?)\)/, 1] # For example pbTrainerBattle(:LINEBACKER,\"Josh\"),
                                func_params_split = func_params.split(',')

                                parsed_cmd[:type] = 'trainer'
                                trainer_type = func_params_split[0][1..] # The id in the param starts with ':'
                                trainer_name = func_params_split[1][/"(.*?)"/, 1]
                                trainer_extra = func_params_split.length >= 3 ? func_params_split[2] : nil

                                parsed_cmd[:k] = "#{trainer_type},#{trainer_name}"
                                parsed_cmd[:k] += ",#{trainer_extra}" if trainer_extra
                            elsif param.include?('introduceAvatar')
                                func_params = param[/\((.*?)\)/, 1] # For example introduceAvatar(:LEDIAN),

                                parsed_cmd[:type] = 'avatar'
                                parsed_cmd[:mon] = func_params[1..] # The id in the param starts with ':'
                            elsif param.include?('mapTransitionTransfer')
                                func_params = param[/\((.*?)\)/, 1] # For example, mapTransitionTransfer(185,9,22)
                                new_map_id, x, y = func_params.split(',')

                                parsed_cmd[:type] = 'map'
                                parsed_cmd[:id] = new_map_id
                                parsed_cmd[:x] = x
                                parsed_cmd[:y] = y
                            elsif param.include?('pbRockSmashDynamite')
                                parsed_cmd[:type] = 'explodeRock'
                            end

                            parsed_event[:cmds].push(parsed_cmd) if parsed_cmd[:type]
                        end
                    end
                end
            end
            for y in 0...file_data.height
                parsed_map[:tiles].push([])
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
                    parsed_map[:tiles].last.push(layers_key)
                end
            end
            map_data[map_id] = parsed_map
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

############# Build Tileset Atlas
tileset_width = 256 # Each tileset is 256 pixels wide
tile_width_height = 32
tile_count_per_row = tileset_width / tile_width_height
x_offset = 0
used_tiles.each do |tileset_key, v|
    tileset = tile_sets_file[tileset_key]
    tileset_name = tileset.tileset_name
    next if tileset_name == ''

    atlas_meta_hash[tileset_key] = { w: 32, h: 32, atlas_name: tileset_atlas_artifact_name }
    tile_data[tileset_key] = {}
    v.each_key do |k|
        k_calc = k - 384 # 0-384 is auto tile and needs to be treated differently

        x_pixel = ((k_calc % tile_count_per_row) * tile_width_height) + x_offset
        y_pixel = (k_calc / tile_count_per_row) * tile_width_height
        atlas_meta_hash[tileset_key][k] = { x: x_pixel, y: y_pixel }

        terrarin_tag = tileset.terrain_tags[k_calc]
        tile_data[tileset_key][k] = terrarin_tag if encounter_tile_terrain_mapping.key?(terrarin_tag)
    end

    tileset_path = "build_temp/game_data/Graphics/Tilesets/#{tileset_name}.png"
    `#{magick_config} convert #{x_offset.zero? ? '' : tileset_atlas_file_path} #{tileset_path} -background none +append #{tileset_atlas_file_path}` if run_img_cmds
    x_offset += tileset_width
end

# Prep all the images for the sprite atlas
`mkdir -p build_temp/icons`
`mkdir -p build_temp/fronts`
`mkdir -p build_temp/items`
`mkdir -p build_temp/trainers`
`mkdir -p build_temp/overworld`

sprite_atlas_prep_cmds = [
    "mogrify -path build_temp/icons -crop #{atlas_meta_hash[:icon][:w]}x#{atlas_meta_hash[:icon][:h]}+0+0 +repage ./build_temp/game_data/Graphics/Pokemon/Icons/*.png",
    "mogrify -path build_temp/fronts -resize #{atlas_meta_hash[:front][:w]}x#{atlas_meta_hash[:front][:h]} +repage ./build_temp/game_data/Graphics/Pokemon/Front/*.png",
    "mogrify -path build_temp/items -resize #{atlas_meta_hash[:item][:w]}x#{atlas_meta_hash[:item][:h]} +repage ./build_temp/game_data/Graphics/Items/*.png",
    "mogrify -path build_temp/trainers -resize #{atlas_meta_hash[:trainer][:w]}x#{atlas_meta_hash[:trainer][:h]} +repage ./build_temp/game_data/Graphics/Trainers/*.png",
    "mogrify -path build_temp/overworld -resize 256x256 -crop #{atlas_meta_hash[:overworld][:w]}x#{atlas_meta_hash[:overworld][:h]}+0+0 +repage ./build_temp/game_data/Graphics/Characters/*.png",
    "mogrify -path build_temp/overworld -resize 256x256 -crop #{atlas_meta_hash[:overworld][:w]}x#{atlas_meta_hash[:overworld][:h]}+0+0 +repage ./build_temp/game_data/Graphics/Characters/Followers/*.png"
]
pids = []
if run_img_cmds
    sprite_atlas_prep_cmds.each do |cmd|
        pids << fork do
            exec(cmd)
        end
    end
    pids.each { |pid| Process.wait(pid) }
end

# Build Sprite Atlas - Step 1 - Row calculations so we can batch it (also creates the json for slicing the image)
atlas_files_hash = { overworld: [], icon: [], item: [], front: [], trainer: [] } # Order of these keys affects placement in the atlas png
atlas_rows = [[]]
x = 0
y = 0

atlas_files_hash[:icon] = Dir.glob('build_temp/icons/*.png')
atlas_files_hash[:front] = Dir.glob('build_temp/fronts/*.png')
atlas_files_hash[:item] = Dir.glob('build_temp/items/*.png')
atlas_files_hash[:trainer] = Dir.glob('build_temp/trainers/*.png')
atlas_files_hash[:overworld] = Dir.glob('build_temp/overworld/*.png')

atlas_files_hash.each do |k, file_list|
    width = atlas_meta_hash[k][:w]
    height = atlas_meta_hash[k][:h]

    max_y = 0
    file_list.each do |path|
        filename = File.basename(path, '.*')

        atlas_meta_hash[k][filename] = { x: x, y: y }
        atlas_rows.last.push("'#{path}'")
        x += width
        max_y = [max_y, height].max

        next if x < 32_768

        x = 0
        y += max_y
        max_y = 0
        atlas_rows.push([])
    end
end

############# Build Sprite Atlas - Step 2 - Generate the image
sprite_atlas_temp_row_file_path = 'build_temp/sprite_atlas_temp_row.png'
atlas_rows.each_with_index do |row, i|
    `#{magick_config} convert #{row.join(' ')} -background none +append #{sprite_atlas_temp_row_file_path}` if run_img_cmds
    `#{magick_config} convert #{i.zero? ? '' : sprite_atlas_file_path} #{sprite_atlas_temp_row_file_path} -background none -append #{sprite_atlas_file_path}` if run_img_cmds
end

############# Huffman encode tileset [x,y,z] values to save a bunch of space in the json
tile_new_key_mappings = {}
tile_key_alphabet = [('A'..'Z'), ('a'..'z'), ('0'..'9')].flat_map(&:to_a)
tile_key_counters = [0, -1, -1] # At 62x62x62 possibilities we far exceed our current number of combos (that we see)
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

############# Parse PBS data
def parse_bracket_entries_file_to_entry_with_lines(filename, kv_split_delim = '=')
    entry = nil
    File.readlines("build_temp/game_data/PBS/#{filename}.txt", mode: "r:BOM|UTF-8").each do |line|
        line = line.split('#')[0].strip
        next if line.empty?

        if line.start_with?('[')
            yield(entry) unless entry.nil?
            entry = { id: line[/\[(.*?)\]/, 1], lines: [] }
        else
            puts line if entry.nil?
            entry[:lines].push(line)
        end
    end
    yield(entry) unless entry.nil?
end

trainers = {}
parse_bracket_entries_file_to_entry_with_lines('trainers') do |entry|
    type, name, extra = entry[:id].split(',').map(&:strip)
    trainer = { t: type, n: name, pokemon: [] }
    trainer[:extra] = extra if extra

    entry[:lines].each do |line|
        k, v = line.split('=').map(&:strip)
        if k == 'Pokemon'
            mon, lvl = v.split(',').map(&:strip)
            trainer[:pokemon].push({ k: mon, lvl: lvl.to_i })
        elsif k == 'Form'
            trainer[:pokemon].last[:form] = v.to_i
        elsif k == 'Moves'
            trainer[:pokemon].last[:moves] = v.split(',').map(&:strip)
        elsif k == 'AbilityIndex'
            trainer[:pokemon].last[:ability] = v.to_i
        elsif k == 'Item'
            trainer[:pokemon].last[:item] = v
        elsif k == 'ItemType'
            trainer[:pokemon].last[:item_type] = v
        elsif k == 'Gender'
            trainer[:pokemon].last[:gender] = v
        elsif k == 'Name'
            trainer[:pokemon].last[:nickname] = v
        elsif k == 'EV'
            trainer[:pokemon].last[:ev] = v.split(',').map(&:strip).map(&:to_i)
        else
            trainer[k] = v
        end
    end

    trainers[entry[:id]] = trainer
end

############# Write atlas and other processed data
processed_data = {
    atlas_meta: atlas_meta_hash,
    map_data: map_data,
    map_huffman_mapping: tile_new_key_mappings.invert,
    tile_tag_data: tile_data,
    encounter_tile_tag_mapping: encounter_tile_terrain_mapping,
    pbs: {
        trainers: trainers,
    }
}
File.write(json_file_path, JSON.generate(processed_data))

############# Move everything into artifacts
`mv #{tileset_atlas_file_path} artifacts/#{tileset_atlas_artifact_name}`
`mv #{sprite_atlas_file_path} artifacts/#{sprite_atlas_artifact_name}`
`mv #{json_file_path} artifacts/build_data.json`
