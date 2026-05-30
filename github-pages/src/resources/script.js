/**
 * Landing page bootstrap. Expects content.json next to index.html.
 */

const CAROUSEL_SELECTOR = '[data-landing-carousel]';
const SLIDE_TRANSITION_MS = 420;
const SWIPE_THRESHOLD_PX = 45;

// Fallback if an icon isn't specified or falls through
const ICON_FALLBACK = '<i class="fa-solid fa-circle-question"></i>';

function escapeHtml(text) {
    return String(text)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

async function initLandingPage() {
    const slideFrameEl = document.getElementById('slide-frame');
    const dotsEl = document.getElementById('nav-dots');
    const btnPrev = document.getElementById('slide-prev');
    const btnNext = document.getElementById('slide-next');
    const titleEl = document.getElementById('slide-title');
    const descEl = document.getElementById('slide-desc');
    const featureListEl = document.getElementById('feature-list');
    const featuresEyebrowEl = document.getElementById('features-eyebrow');
    const shieldRowEl = document.getElementById('shield-row');
    const siteTaglineEl = document.getElementById('site-tagline');

    if (!slideFrameEl || !dotsEl || !btnPrev || !btnNext || !titleEl || !descEl) {
        return;
    }

    let slides = [];
    let currentIndex = 0;
    let transitionLock = false;

    function setCarouselVisible(visible) {
        document.querySelectorAll(CAROUSEL_SELECTOR).forEach(el => {
            el.hidden = !visible;
        });
    }

    function setLeftColumnVisible(visible) {
        const featuresSection = featureListEl?.closest('.info-features');
        const downloadBlock = document.querySelector('.info-actions');
        if (featuresSection) featuresSection.hidden = !visible;
        if (downloadBlock) downloadBlock.hidden = !visible;
    }

    function getSlideElement(index) {
        return slideFrameEl.querySelector(`.slide[data-idx="${index}"]`);
    }

    function updateSlideCopy(index) {
        titleEl.textContent = slides[index].title;
        descEl.textContent = slides[index].description;
    }

    function updateDotStates() {
        dotsEl.querySelectorAll('.dot').forEach((dot, i) => {
            dot.classList.toggle('active', i === currentIndex);
            dot.setAttribute('aria-selected', String(i === currentIndex));
        });
    }

    function buildShields(shields) {
        if (!shieldRowEl) return;
        if (!shields.length) {
            shieldRowEl.innerHTML = '';
            shieldRowEl.hidden = true;
            return;
        }
        shieldRowEl.hidden = false;
        shieldRowEl.innerHTML = shields.map(s => {
            const img = `<img class="shield-img" src="${escapeHtml(s.src)}" alt="${escapeHtml(s.alt || '')}" loading="lazy" decoding="async" height="22">`;
            if (s.href) {
                return `<a class="shield-link" href="${escapeHtml(s.href)}" target="_blank" rel="noopener noreferrer">${img}</a>`;
            }
            return `<span class="shield-wrap">${img}</span>`;
        }).join('');
    }

    // UPDATED: Dynamically generates Font Awesome element markup from your string name
    function buildFeatures(content) {
        if (!featureListEl) return;
        const features = content.features || [];

        if (featuresEyebrowEl && content.featuresEyebrow) {
            featuresEyebrowEl.textContent = content.featuresEyebrow;
        }

        if (!features.length) {
            featureListEl.innerHTML = '';
            setLeftColumnVisible(false);
            return;
        }
        setLeftColumnVisible(true);

        featureListEl.innerHTML = features.map(f => {
            // Safe fallback rule if icon name is completely empty
            const iconHtml = f.icon ? `<i class="${escapeHtml(f.icon)}"></i>` : ICON_FALLBACK;
            
            return `<li>
                <span class="feat-icon">${iconHtml}</span>
                <div>
                    <strong>${escapeHtml(f.title || '')}</strong>
                    <p>${escapeHtml(f.description || '')}</p>
                </div>
            </li>`;
        }).join('');
    }

    function buildSlides() {
        slideFrameEl.innerHTML = slides.map((s, i) => {
            const body = s.image
                ? `<img src="${escapeHtml(s.image)}" alt="${escapeHtml(s.title)}" loading="${i === 0 ? 'eager' : 'lazy'}">`
                : '<div class="slide-placeholder">Screenshot coming soon</div>';
            return `<div class="slide" data-idx="${i}" data-state="idle">${body}</div>`;
        }).join('');
    }

    function buildDots() {
        dotsEl.innerHTML = slides.map((_, i) =>
            `<button type="button" class="dot" role="tab"
                aria-label="Slide ${i + 1}" data-idx="${i}"></button>`
        ).join('');
        dotsEl.querySelectorAll('.dot').forEach(dot =>
            dot.addEventListener('click', () => goToSlide(+dot.dataset.idx))
        );
    }

    function goToSlide(nextIndex) {
        if (!slides.length) return;
        nextIndex = ((nextIndex % slides.length) + slides.length) % slides.length;
        if (nextIndex === currentIndex || transitionLock) return;
        transitionLock = true;

        const forward = nextIndex > currentIndex || (currentIndex === slides.length - 1 && nextIndex === 0);

        const outgoing = getSlideElement(currentIndex);
        const incoming = getSlideElement(nextIndex);

        incoming.style.transition = 'none';
        incoming.dataset.state = forward ? 'enter' : 'enter-back';
        incoming.getBoundingClientRect();
        incoming.style.transition = '';

        outgoing.dataset.state = forward ? 'exit' : 'exit-back';
        incoming.dataset.state = 'active';

        currentIndex = nextIndex;
        updateSlideCopy(currentIndex);
        updateDotStates();

        window.setTimeout(() => {
            transitionLock = false;
            slideFrameEl.querySelectorAll('.slide').forEach(card => {
                if (card.dataset.state !== 'active') card.dataset.state = 'idle';
            });
        }, SLIDE_TRANSITION_MS);
    }

    btnPrev.addEventListener('click', () => goToSlide(currentIndex - 1));
    btnNext.addEventListener('click', () => goToSlide(currentIndex + 1));

    document.addEventListener('keydown', e => {
        if (e.key === 'ArrowLeft') goToSlide(currentIndex - 1);
        if (e.key === 'ArrowRight') goToSlide(currentIndex + 1);
    });

    let touchStartX = 0;
    slideFrameEl.addEventListener('touchstart', e => {
        touchStartX = e.touches[0].clientX;
    }, { passive: true });
    slideFrameEl.addEventListener('touchend', e => {
        const dx = e.changedTouches[0].clientX - touchStartX;
        if (dx < -SWIPE_THRESHOLD_PX) goToSlide(currentIndex + 1);
        else if (dx > SWIPE_THRESHOLD_PX) goToSlide(currentIndex - 1);
    });

    let content = {};
    try {
        const response = await fetch('content.json');
        if (!response.ok) throw new Error('content.json not ok');
        content = await response.json();
    } catch {
        content = {};
    }

    slides = content.slides || [];

    if (siteTaglineEl && content.tagline) {
        siteTaglineEl.textContent = content.tagline;
    }

    buildShields(content.shields || []);
    buildFeatures(content);

    if (!slides.length) {
        setCarouselVisible(false);
        return;
    }

    setCarouselVisible(true);
    buildSlides();
    buildDots();
    getSlideElement(0).dataset.state = 'active';
    updateSlideCopy(0);
    updateDotStates();
}

initLandingPage();