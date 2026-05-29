#!/usr/bin/env node
// tools/capture-chrome.js
// CDP Screencast recorder — captures browser frames via Chrome DevTools Protocol.
// No system screen capture, no focus management, no DPI scaling issues.
//
// Usage: node capture-chrome.js <workspace-dir> --chapter <id> --port <port> [--output <path>]

const puppeteer = require('puppeteer')
const path = require('path')
const fs = require('fs')
const { execSync, spawn } = require('child_process')

// --- CLI Arguments ---

function parseArgs() {
  const args = process.argv.slice(2)
  const workspace = args.find(a => !a.startsWith('--'))
  const chapter = args.find((a, i) => args[i - 1] === '--chapter')
  const port = args.find((a, i) => args[i - 1] === '--port') || '5173'
  const output = args.find((a, i) => args[i - 1] === '--output')

  if (!workspace || !chapter) {
    console.error('Usage: node capture-chrome.js <workspace-dir> --chapter <id> --port <port> [--output <path>]')
    process.exit(1)
  }
  return { workspace, chapter, port: parseInt(port), output }
}

// --- Audio Duration ---

function getMp3Duration(mp3Path) {
  try {
    const out = execSync(
      `ffprobe -v error -show_entries format=duration -of csv=p=0 "${mp3Path}"`,
      { encoding: 'utf-8', timeout: 5000 }
    ).trim()
    return parseFloat(out)
  } catch (e) {
    console.warn(`Warning: Could not read duration of ${mp3Path}: ${e.message}`)
    return 5 // fallback 5 seconds
  }
}

// --- Merge Step MP3s into Chapter MP3 ---

function mergeChapterAudio(audioDir, chapterId, stepCount, outputPath) {
  const files = []
  for (let i = 1; i <= stepCount; i++) {
    const mp3Path = path.join(audioDir, chapterId, `${String(i).padStart(2, '0')}.mp3`)
    if (fs.existsSync(mp3Path)) {
      files.push(mp3Path)
    }
  }
  if (files.length === 0) {
    throw new Error(`No MP3 files found for chapter ${chapterId}`)
  }

  if (files.length === 1) {
    fs.copyFileSync(files[0], outputPath)
    return outputPath
  }

  // Write concat list
  const listFile = outputPath + '.concat.txt'
  fs.writeFileSync(listFile, files.map(f => `file '${f.replace(/\\/g, '/')}'`).join('\n'))

  execSync(
    `ffmpeg -y -f concat -safe 0 -i "${listFile}" -c:a libmp3lame -b:a 192k "${outputPath}"`,
    { stdio: 'pipe', timeout: 30000 }
  )
  fs.unlinkSync(listFile)
  return outputPath
}

// --- Frames to MP4 ---

function framesToMp4(frames, outputPath, fps = 15) {
  return new Promise((resolve, reject) => {
    if (frames.length === 0) {
      reject(new Error('No frames captured'))
      return
    }

    const ffmpeg = spawn('ffmpeg', [
      '-y',
      '-f', 'image2pipe',
      '-framerate', String(fps),
      '-i', 'pipe:0',
      '-c:v', 'libx264',
      '-preset', 'medium',
      '-crf', '18',
      '-pix_fmt', 'yuv420p',
      outputPath,
    ], { stdio: ['pipe', 'pipe', 'pipe'] })

    let stderr = ''
    ffmpeg.stderr.on('data', d => { stderr += d.toString() })

    ffmpeg.on('close', code => {
      if (code === 0) resolve()
      else reject(new Error(`FFmpeg exit ${code}: ${stderr.slice(-500)}`))
    })

    ffmpeg.on('error', reject)

    // Write all frames
    for (const frame of frames) {
      if (!ffmpeg.stdin.destroyed) {
        ffmpeg.stdin.write(frame)
      }
    }
    if (!ffmpeg.stdin.destroyed) {
      ffmpeg.stdin.end()
    }
  })
}

// --- Mux Audio into Video ---

