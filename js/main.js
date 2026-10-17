// Pure browser JavaScript: no build step, framework, or host-specific APIs.
const toggle = document.querySelector('.menu-toggle');
const nav = document.querySelector('#main-nav');
if (toggle && nav) {
  toggle.addEventListener('click', () => {
    const expanded = toggle.getAttribute('aria-expanded') === 'true';
    toggle.setAttribute('aria-expanded', String(!expanded));
    nav.classList.toggle('open', !expanded);
  });
  nav.addEventListener('click', event => {
    if (event.target.closest('a')) {
      nav.classList.remove('open');
      toggle.setAttribute('aria-expanded', 'false');
    }
  });
}
const video = document.querySelector('.hero-video');
if (video && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
  video.pause();
  video.removeAttribute('autoplay');
}
