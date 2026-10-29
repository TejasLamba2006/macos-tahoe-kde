window.addEventListener('keydown', (e) => {
  if (e.altKey && (e.key === 'x' || e.key === 'X')) {
    document.documentElement.classList.toggle('wa-privacy-off');
  }
});
