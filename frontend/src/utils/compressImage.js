// Shrinks a photo in the browser before upload: scaled to fit maxSide and
// re-encoded, so a 6 MB phone photo usually becomes 300-600 KB. Uses a
// <canvas>, which also drops the photo's EXIF data (location, camera).
//
// Output type: JPEG stays JPEG; PNG and WebP become WebP where the browser
// can encode it (keeps transparency), else they keep their own type.
// If the result isn't smaller and needed no resizing, the original is kept.

function loadImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload = () => {
      URL.revokeObjectURL(url)
      resolve(img)
    }
    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('This file could not be read as an image'))
    }
    img.src = url // browsers apply the EXIF rotation when drawing
  })
}

function toBlob(canvas, type, quality) {
  return new Promise((resolve) => canvas.toBlob(resolve, type, quality))
}

function renamed(name, type) {
  const ext = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' }[type]
  return name.replace(/\.[^.]+$/, '') + '.' + ext
}

// Resolves with { file, width, height, originalSize, size }
export async function compressImage(
  file,
  { maxSide = 1920, quality = 0.82, maxBytes = Infinity } = {},
) {
  const img = await loadImage(file)
  const scale = Math.min(1, maxSide / Math.max(img.naturalWidth, img.naturalHeight))
  const width = Math.round(img.naturalWidth * scale)
  const height = Math.round(img.naturalHeight * scale)

  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  canvas.getContext('2d').drawImage(img, 0, 0, width, height)

  let type = file.type === 'image/jpeg' ? 'image/jpeg' : 'image/webp'
  let blob = await toBlob(canvas, type, quality)
  // toBlob falls back to PNG when the browser can't encode WebP
  if (!blob || blob.type !== type) {
    type = file.type
    blob = await toBlob(canvas, type, quality)
  }
  // Still too big for the server: lower the quality a few times
  for (
    let q = quality - 0.15;
    blob && blob.size > maxBytes && q > 0.4 && type !== 'image/png';
    q -= 0.15
  ) {
    blob = await toBlob(canvas, type, q)
  }

  if (!blob || (scale === 1 && blob.size >= file.size && file.size <= maxBytes)) {
    return { file, width, height, originalSize: file.size, size: file.size }
  }
  return {
    file: new File([blob], renamed(file.name, type), { type }),
    width,
    height,
    originalSize: file.size,
    size: blob.size,
  }
}
