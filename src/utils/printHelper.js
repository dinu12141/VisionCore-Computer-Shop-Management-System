/**
 * Utility to print HTML content using a hidden iframe.
 * This keeps the user on the current page.
 */
export const printHTML = (html) => {
  // Create a hidden iframe
  const frameId = 'print-iframe'
  let frame = document.getElementById(frameId)

  if (!frame) {
    frame = document.createElement('iframe')
    frame.id = frameId
    frame.style.position = 'absolute'
    frame.style.width = '0px'
    frame.style.height = '0px'
    frame.style.border = 'none'
    frame.style.top = '-1000px'
    document.body.appendChild(frame)
  }

  const frameDoc = frame.contentWindow.document
  frameDoc.open()
  frameDoc.write(html)
  frameDoc.close()

  // Wait for images and resources to load in the frame
  frame.contentWindow.focus()

  // Cross-browser print trigger
  setTimeout(() => {
    frame.contentWindow.print()
  }, 500)
}
