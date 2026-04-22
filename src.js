var build_data
async function getBuildData() {
    try {
        const response = await fetch('atlas_metadata.json')
        if (!response.ok) {
            throw new Error(`Response status: ${response.status}`)
        }

        build_data = await response.json()
        Object.entries(build_data['icon']).forEach(([k, v]) => {
            var elem = document.createElement('div')
            const x = -v['x']
            const y = -v['y']
            const width = v['width']
            const height = v['height']
            elem.style.cssText = `width: ${width}px; height: ${height}px; background-image: url('sprite_atlas.png'); background-repeat: no-repeat; background-position: ${x}px ${y}px; overflow: hidden`
            document.body.appendChild(elem)
        })
        Object.entries(build_data['front']).forEach(([k, v]) => {
            var elem = document.createElement('div')
            const x = -v['x']
            const y = -v['y']
            const width = v['width']
            const height = v['height']
            elem.style.cssText = `width: ${width}px; height: ${height}px; background-image: url('sprite_atlas.png'); background-repeat: no-repeat; background-position: ${x}px ${y}px; overflow: hidden`
            document.body.appendChild(elem)
        })
    } catch (error) {
        console.error(error.message)
    }
}

document.addEventListener('DOMContentLoaded', () => {
    getBuildData()
})
