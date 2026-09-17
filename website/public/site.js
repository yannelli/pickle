(() => {
  const device = document.querySelector('.device');
  const message = document.querySelector('#demo-message');
  const effect = document.querySelector('#pet-effect');
  const pet = document.querySelector('#pet-button');
  const napLabel = document.querySelector('#nap-label');
  const happiness = document.querySelector('#happiness-fill');
  let sleeping = false;
  let affection = 72;
  let resetAnimation;
  let animationFrame;

  function care(action) {
    clearTimeout(resetAnimation);
    cancelAnimationFrame(animationFrame);
    delete device.dataset.action;
    if (action === 'nap' || sleeping) {
      sleeping = !sleeping;
      device.dataset.sleeping = String(sleeping);
      message.textContent = sleeping ? 'Dreaming of you. And snacks.' : 'Oh good, you’re here!';
      effect.textContent = sleeping ? 'z z z' : '♡';
      napLabel.textContent = sleeping ? 'Wake' : 'Nap';
      pet.setAttribute('aria-label', sleeping ? 'Wake Dill' : 'Pet Dill');
      return;
    }
    affection = Math.min(100, affection + 7);
    happiness.style.width = `${affection}%`;
    message.textContent = action === 'feed' ? 'Compliments to the chef. More brine?' : 'You’re kind of my favorite human.';
    effect.textContent = action === 'feed' ? '✦' : '♡';
    animationFrame = requestAnimationFrame(() => {
      animationFrame = requestAnimationFrame(() => {
        device.dataset.action = action;
        resetAnimation = setTimeout(() => delete device.dataset.action, 850);
      });
    });
  }

  const motionOk = window.matchMedia('(prefers-reduced-motion: no-preference)').matches;
  if (motionOk && 'IntersectionObserver' in window) {
    const targets = document.querySelectorAll('.section-heading, .center-heading, .step, .pal, .play-copy, .game-list article, .life-inner > div, .faq-section > div, .final-card');
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        entry.target.dataset.reveal = 'in';
        observer.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: .15 });
    targets.forEach(target => {
      const siblings = [...target.parentElement.children].filter(child => child.matches('.step, .pal, article, div'));
      target.style.transitionDelay = `${Math.min(siblings.indexOf(target), 6) * 70}ms`;
      target.dataset.reveal = '';
      observer.observe(target);
    });
  }

  pet.disabled = false;
  pet.addEventListener('click', () => care('love'));
  document.querySelectorAll('[data-care]').forEach(button => {
    button.disabled = false;
    button.addEventListener('click', () => care(button.dataset.care));
  });
})();
