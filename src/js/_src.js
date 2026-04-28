document.addEventListener('DOMContentLoaded', () => {
    getBuildData()
})

var build_data
async function getBuildData() {
    try {
        const response = await fetch('build_data.json')
        if (!response.ok) {
            throw new Error(`Response status: ${response.status}`)
        }
        build_data = await response.json()

        document.body.appendChild(getPokemonIconImg('ABRA'))
    } catch (error) {
        console.error(error.message)
    }
}
