import { useState, useEffect, useRef } from 'react'
import { chapters } from './chapters'

const params = new URLSearchParams(window.location.search)
const isAutoMode = params.get('auto') === '1'

function App() {
  const [globalStep, setGlobalStep] = useState(0)
  const [isStarted, setIsStarted] = useState(false)
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const totalSteps = chapters.reduce((sum, ch) => sum + ch.stepCount, 0)

  let accumulated = 0
  let activeChapter = 0
  let localStep = 0
  for (let i = 0; i < chapters.length; i++) {
    if (globalStep < accumulated + chapters[i].stepCount) {
      activeChapter = i
      localStep = globalStep - accumulated
      break
    }
    accumulated += chapters[i].stepCount
  }

  const ChapterComponent = chapters[activeChapter].Component

  // SPACE to start (auto mode only, before started)
  useEffect(() => {
    if (!isAutoMode) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === ' ' && !isStarted) {
        e.preventDefault()
        setIsStarted(true)
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [isAutoMode, isStarted])

  // Manual keyboard navigation (disabled in auto mode)
  useEffect(() => {
    if (isAutoMode) return
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight' || e.key === ' ') {
        e.preventDefault()
        setGlobalStep(s => Math.min(s + 1, totalSteps - 1))
      }
      if (e.key === 'ArrowLeft') {
        e.preventDefault()
        setGlobalStep(s => Math.max(s - 1, 0))
      }
    }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [totalSteps, isAutoMode])

  // Auto-play: play audio per step, advance on ended
  useEffect(() => {
    if (!isAutoMode || !isStarted) return

    // Find chapter/localStep from globalStep
    let acc = 0, chIdx = 0, local = 0
    for (let i = 0; i < chapters.length; i++) {
      if (globalStep < acc + chapters[i].stepCount) {
        chIdx = i; local = globalStep - acc; break
      }
      acc += chapters[i].stepCount
    }

    const chapterId = chapters[chIdx].id
    const stepNum = String(local + 1).padStart(2, '0')
    const audio = new Audio(`/audio/${chapterId}/${stepNum}.mp3`)
    audioRef.current = audio

    const onEnded = () => {
      setTimeout(() => {
        setGlobalStep(s => Math.min(s + 1, totalSteps - 1))
      }, 200)
    }
    audio.addEventListener('ended', onEnded)
    audio.play().catch(console.error)

    return () => {
      audio.pause()
      audio.removeEventListener('ended', onEnded)
      audioRef.current = null
    }
  }, [globalStep, isAutoMode, isStarted, totalSteps])

  // Manual click handler (disabled in auto mode)
  const handleClick = (e: React.MouseEvent) => {
    if (isAutoMode) return
    const target = e.target as HTMLElement
    if (target.closest('[data-no-advance]')) return
    setGlobalStep(s => Math.min(s + 1, totalSteps - 1))
  }

  // Auto mode: overlay before start
  if (isAutoMode && !isStarted) {
    return (
      <div style={{
        width: 1920, height: 1080,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: '#000', color: '#fff', fontSize: 32
      }}>
        Press SPACE to start
      </div>
    )
  }

  return (
    <div className="cd-shell" onClick={handleClick}>
      <ChapterComponent step={localStep} />
      <div className="cd-progress">
        <div className="cd-progress-bar" style={{ width: `${((globalStep + 1) / totalSteps) * 100}%` }} />
      </div>
    </div>
  )
}

export default App
