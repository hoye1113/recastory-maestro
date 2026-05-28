// tools/puppeteer-launch.js
// 自动打开浏览器、启动 auto-play、等待播放完成
// Usage: node puppeteer-launch.js <storyboard-url> [--headed] [--screenshot-steps] [--screenshot-only] [--screenshot-dir=<dir>]

const puppeteer = require('puppeteer')
const path = require('path')
const fs = require('fs')

// Detect available browser: Chrome → Edge (Chromium-based) → default
function detectBrowserPath() {
  const candidates = [
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  ]
  for (const p of candidates) {
    if (fs.existsSync(p)) return p
  }
  return undefined
}

async function launch(url, headed = false, options = {}) {
  const { screenshotSteps = false, screenshotOnly = false, screenshotDir = null } = options

  const launchOptions = {
    headless: headed ? false : 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--start-fullscreen',
      '--kiosk',
      '--disable-infobars',
      '--no-first-run',
    ],
    defaultViewport: null,
  }
  const browserPath = process.env.PUPPETEER_EXECUTABLE_PATH || detectBrowserPath()
  if (browserPath) {
    launchOptions.executablePath = browserPath
    console.log(`Using browser: ${browserPath}`)
  }

  const browser = await puppeteer.launch(launchOptions)

  try {
    const page = await browser.newPage()

    // Force window to cover entire screen via CDP
    try {
      const session = await page.target().createCDPSession()
      const { windowId } = await session.send('Browser.getWindowForTarget')
      await session.send('Browser.setWindowBounds', {
        windowId,
        bounds: { left: 0, top: 0, width: 1920, height: 1080, windowState: 'fullscreen' }
      })
      console.log('Browser set to fullscreen via CDP')
    } catch (e) {
      console.warn('CDP fullscreen failed, trying alternative:', e.message)
      // Fallback: use page.evaluate to request fullscreen
      await page.evaluate(() => {
        document.documentElement.requestFullscreen?.()
      })
    }

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

    // Resolve screenshot directory (default: workspace/storyboard/screenshots)
    const outDir = screenshotDir || path.join(process.cwd(), 'storyboard', 'screenshots')

    // --- Screenshot-only mode: capture each step without auto-play ---
    if (screenshotOnly) {
      fs.mkdirSync(outDir, { recursive: true })
      console.log('Screenshot-only mode: capturing steps...')

      // Press SPACE to dismiss overlay
      await page.keyboard.press('Space')
      await new Promise(r => setTimeout(r, 500))

      let stepIndex = 0
      const MAX_STEPS = 100  // safety limit
      let prevProgress = null

      for (let i = 0; i < MAX_STEPS; i++) {
        await new Promise(r => setTimeout(r, 500))
        const stepFile = path.join(outDir, `step-${String(stepIndex).padStart(2, '0')}.png`)
        await page.screenshot({ path: stepFile, fullPage: false })
        console.log(`[SCREENSHOT] ${stepFile}`)
        stepIndex++

        // Check if we're at the end (progress bar at 100%)
        const progress = await page.evaluate(() => {
          const bar = document.querySelector('.cd-progress-bar')
          return bar ? bar.style.width : null
        }).catch(() => null)

        if (progress === '100%' && prevProgress === '100%') {
          break  // stable at end
        }
        prevProgress = progress

        await page.keyboard.press('Space')
      }

      console.log(`Screenshot capture complete: ${stepIndex} steps`)
      await browser.close()
      console.log('Browser closed')
      return
    }

    // --- Normal auto-play mode (with optional per-step screenshots) ---
    if (screenshotSteps) {
      fs.mkdirSync(outDir, { recursive: true })
    }

    // Press SPACE to start
    console.log('Pressing SPACE to start auto-play...')
    await page.keyboard.press('Space')

    // Capture first step screenshot if enabled
    if (screenshotSteps) {
      await new Promise(r => setTimeout(r, 500))
      const stepFile = path.join(outDir, 'step-00.png')
      await page.screenshot({ path: stepFile, fullPage: false })
      console.log(`[SCREENSHOT] ${stepFile}`)
    }

    // Wait for auto-play to complete
    // Strategy: poll for the page to signal completion
    // The app plays audio per step and advances. When the last step's audio ends,
    // the app stays on the final step. We detect this by watching for stability.
    console.log('Waiting for auto-play to complete...')

    let stableCount = 0
    let screenshotIndex = 1
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
        // Capture per-step screenshot when step changes
        if (screenshotSteps && currentStep) {
          const stepFile = path.join(outDir, `step-${String(screenshotIndex).padStart(2, '0')}.png`)
          await page.screenshot({ path: stepFile, fullPage: false })
          console.log(`[SCREENSHOT] ${stepFile}`)
          screenshotIndex++
        }
        stableCount = 0
      }
    }

    if (stableCount < 10) {
      throw new Error('Auto-play timed out after 10 minutes')
    }

    // Capture final step screenshot
    if (screenshotSteps) {
      const stepFile = path.join(outDir, `step-${String(screenshotIndex).padStart(2, '0')}.png`)
      await page.screenshot({ path: stepFile, fullPage: false })
      console.log(`[SCREENSHOT] ${stepFile}`)
    }

    console.log('Auto-play complete')
  } finally {
    await browser.close()
    console.log('Browser closed')
  }
}

const args = process.argv.slice(2)
const url = args.find(a => !a.startsWith('--'))
const headed = args.includes('--headed')
const screenshotSteps = args.includes('--screenshot-steps')
const screenshotOnly = args.includes('--screenshot-only')
const screenshotDir = args.find(a => a.startsWith('--screenshot-dir='))?.split('=')[1] || null

if (!url) {
  console.error('Usage: node puppeteer-launch.js <storyboard-url> [--headed] [--screenshot-steps] [--screenshot-only] [--screenshot-dir=<dir>]')
  process.exit(1)
}

launch(url, headed, { screenshotSteps, screenshotOnly, screenshotDir }).catch(err => {
  console.error('Failed:', err.message)
  process.exit(1)
})
