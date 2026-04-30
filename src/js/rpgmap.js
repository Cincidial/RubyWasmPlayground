function getRpgMapCanvas(id) {
    const map = build_data.map_data[id]
    const atlas = build_data.atlas_meta[map.tileset]
    const node = document.getElementById('rpgmap-template').content.cloneNode(true)
    const tw = atlas.common_width // Tile width
    const th = atlas.common_height // Tile height

    const canvas = node.getElementById('canvas')
    canvas.width = map.width * tw
    canvas.height = map.height * th
    const draw_context = canvas.getContext('2d')

    map.tiles.forEach((row, y) => {
        row.forEach((tile, x) => {
            tile.forEach((layer_tile_id) => {
                try {
                    const tile_data = atlas[layer_tile_id]
                    draw_context.drawImage(tile_atlas_img, tile_data.x, tile_data.y, tw, th, x * tw, y * th, tw, th)
                } catch (ex) {
                    console.log(ex)
                }
            })
        })
    })

    return node
}
