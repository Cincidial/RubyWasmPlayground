document.addEventListener('DOMContentLoaded', () => {
    getBuildData()
})

var build_data
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

        // TODO: This needs to be cleaned up
        tile_atlas_img = new Image()
        tile_atlas_img.onload = () => {
            document.body.appendChild(getSearch(Object.keys(build_data.map_data).map((m) => ({ k: m, v: build_data.map_data[m].name }))))
        }
        tile_atlas_img.src = build_data.atlas_meta[24].atlas_name
    } catch (error) {
        console.error(error.message)
    }
}
