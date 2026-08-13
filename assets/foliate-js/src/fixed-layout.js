// How many recently shown sections keep hold of their resources before being
// asked to give them back. Wide enough that turning a page and turning straight
// back is free, narrow enough that reading a 400-page document does not end
// with all 400 pages resident.
const unloadKeepWindow = 6

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
    // Two persistent frame slots, in DOM order. Every page turn used to call
    // `replaceChildren` and build two fresh iframes, so a turn cost an element
    // teardown and two document creations on top of loading the page itself.
    // The slots are made once and navigated instead.
    #slots = []
    // Bumped by each `#showSpread`. A turn that arrives while an earlier one is
    // still loading takes ownership of the slots, and the earlier one must not
    // then announce a document that is no longer on screen.
    #generation = 0
    // Recently shown section indices, oldest first, so the ones left behind can
    // be unloaded. `Paginator` already does this (paginator.js:1373); nothing
    // here ever did, so a format whose sections hold resources - a CBZ holds a
    // blob URL per page - never gave any of them back.
    #shown = []
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
    #slot(position) {
        let slot = this.#slots[position]
        if (slot) return slot
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
        slot = { element, iframe }
        this.#slots[position] = slot
        return slot
    }
    // Navigates one slot and resolves once its document is up. Resolves null if
    // a newer turn took the slots while this one was loading; every caller
    // checks the generation immediately afterwards.
    async #loadFrame(position, side, { index, src }, generation) {
        const { element, iframe } = this.#slot(position)
        if (!src) {
            element.style.display = 'none'
            return { blank: true, element, iframe }
        }
        return new Promise(resolve => {
            const onload = () => {
                iframe.removeEventListener('load', onload)
                if (generation !== this.#generation) return resolve(null)
                const doc = iframe.contentDocument
                doc.position = side
                this.dispatchEvent(new CustomEvent('load', { detail: { doc, index } }))
                const { width, height } = getViewport(doc, this.defaultViewport)
                resolve({
                    element, iframe, index,
                    width: parseFloat(width),
                    height: parseFloat(height),
                })
            }
            iframe.addEventListener('load', onload)
            iframe.src = src
        })
    }
    // Gives back sections that have been off screen for a while.
    //
    // A section that does not define `unload` - a PDF page, held by the bounded
    // cache in pdf.js - keeps whatever policy it set for itself. One that does
    // is unloaded, but not the instant it leaves: a CBZ page costs a decode out
    // of the archive to bring back, and turning one page forward and one back
    // should not pay for two of them. It is released once
    // [unloadKeepWindow] other pages have been visited since.
    #unloadDeparted(shown) {
        for (const index of shown) {
            const seen = this.#shown.indexOf(index)
            if (seen !== -1) this.#shown.splice(seen, 1)
            this.#shown.push(index)
        }
        while (this.#shown.length > unloadKeepWindow) {
            const index = this.#shown.shift()
            if (!shown.includes(index)) this.book?.sections?.[index]?.unload?.()
        }
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
    async #showSpread({ left, right, center, side }) {
        const generation = ++this.#generation
        if (center) {
            const frame = await this.#loadFrame(0, 'center', center, generation)
            if (generation !== this.#generation) return
            this.#slot(1).element.style.display = 'none'
            this.#left = null
            this.#right = null
            this.#center = frame
            this.#side = 'center'
            this.#render()
            this.#unloadDeparted([center.index])
        } else {
            const first = await this.#loadFrame(0, 'left', left, generation)
            if (generation !== this.#generation) return
            const second = await this.#loadFrame(1, 'right', right, generation)
            if (generation !== this.#generation) return
            this.#center = null
            this.#left = first
            this.#right = second
            this.#side = first.blank ? 'right'
                : second.blank ? 'left' : side
            this.#render()
            this.#unloadDeparted(
                [left.src ? left.index : null, right.src ? right.index : null]
                    .filter(index => index != null))
        }
    }
    #goLeft() {
        if (this.#center || this.#left?.blank) return
        if (this.#portrait && this.#left?.element?.style?.display === 'none') {
            this.#right.element.style.display = 'none'
            this.#left.element.style.display = 'block'
            this.#side = 'left'
            return true
        }
    }
    #goRight() {
        if (this.#center || this.#right?.blank) return
        if (this.#portrait && this.#right?.element?.style?.display === 'none') {
            this.#left.element.style.display = 'none'
            this.#right.element.style.display = 'block'
            this.#side = 'right'
            return true
        }
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
        // `this.side` was never a property - the field is private - so this
        // read was always undefined and every spread reported its right-hand
        // page. On a phone, where the two halves of a spread are shown one at
        // a time, that is the page number being off by one for the whole of
        // the left-hand page.
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
            this.#render(side)
            return
        }
        this.#index = index
        const spread = this.#spreads[index]
        if (spread.center) {
            const index = this.book.sections.indexOf(spread.center)
            const src = await spread.center?.load?.()
            await this.#showSpread({ center: { index, src } })
        } else {
            const indexL = this.book.sections.indexOf(spread.left)
            const indexR = this.book.sections.indexOf(spread.right)
            const srcL = await spread.left?.load?.()
            const srcR = await spread.right?.load?.()
            const left = { index: indexL, src: srcL }
            const right = { index: indexR, src: srcR }
            await this.#showSpread({ left, right, side })
        }
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
        const s = this.rtl ? this.#goLeft() : this.#goRight()
        if (s) this.#reportLocation('page')
        else return this.goToSpread(this.#index + 1, this.rtl ? 'right' : 'left', 'page')
    }
    async prev() {
        const s = this.rtl ? this.#goRight() : this.#goLeft()
        if (s) this.#reportLocation('page')
        else return this.goToSpread(this.#index - 1, this.rtl ? 'left' : 'right', 'page')
    }
    getContents() {
        // Only what is actually on screen. The slots persist now, so a hidden
        // one still holds the document it last showed, and handing that back
        // would make `getContents()[0]` the page the reader has left.
        return [this.#center, this.#left, this.#right]
            .filter(frame => frame && !frame.blank && frame.iframe.contentDocument)
            .map(({ iframe, index }) => ({
                doc: iframe.contentDocument,
                index,
                // TODO: overlayer
            }))
    }
    destroy() {
        this.#observer.unobserve(this)
        for (const index of this.#shown)
            this.book?.sections?.[index]?.unload?.()
        this.#shown = []
        this.#slots = []
        this.#root.replaceChildren()
    }
}

customElements.define('foliate-fxl', FixedLayout)
