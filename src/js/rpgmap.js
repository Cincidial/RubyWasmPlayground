function getRpgMap(id) {
    const map = build_data.map_data[id]
    const atlas = build_data.atlas_meta[map.tileset]
    const node = document.getElementById('rpgmap-template').content.cloneNode(true)
    const tw = atlas.w // Tile width
    const th = atlas.h // Tile height

    const canvas = node.getElementById('canvas')
    canvas.width = map.width * tw
    canvas.height = map.height * th
    const draw_context = canvas.getContext('2d')

    const rpg_map = {
        node: node,
        draw_context: draw_context,
        map: map,
        tw: tw,
        th: th,
        current_cursor_tile_id: -1,
        current_cursor_img_data: null,
    }

    console.log(map)
    map.tiles.forEach((row, y) => {
        row.forEach((tile, x) => {
            tile.forEach((layer_tile_id) => {
                coordinate_key = x + y * map.width

                try {
                    const tile_data = atlas[layer_tile_id]
                    draw_context.drawImage(tile_atlas_img, tile_data.x, tile_data.y, tw, th, x * tw, y * th, tw, th)
                } catch (ex) {
                    console.log(ex)
                }
            })
        })
    })

    const sprite_direction_src_y_offsets = {
        2: 0, // South
        4: 64, // West
        6: 128, // East
        8: 192, // North
    }
    Object.keys(map.events ?? {}).forEach((coordinate_key) => {
        const event = map.events[coordinate_key]
        const overworld = event.overworld.replaceAll('Followers/', '').replaceAll('Followers shiny', '')
        let event_draw_data = event.tile_id_graphic != 0 ? atlas[event.tile_id_graphic] : overworld_atlas_meta[overworld] ? overworld_atlas_meta[overworld] : null

        if (event_draw_data) {
            const dst_x = (coordinate_key % map.width) * tw
            const dst_y = Math.trunc(coordinate_key / map.width) * th

            var src_y_direction_offset = sprite_direction_src_y_offsets[event.direction] ?? 0
            var src_w = 64
            var src_h = 64
            var dst_w = 64
            var dst_h = 64
            var dst_x_offset = -16
            var dst_y_offset = -32
            for (const cmd of event.cmds) {
                if (cmd.type == 'item' || cmd.type == 'explodeRock') {
                    dst_w = tw
                    dst_h = th
                    dst_x_offset = 0
                    dst_y_offset = 0
                    break
                } else if (cmd.type == 'berry') {
                    src_w = 32
                    dst_w = 32
                    dst_x_offset = 0
                    dst_y_offset = 0
                    break
                } else if (cmd.type == 'avatar') {
                    // These offsets might not align every avatar.
                    dst_w = 128
                    dst_h = 128
                    dst_x_offset = -32
                    dst_y_offset = -64
                    break
                } else if (cmd.type == 'trainer_follower_mon') {
                    const mon_key = build_data.pbs.trainers[cmd.k]?.pokemon[0]?.k
                    event_draw_data = overworld_atlas_meta[mon_key] ?? event_draw_data
                    break
                }
            }
            draw_context.drawImage(sprite_atlas_img, event_draw_data.x, event_draw_data.y + src_y_direction_offset, src_w, src_h, dst_x + dst_x_offset, dst_y + dst_y_offset, dst_w, dst_h)
        }
    })

    canvas.addEventListener('mousemove', (e) => {
        const x = e.offsetX - (e.offsetX % tw)
        const y = e.offsetY - (e.offsetY % th)
        const tile_id = Math.trunc(x / tw) + Math.trunc(y / th) * map.width

        if (rpg_map.current_cursor_tile_id != tile_id) {
            if (rpg_map.current_cursor_img_data != null) {
                const old_x = (rpg_map.current_cursor_tile_id % map.width) * tw
                const old_y = Math.trunc(rpg_map.current_cursor_tile_id / map.width) * th
                draw_context.putImageData(rpg_map.current_cursor_img_data, old_x, old_y)
            }

            rpg_map.current_cursor_img_data = draw_context.getImageData(x, y, tw, th)
            rpg_map.current_cursor_tile_id = tile_id

            const new_img_data = draw_context.getImageData(x, y, tw, th)
            const data = new_img_data.data
            for (let i = 0; i < data.length; i += 4) {
                const r = data[i]
                const g = data[i + 1]
                const b = data[i + 2]

                data[i] = Math.min(Math.round(0.593 * r + 0.869 * g + 0.389 * b), 255)
                data[i + 1] = Math.min(Math.round(0.549 * r + 0.786 * g + 0.368 * b), 255)
                data[i + 2] = Math.min(Math.round(0.472 * r + 0.634 * g + 0.331 * b), 255)
            }
            draw_context.putImageData(new_img_data, x, y)
        }
    })

    return rpg_map
}
