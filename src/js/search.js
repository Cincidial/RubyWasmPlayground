var setElement

function getSearch(kvs) {
    const node = document.getElementById('search-template').content.cloneNode(true)
    const select = node.getElementById('select')

    kvs.forEach((kv) => select.add(new Option(kv.v, kv.k)))
    select.addEventListener('change', (event) => {
        if (setElement) {
            setElement.remove()
        }

        const selectedValue = event.target.value
        const rpgMap = getRpgMap(selectedValue)

        setElement = rpgMap.node.children[0]
        document.body.appendChild(rpgMap.node)
    })

    return node
}
