# frozen_string_literal: true

require 'pp'
require 'eidolon'

# rubocop:disable Security/MarshalLoad
Eidolon.build('RGSS') do
    parsed_data = {}
    Dir.glob('build_temp/game_data/**/*.rxdata') do |path|
        next if path == 'build_temp/game_data/Data/PkmnAnimations.rxdata'
        next if path.include?('Prototype Maps')

        filename = File.basename(path, '.*')
        file_data = File.open(path, 'rb') { |data| Marshal.load(data) }

        if filename[-3..].to_i.positive? # This is a MapXYZ.rxdata file
            map_id = filename[-3..].to_i

            parsed = { items: [] }
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
            parsed_data[map_id] = parsed
        end
    end

    pp parsed_data
    # MapInfos to be used with the MapXYZ filenames where XYZ converts to an int. @name provides the name of the location. @parent provides what map leads here
    # map65 = parsed_data['Map065']
    # pp map65.events[3].pages[0].list[0].parameters[1].include?('pbItemBall')
end
# rubocop:enable Security/MarshalLoad