function muxAudio(videoPath, audioPath, outputPath) {
  execSync(
    `ffmpeg -y -i "${videoPath}" -i "${audioPath}" -c:v copy -c:a aac -b:a 192k -map 0:v:0 -map 1:a:0 -shortest "${outputPath}"`,
    { stdio: 'pipe', timeout: 60000 }
  )
}

// --- Detect Browser Path ---

function detectBrowserPath() {
  const candidates = [
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  ]
  for (const p of candidates) {
    if (fs.existsSync(p)) return p
  }
  return undefined
}

// --- Load Chapter Info from audio-segments.json ---

function getChapterInfo(workspace, chapterId) {
  const segmentsFile = path.join(workspace, 'voice', 'audio-segments.json')
  if (!fs.existsSync(segmentsFile)) {
    throw new Error(`audio-segments.json not found: ${segmentsFile}`)
  }
  const segments = JSON.parse(fs.readFileSync(segmentsFile, 'utf-8'))
  const chapterSteps = segments.segments.filter(s => s.chapter === chapterId)
  if (chapterSteps.length === 0) {
    throw new Error(`No steps found for chapter ${chapterId}`)
  }
  return {
    id: chapterId,
    stepCount: chapterSteps.length,
    steps: chapterSteps.sort((a, b) => a.stepIndex - b.stepIndex),
  }
}

// --- Main ---

