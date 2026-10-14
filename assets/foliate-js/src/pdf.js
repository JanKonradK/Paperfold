// Page frames use blob: URLs, which cannot resolve a root-relative stylesheet.
const PDFJS_BASE = new URL('/foliate-js/src/vendor/pdfjs/', location.href).href

const renderPage = async (pdfjs, pdf, page, getImageBlob = false) => {
    const natural = page.getViewport({ scale: 1 })
    const fitScale = Math.min(innerWidth / natural.width, innerHeight / natural.height)
    // Bound the bitmap allocation on large monitors and high-density phones.
    const scale = Math.min(devicePixelRatio * fitScale,
        Math.sqrt(16_000_000 / (natural.width * natural.height)))
    const viewport = page.getViewport({ scale })
    const canvas = document.createElement('canvas')
    canvas.height = Math.ceil(viewport.height)
    canvas.width = Math.ceil(viewport.width)
    await page.render({ canvas, viewport }).promise
    const blob = await new Promise((resolve, reject) => canvas.toBlob(value =>
        value ? resolve(value) : reject(new Error('Could not render PDF page'))))
    if (getImageBlob) return blob

    const container = document.createElement('div')
    container.classList.add('textLayer')
    await new pdfjs.TextLayer({
        textContentSource: await page.getTextContent(), container, viewport,
    }).render()

    const div = document.createElement('div')
    div.classList.add('annotationLayer')
    // Foliate handles links after these elements are copied into the page frame.
    // Convert named page actions to the same destinations as normal PDF links.
    const pageIndex = page.pageNumber - 1
    const namedPages = {
        FirstPage: 0, LastPage: pdf.numPages - 1,
        PrevPage: Math.max(0, pageIndex - 1),
        NextPage: Math.min(pdf.numPages - 1, pageIndex + 1),
    }
    const annotations = (await page.getAnnotations()).map(annotation =>
        Object.hasOwn(namedPages, annotation.action)
            ? { ...annotation, action: null,
                dest: [namedPages[annotation.action], { name: 'Fit' }] }
            : annotation)
    await new pdfjs.AnnotationLayer({
        page, viewport: viewport.clone({ dontFlip: true }), div,
        linkService: {
            getDestinationHash: dest => JSON.stringify(dest),
            getAnchorUrl: () => JSON.stringify([pageIndex, { name: 'Fit' }]),
            addLinkAttributes: (link, url) => {
                link.href = url
                link.rel = 'noopener noreferrer'
            },
        },
    }).render({
        annotations, imageResourcesPath: `${PDFJS_BASE}images/`,
        renderForms: false, enableScripting: false,
    })
    // Older WebViews lack CSS round(); the page frames need only fixed dimensions.
    for (const layer of [container, div]) {
        layer.style.width = `${viewport.rawDims.pageWidth * scale}px`
        layer.style.height = `${viewport.rawDims.pageHeight * scale}px`
    }

    const src = URL.createObjectURL(blob)
    return URL.createObjectURL(new Blob([`
        <!DOCTYPE html>
        <meta charset="utf-8">
        <meta name="viewport" content="width=${canvas.width},height=${canvas.height}">
        <link rel="stylesheet" href="${PDFJS_BASE}pdf_viewer.css">
        <style>
        :root {
            --scale-factor: ${scale};
            --total-scale-factor: ${scale};
            --scale-round-x: 1px;
            --scale-round-y: 1px;
        }
        html, body { margin: 0; padding: 0; }
        body > img { display: block; }
        /* Basic text/link layout for WebViews without CSS nesting. */
        .textLayer {
            position: absolute; top: 0; left: 0; overflow: hidden;
            line-height: 1; transform-origin: 0 0; z-index: 2;
            -webkit-text-size-adjust: none;
        }
        .textLayer span, .textLayer br {
            color: transparent; position: absolute; white-space: pre;
            cursor: text; transform-origin: 0 0;
            -webkit-user-select: text; user-select: text;
        }
        .textLayer > :not(.markedContent), .textLayer .markedContent span:not(.markedContent) {
            font-size: calc(${scale} * var(--min-font-size, 1) * var(--font-height, 0px));
            transform: rotate(var(--rotate, 0deg)) scaleX(var(--scale-x, 1))
                scale(calc(1 / var(--min-font-size, 1)));
        }
        .textLayer .markedContent { display: contents; }
        .textLayer ::selection { background: rgba(0, 0, 255, .25); color: transparent; }
        .annotationLayer {
            position: absolute; top: 0; left: 0; pointer-events: none;
            transform-origin: 0 0; z-index: 3;
        }
        .annotationLayer section {
            position: absolute; pointer-events: auto; box-sizing: border-box;
            transform-origin: 0 0;
        }
        .annotationLayer .linkAnnotation > a {
            position: absolute; top: 0; left: 0; width: 100%; height: 100%;
        }
        </style>
        <img src="${src}">
        ${container.outerHTML}
        ${div.outerHTML}
    `], { type: 'text/html' }))
}

const makeTOCItem = item => ({
    label: item.title,
    href: JSON.stringify(item.dest),
    subitems: item.items.length ? item.items.map(makeTOCItem) : null,
})

export const makePDF = async file => {
    // Load PDF.js only for PDF books. The EPUB reader keeps its smaller bundle.
    const pdfjs = await import(/* webpackIgnore: true */ '/foliate-js/src/vendor/pdfjs/pdf.mjs')
    pdfjs.GlobalWorkerOptions.workerSrc = `${PDFJS_BASE}pdf.worker.mjs`
    const data = new Uint8Array(await file.arrayBuffer())
    const pdf = await pdfjs.getDocument({
        data,
        cMapUrl: `${PDFJS_BASE}cmaps/`, cMapPacked: true,
        standardFontDataUrl: `${PDFJS_BASE}standard_fonts/`,
        wasmUrl: `${PDFJS_BASE}wasm/`, iccUrl: `${PDFJS_BASE}iccs/`,
    }).promise

    const book = { rendition: { layout: 'pre-paginated' } }
    const info = (await pdf.getMetadata())?.info
    book.metadata = { title: info?.Title, author: info?.Author }
    book.toc = (await pdf.getOutline())?.map(makeTOCItem)

    const cache = new Map()
    book.sections = Array.from({ length: pdf.numPages }, (_, i) => ({
        id: i,
        load: async () => {
            if (!cache.has(i)) {
                const loading = pdf.getPage(i + 1)
                    .then(page => renderPage(pdfjs, pdf, page))
                    .catch(error => { cache.delete(i); throw error })
                cache.set(i, loading)
            }
            return cache.get(i)
        },
        size: 1000,
    }))
    book.sections[0].pageSpread = 'right'
    book.isExternal = uri => /^\w+:/i.test(uri)
    const resolveIndex = async href => {
        const parsed = JSON.parse(href)
        const dest = typeof parsed === 'string'
            ? await pdf.getDestination(parsed) : parsed
        if (dest?.[0] == null) return 0
        return typeof dest[0] === 'number' ? dest[0] : pdf.getPageIndex(dest[0])
    }
    book.resolveHref = async href => ({ index: await resolveIndex(href) })
    book.splitTOCHref = async href => [await resolveIndex(href), null]
    book.getTOCFragment = doc => doc.documentElement
    book.getCover = async () => renderPage(pdfjs, pdf, await pdf.getPage(1), true)
    return book
}
