function getAtlasImg(x, y, w, h, filename) {
    const node = document.getElementById('atlas-img-template').content.cloneNode(true)
    const img = node.getElementById('img')
    img.style = `width: ${w}px; height: ${h}px; background-image: url('${filename}'); background-position: -${x}px -${y}px;`

    return node
}

function getPokemonIconImg(id) {
    const w = build_data.atlas_meta.icon.common_width
    const h = build_data.atlas_meta.icon.h
    const data = build_data.atlas_meta.icon[id]
    return getAtlasImg(data.x, data.y, w, h, build_data.atlas_meta.icon.atlas_name)
}

function getPokemonFrontImg(id) {
    const data = build_data.atlas_meta.front[id]
    return getAtlasImg(data.x, data.y, data.w, data.h, build_data.atlas_meta.front.atlas_name)
}