async function main() {
  const { workspace, chapter, port, output } = parseArgs()

  // Resolve paths
  const workspaceAbs = path.resolve(workspace)
  const audioDir = path.join(workspaceAbs, 'voice', 'public', 'audio')
  const outputDir = path.join(workspaceAbs, 'render')
  fs.mkdirSync(outputDir, { recursive: true })

  // Get chapter info
  const chapterInfo = getChapterInfo(workspaceAbs, chapter)
  console.log(`Chapter: ${chapter} (${chapterInfo.stepCount} steps)`)

  // Get MP3 durations for each step
  const stepDurations = chapterInfo.steps.map(s => {
    const mp3Path = path.join(audioDir, `${chapter}`, `${String(s.stepIndex).padStart(2, '0')}.mp3`)
    const duration = getMp3Duration(mp3Path)
    console.log(`  Step ${s.stepIndex}: ${duration.toFixed(1)}s (${path.basename(mp3Path)})`)
    return { stepIndex: s.stepIndex, mp3Path, duration }
  })

  const totalDuration = stepDurations.reduce((sum, s) => sum + s.duration, 0)
  console.log(`  Total audio: ${totalDuration.toFixed(1)}s`)

  // Merge chapter audio
  const chapterAudioPath = path.join(outputDir, `${chapter}-audio.mp3`)
  mergeChapterAudio(audioDir, chapter, chapterInfo.stepCount, chapterAudioPath)
  console.log(`  Merged audio: ${chapterAudioPath}`)

  // Launch Chrome
  const browserPath = detectBrowserPath()
  console.log(`Launching browser: ${browserPath || 'Puppeteer bundled Chromium'}`)

  const browser = await puppeteer.launch({
    headless: false,
    executablePath: browserPath,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-background-timer-throttling',
      '--disable-renderer-backgrounding',
      '--force-device-scale-factor=1',
      '--disable-gpu',
      '--disable-software-rasterizer',
      '--disable-dev-shm-usage',
      '--no-zygote',
    ],
    defaultViewport: { width: 1920, height: 1080 },
  })

  try {
    const page = await browser.newPage()

    // Navigate to chapter (manual mode, no ?auto=1)
    const url = `http://127.0.0.1:${port}/?chapter=${chapter}`
    console.log(`Opening: ${url}`)
    await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 })

    // Wait for React to render
    await page.waitForSelector('#root', { timeout: 10000 })

    // Wait for fonts to load
    await page.evaluate(() => document.fonts.ready)

    // Stabilization buffer
    await new Promise(r => setTimeout(r, 500))
    console.log('Page loaded, starting screencast...')

    // Start CDP screencast
    const cdp = await page.target().createCDPSession()
    const frames = []

    cdp.on('Page.screencastFrame', ({ data, sessionId }) => {
      frames.push(Buffer.from(data, 'base64'))
      cdp.send('Page.screencastFrameAck', { sessionId }).catch(() => {})
    })

    await cdp.send('Page.startScreencast', {
      format: 'jpeg',
      quality: 85,
      everyNthFrame: 1, // 每帧都取（静态页可能只有 1-2 帧）
      maxWidth: 1920,
      maxHeight: 1080,
    })

    console.log('Screencast started, driving slides...')

    const screencastStartTime = Date.now()

    // Drive slides: wait for audio duration + buffer, then advance
    for (let i = 0; i < stepDurations.length; i++) {
      const step = stepDurations[i]
      const waitMs = Math.round(step.duration * 1000) + 200 // audio duration + 200ms buffer

      console.log(`  Step ${step.stepIndex}: waiting ${waitMs}ms...`)
      await new Promise(r => setTimeout(r, waitMs))

      // Advance to next step (except last step)
      // Use page.evaluate + dispatchEvent instead of page.keyboard.press
      // because keyboard.press doesn't reliably trigger React window keydown listeners
      // during CDP screencast capture
      if (i < stepDurations.length - 1) {
        await page.evaluate(() => {
          window.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true }))
        })
      }
    }

    // Tail buffer: ensure last frame is captured
    console.log('  Tail buffer: 1000ms...')
    await new Promise(r => setTimeout(r, 1000))

    // Stop screencast
    await cdp.send('Page.stopScreencast')
    const screencastElapsed = (Date.now() - screencastStartTime) / 1000
    console.log(`Screencast stopped. Captured ${frames.length} frames in ${screencastElapsed.toFixed(1)}s.`)

    // Calculate actual fps from elapsed time and frame count
    // CDP pushes frames at variable rate (often 30-100fps), not fixed
    // Minimum 1fps to handle fully static pages (only 1 initial frame)
    let actualFps = Math.max(1, Math.round(frames.length / screencastElapsed))

    // For fully static pages (1-2 frames), duplicate the last frame to fill audio duration
    // Otherwise the video would be 1-2 seconds while audio is much longer
    const totalAudioDuration = stepDurations.reduce((sum, s) => sum + s.duration, 0) + 1.2 // +buffer
    if (frames.length <= 2 && totalAudioDuration > 3) {
      const targetFrames = Math.ceil(totalAudioDuration * 2) // 2fps is enough for static
      const lastFrame = frames[frames.length - 1]
      while (frames.length < targetFrames) {
        frames.push(lastFrame)
      }
      actualFps = 2
      console.log(`  Static page: duplicated to ${frames.length} frames at 2fps`)
    }

    console.log(`  Actual capture rate: ${actualFps} fps (${frames.length} frames / ${screencastElapsed.toFixed(1)}s)`)

    // Encode frames to MP4 using actual fps so video duration matches real time
    const rawVideoPath = path.join(outputDir, `${chapter}-raw.mp4`)
    console.log(`Encoding ${frames.length} frames at ${actualFps}fps to ${rawVideoPath}...`)
    await framesToMp4(frames, rawVideoPath, actualFps)
    console.log('  Raw video encoded.')

    // Mux audio
    const finalVideoPath = output || path.join(outputDir, `${chapter}.mp4`)
    console.log(`Muxing audio: ${chapterAudioPath} + ${rawVideoPath} -> ${finalVideoPath}`)
    muxAudio(rawVideoPath, chapterAudioPath, finalVideoPath)
    console.log(`  Final video: ${finalVideoPath}`)

    // Clean up intermediate files
    try { fs.unlinkSync(rawVideoPath) } catch (e) {}
    try { fs.unlinkSync(chapterAudioPath) } catch (e) {}

    console.log(`Chapter ${chapter} complete.`)
  } finally {
    await browser.close()
    console.log('Browser closed.')
  }
}

main().catch(err => {
  console.error('Failed:', err.message)
  process.exit(1)
})
