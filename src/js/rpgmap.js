function getRpgMapCanvas(id) {
    const map = build_data.map_data[id]
    const atlas = build_data.atlas_meta[map.tileset]
    const node = document.getElementById('rpgmap-template').content.cloneNode(true)
    const tw = atlas.w // Tile width
    const th = atlas.h // Tile height

    const canvas = node.getElementById('canvas')
    canvas.width = map.width * tw
    canvas.height = map.height * th
    const draw_context = canvas.getContext('2d')

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
        const event = map.events[coordinate_key][0]
        if (event) {
            // This is the position of the event, depending on the event type drawing it may be offset and scaled
            const x = coordinate_key % map.width
            const y = Math.trunc(coordinate_key / map.width)
            const src_y_offset = sprite_direction_src_y_offsets[event.direction] ?? 0

            const overworld = event.overworld.replaceAll('Followers/', '').replaceAll('Followers shiny', '')
            const event_draw_data = event.tile_id_graphic != 0 ? atlas[event.tile_id_graphic] : overworld_atlas_meta[overworld] ? overworld_atlas_meta[overworld] : overworld_atlas_meta['00itemPlaceholders']

            try {
                draw_context.drawImage(sprite_atlas_img, event_draw_data.x, event_draw_data.y + src_y_offset, 64, 64, x * tw - 16, y * th - 32, 64, 64)
            } catch {
                console.log(event)
            }
        }
    })

    return node
}
