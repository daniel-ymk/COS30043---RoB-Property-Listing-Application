// ?redirect= comes from the URL, so only allow paths inside this app
// ("/liked"), never another site ("//evil.com", "https://...").
export function safeRedirect(value, fallback = '/') {
  return typeof value === 'string' && value.startsWith('/') && !value.startsWith('//')
    ? value
    : fallback
}
