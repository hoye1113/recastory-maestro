// tools/puppeteer-launch.js
// 自动打开浏览器、启动 auto-play、等待播放完成
// Usage: node puppeteer-launch.js <storyboard-url> [--headed]

const puppeteer = require('puppeteer')

async function launch(url, headed = false) {
  const browser = await puppeteer.launch({
    headless: headed ? false : 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  })

  try {
    const page = await browser.newPage()
    await page.setViewport({ width: 1920, height: 1080 })

    console.log(`Opening: ${url}`)
    await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 })

    // Wait for React to render
    await page.waitForSelector('#root', { timeout: 10000 })

    // Check if auto mode overlay is showing
    const hasOverlay = await page.evaluate(() => {
      return document.body.textContent.includes('Press SPACE to start')
    })

    if (!hasOverlay) {
      console.log('WARN: Auto mode overlay not found, page may not support ?auto=1')
    }

    // Press SPACE to start
    console.log('Pressing SPACE to start auto-play...')
    await page.keyboard.press('Space')

    // Wait for auto-play to complete
    // Strategy: poll for the page to signal completion
    // The app plays audio per step and advances. When the last step's audio ends,
    // the app stays on the final step. We detect this by watching for stability.
    console.log('Waiting for auto-play to complete...')

    let stableCount = 0
    const MAX_WAIT_MS = 10 * 60 * 1000 // 10 minutes
    const startTime = Date.now()

    while (stableCount < 10 && Date.now() - startTime < MAX_WAIT_MS) {
      await new Promise(r => setTimeout(r, 1000))

      // Try to detect current step from the page
      const currentStep = await page.evaluate(() => {
        // Look for progress bar or step indicator
        const bar = document.querySelector('.cd-progress-bar')
        if (bar) {
          const width = bar.style.width
          return width // e.g., "100%" for last step
        }
        return null
      }).catch((err) => {
        console.warn('Poll evaluate failed:', err.message)
        return null
      })

      if (currentStep === '100%') {
        stableCount++
      } else {
        stableCount = 0
      }
    }

    if (stableCount < 10) {
      throw new Error('Auto-play timed out after 10 minutes')
    }

    console.log('Auto-play complete')
  } finally {
    await browser.close()
    console.log('Browser closed')
  }
}

const args = process.argv.slice(2)
const url = args[0]
const headed = args.includes('--headed')

if (!url) {
  console.error('Usage: node puppeteer-launch.js <storyboard-url> [--headed]')
  process.exit(1)
}

launch(url, headed).catch(err => {
  console.error('Failed:', err.message)
  process.exit(1)
})
