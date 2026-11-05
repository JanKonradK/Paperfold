const parseViewport = str => str
    ?.split(/[,;\s]/) // NOTE: technically, only the comma is valid
    ?.filter(x => x)
    ?.map(x => x.split('=').map(x => x.trim()))

const getViewport = (doc, viewport) => {
    // use `viewBox` for SVG
    if (doc.documentElement.localName === 'svg') {
        const [, , width, height] = doc.documentElement
            .getAttribute('viewBox')?.split(/\s/) ?? []
        return { width, height }
    }

    // get `viewport` `meta` element
    const meta = parseViewport(doc.querySelector('meta[name="viewport"]')
        ?.getAttribute('content'))
    if (meta) return Object.fromEntries(meta)

    // fallback to book's viewport
    if (typeof viewport === 'string') return parseViewport(viewport)
    if (viewport) return viewport

    // if no viewport (possibly with image directly in spine), get image size
    const img = doc.querySelector('img')
    if (img) return { width: img.naturalWidth, height: img.naturalHeight }

    // just show *something*, i guess...
    console.warn(new Error('Missing viewport properties'))
    return { width: 1000, height: 2000 }
}

export class FixedLayout extends HTMLElement {
    #root = this.attachShadow({ mode: 'closed' })
    #observer = new ResizeObserver(() => this.#render())
    #spreads
    #index = -1
    defaultViewport
    spread
    #portrait = false
    #left
    #right
    #center
    #side
    #turn = 0
    // The turn on screen. While it differs from #turn, a spread is loading.
    #shown = 0
    constructor() {
        super()

        const sheet = new CSSStyleSheet()
        this.#root.adoptedStyleSheets = [sheet]
        sheet.replaceSync(`:host {
            width: 100%;
            height: 100%;
            display: flex;
            justify-content: center;
            align-items: center;
        }`)

        this.#observer.observe(this)
    }
    async #createFrame(position, { index, src }) {
        const element = document.createElement('div')
        const iframe = document.createElement('iframe')
        element.append(iframe)
        Object.assign(iframe.style, {
            border: '0',
            display: 'none',
            overflow: 'hidden',
        })
        // `allow-scripts` is needed for events because of WebKit bug
        // https://bugs.webkit.org/show_bug.cgi?id=218086
        iframe.setAttribute('sandbox', 'allow-same-origin allow-scripts')
        iframe.setAttribute('scrolling', 'no')
        iframe.setAttribute('part', 'filter')
        this.#root.append(element)
        if (!src) return { blank: true, element, iframe }
        return new Promise(resolve => {
            const onload = () => {
                iframe.removeEventListener('load', onload)
                const doc = iframe.contentDocument
                doc.position = position
                const { width, height } = getViewport(doc, this.defaultViewport)
                resolve({
                    element, iframe, doc, index,
                    width: parseFloat(width),
                    height: parseFloat(height),
                })
            }
            iframe.addEventListener('load', onload)
            iframe.src = src
        })
    }
    #render(side = this.#side) {
        if (!side) return
        const left = this.#left ?? {}
        const right = this.#center ?? this.#right
        const target = side === 'left' ? left : right
        const { width, height } = this.getBoundingClientRect()
        const portrait = this.spread !== 'both' && this.spread !== 'portrait'
            && height > width
        this.#portrait = portrait
        const blankWidth = left.width ?? right.width
        const blankHeight = left.height ?? right.height

        const scale = portrait || this.#center
            ? Math.min(
                width / (target.width ?? blankWidth),
                height / (target.height ?? blankHeight))
            : Math.min(
                width / ((left.width ?? blankWidth) + (right.width ?? blankWidth)),
                height / Math.max(
                    left.height ?? blankHeight,
                    right.height ?? blankHeight))

        const transform = frame => {
            const { element, iframe, width, height, blank } = frame
            iframe.contentDocument.scale = scale
            Object.assign(iframe.style, {
                width: `${width}px`,
                height: `${height}px`,
                transform: `scale(${scale})`,
                transformOrigin: 'top left',
                display: blank ? 'none' : 'block',
            })
            Object.assign(element.style, {
                width: `${(width ?? blankWidth) * scale}px`,
                height: `${(height ?? blankHeight) * scale}px`,
                overflow: 'hidden',
                display: 'block',
            })
            if (portrait && frame !== target) {
                element.style.display = 'none'
            }
        }
        if (this.#center) {
            transform(this.#center)
        } else {
            transform(left)
            transform(right)
        }
    }
    async #showSpread({ left, right, center }, turn) {
        // The old page stays on screen until the new one has loaded. Clearing
        // it first showed an empty reader for every turn.
        const old = [...this.#root.children]
        const frames = center
            ? [await this.#createFrame('center', center)]
            : await Promise.all([
                this.#createFrame('left', left),
                this.#createFrame('right', right),
            ])
        if (turn !== this.#turn) {
            for (const frame of frames) frame.element.remove()
            return false
        }
        for (const element of old) element.remove()
        // Announced only now, so a superseded page never becomes the reader's
        // current document.
        for (const { doc, index } of frames) if (doc)
            this.dispatchEvent(new CustomEvent('load', { detail: { doc, index } }))
        if (center) {
            [this.#center] = frames
            this.#left = this.#right = null
            this.#side = 'center'
        } else {
            [this.#left, this.#right] = frames
            this.#center = null
            // #side, not the side asked for: a tap during the load can
            // have moved to the other page of this spread.
            this.#side = this.#left.blank ? 'right'
                : this.#right.blank ? 'left' : this.#side
        }
        this.#shown = turn
        this.#render()
        return true
    }
    // In portrait, moves to the other page of the spread on screen or loading.
    #goSide(side) {
        const spread = this.#spreads[this.#index]
        if (!this.#portrait || this.#side === side || !spread?.[side]) return false
        this.#side = side
        if (this.#shown === this.#turn) {
            this.#render()
            this.#reportLocation('page')
        }
        return true
    }
    open(book) {
        this.book = book
        const { rendition } = book
        this.spread = rendition?.spread
        this.defaultViewport = rendition?.viewport

        const rtl = book.dir === 'rtl'
        const ltr = !rtl
        this.rtl = rtl

        if (rendition?.spread === 'none')
            this.#spreads = book.sections.map(section => ({ center: section }))
        else this.#spreads = book.sections.reduce((arr, section) => {
            const last = arr[arr.length - 1]
            const { linear, pageSpread } = section
            if (linear === 'no') return arr
            const newSpread = () => {
                const spread = {}
                arr.push(spread)
                return spread
            }
            if (pageSpread === 'center') {
                const spread = last.left || last.right ? newSpread() : last
                spread.center = section
            }
            else if (pageSpread === 'left') {
                const spread = last.center || last.left || ltr ? newSpread() : last
                spread.left = section
            }
            else if (pageSpread === 'right') {
                const spread = last.center || last.right || rtl ? newSpread() : last
                spread.right = section
            }
            else if (ltr) {
                if (last.center || last.right) newSpread().left = section
                else if (last.left) last.right = section
                else last.left = section
            }
            else {
                if (last.center || last.left) newSpread().right = section
                else if (last.right) last.left = section
                else last .right = section
            }
            return arr
        }, [{}])
    }
    get index() {
        const spread = this.#spreads[this.#index]
        const section = spread?.center ?? (this.#side === 'left'
            ? spread.left ?? spread.right : spread.right ?? spread.left)
        return this.book.sections.indexOf(section)
    }
    #reportLocation(reason) {
        this.dispatchEvent(new CustomEvent('relocate', { detail:
            { reason, range: null, index: this.index, fraction: 0, size: 1 } }))
    }
    getSpreadOf(section) {
        const spreads = this.#spreads
        for (let index = 0; index < spreads.length; index++) {
            const { left, right, center } = spreads[index]
            if (left === section) return { index, side: 'left' }
            if (right === section) return { index, side: 'right' }
            if (center === section) return { index, side: 'center' }
        }
    }
    async goToSpread(index, side, reason) {
        if (index < 0 || index > this.#spreads.length - 1) return
        if (index === this.#index) {
            // A target in the shown spread can be its hidden portrait page.
            if (side) this.#side = side
            if (this.#shown !== this.#turn) return
            this.#render()
            this.#reportLocation(reason)
            return
        }
        this.#index = index
        // Set now, so a turn during the load continues from this page.
        this.#side = side
        // A newer turn supersedes this one, so fast taps do not stack loads.
        const turn = ++this.#turn
        const spread = this.#spreads[index]
        const { sections } = this.book
        let shown
        if (spread.center) {
            const src = await spread.center.load?.()
            if (turn !== this.#turn) return
            shown = await this.#showSpread({ center:
                { index: sections.indexOf(spread.center), src } }, turn)
        } else {
            const [srcL, srcR] = await Promise.all([
                spread.left?.load?.(), spread.right?.load?.()])
            if (turn !== this.#turn) return
            const left = { index: sections.indexOf(spread.left), src: srcL }
            const right = { index: sections.indexOf(spread.right), src: srcR }
            shown = await this.#showSpread({ left, right }, turn)
        }
        if (!shown) return
        this.#reportLocation(reason)
    }
    async select(target) {
        await this.goTo(target)
        // TODO
    }
    async goTo(target) {
        const { book } = this
        const resolved = await target
        const section = book.sections[resolved.index]
        if (!section) return
        const { index, side } = this.getSpreadOf(section)
        await this.goToSpread(index, side)
    }
    async next() {
        if (!this.#goSide(this.rtl ? 'left' : 'right'))
            return this.goToSpread(this.#index + 1, this.rtl ? 'right' : 'left', 'page')
    }
    async prev() {
        if (!this.#goSide(this.rtl ? 'right' : 'left'))
            return this.goToSpread(this.#index - 1, this.rtl ? 'left' : 'right', 'page')
    }
    getContents() {
        return Array.from(this.#root.querySelectorAll('iframe'), frame => ({
            doc: frame.contentDocument,
            // TODO: index, overlayer
        }))
    }
    destroy() {
        this.#observer.unobserve(this)
    }
}

customElements.define('foliate-fxl', FixedLayout)
