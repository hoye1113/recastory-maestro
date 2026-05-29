// tools/puppeteer-launch.js
// 打开浏览器、启动 auto-play、等待播放完成
// 用于截图验证和 auto-play 模式（录制已移至 capture-chrome.js）
// Usage: node puppeteer-launch.js <storyboard-url> [--headed] [--screenshot-steps] [--screenshot-only] [--screenshot-dir=<dir>]

const puppeteer = require('puppeteer')
const path = require('path')
const fs = require('fs')

// Detect available browser: Chrome → Edge
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
      '--disable-infobars',
      '--no-first-run',
      '--disable-prompt-on-repost',
      '--disable-background-timer-throttling',
      '--disable-gpu',
      '--disable-software-rasterizer',
      '--disable-dev-shm-usage',
      '--no-zygote',
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

    // Maximize browser window via CDP
    try {
      const session = await page.target().createCDPSession()
      const { windowId } = await session.send('Browser.getWindowForTarget')
      await session.send('Browser.setWindowBounds', {
        windowId,
        bounds: { windowState: 'maximized' }
      })
    } catch (e) {
      // Ignore on headless
    }

    console.log(`Opening: ${url}`)
    await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 })
    await page.waitForSelector('#root', { timeout: 10000 })

    // Resolve screenshot directory
    const outDir = screenshotDir || path.join(process.cwd(), 'storyboard', 'screenshots')

    // --- Screenshot-only mode ---
    if (screenshotOnly) {
      fs.mkdirSync(outDir, { recursive: true })
      console.log('Screenshot-only mode: capturing steps...')

      await page.keyboard.press('Space')
      await new Promise(r => setTimeout(r, 500))

      let stepIndex = 0
      const MAX_STEPS = 100
      let prevProgress = null

      for (let i = 0; i < MAX_STEPS; i++) {
        await new Promise(r => setTimeout(r, 500))
        const stepFile = path.join(outDir, `step-${String(stepIndex).padStart(2, '0')}.png`)
        await page.screenshot({ path: stepFile, fullPage: false })
        console.log(`[SCREENSHOT] ${stepFile}`)
        stepIndex++

        const progress = await page.evaluate(() => {
          const bar = document.querySelector('.cd-progress-bar')
          return bar ? bar.style.width : null
        }).catch(() => null)

        if (progress === '100%' && prevProgress === '100%') break
        prevProgress = progress

        await page.keyboard.press('Space')
      }

      console.log(`Screenshot capture complete: ${stepIndex} steps`)
      return
    }

    // --- Auto-play mode ---
    if (screenshotSteps) {
      fs.mkdirSync(outDir, { recursive: true })
    }

    console.log('Pressing SPACE to start auto-play...')
    await page.keyboard.press('Space')

    if (screenshotSteps) {
      await new Promise(r => setTimeout(r, 500))
      const stepFile = path.join(outDir, 'step-00.png')
      await page.screenshot({ path: stepFile, fullPage: false })
      console.log(`[SCREENSHOT] ${stepFile}`)
    }

    console.log('Waiting for auto-play to complete...')

    let stableCount = 0
    let screenshotIndex = 1
    const MAX_WAIT_MS = 10 * 60 * 1000
    const startTime = Date.now()

    while (stableCount < 10 && Date.now() - startTime < MAX_WAIT_MS) {
      await new Promise(r => setTimeout(r, 1000))

      const currentStep = await page.evaluate(() => {
        const bar = document.querySelector('.cd-progress-bar')
        return bar ? bar.style.width : null
      }).catch(() => null)

      if (currentStep === '100%') {
        stableCount++
      } else {
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
