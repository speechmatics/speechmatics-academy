// Vercel supplies this endpoint after Web Analytics is enabled and deployed.
// Local development does not load the tracker or send page views.
const hostname = window.location.hostname;
const isLocal = ['localhost', '127.0.0.1', '[::1]'].includes(hostname)
  || hostname.endsWith('.localhost');

if (!isLocal) {
  window.va = window.va || function () {
    (window.vaq = window.vaq || []).push(arguments);
  };

  // Only page views: never attach consultation content, filenames, or API keys.
  window.va('beforeSend', (event) => {
    if (event.type !== 'pageview') return null;
    const url = new URL(event.url);
    url.search = '';
    url.hash = '';
    return { ...event, url: url.href };
  });

  const script = document.createElement('script');
  script.defer = true;
  script.src = '/_vercel/insights/script.js';
  document.head.appendChild(script);
}
