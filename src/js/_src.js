document.addEventListener('DOMContentLoaded', () => {
    getBuildData()
})

var build_data
var sprite_atlas_img
var overworld_atlas_meta
var tile_atlas_img

async function getBuildData() {
    try {
        const response = await fetch('build_data.json')
        if (!response.ok) {
            throw new Error(`Response status: ${response.status}`)
        }
        build_data = await response.json()

        // Expand the huffman encoding for the tile data
        const huffman_mapping = build_data.map_huffman_mapping
        Object.values(build_data.map_data).forEach((map) => {
            map.tiles.forEach((row) => {
                row.forEach((key, i) => {
                    row[i] = huffman_mapping[key].split(',').map(Number)
                })
            })
        })

        // TODO: Add a loading icon that goes away when both atlas have finished
        tile_atlas_img = new Image()
        tile_atlas_img.onload = () => {
            document.body.appendChild(getSearch(Object.keys(build_data.map_data).map((m) => ({ k: m, v: build_data.map_data[m].name }))))
        }
        tile_atlas_img.src = 'tileset_atlas.png'

        sprite_atlas_img = new Image()
        overworld_atlas_meta = build_data.atlas_meta['overworld']
        sprite_atlas_img.src = 'sprite_atlas.png'
    } catch (error) {
        console.error(error.message)
    }
}
