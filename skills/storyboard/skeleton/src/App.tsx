import { useState, useEffect } from 'react'
import { chapters } from './chapters'

function App() {
  const [globalStep, setGlobalStep] = useState(0)
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

  useEffect(() => {
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
  }, [totalSteps])

  const handleClick = (e: React.MouseEvent) => {
    const target = e.target as HTMLElement
    if (target.closest('[data-no-advance]')) return
    setGlobalStep(s => Math.min(s + 1, totalSteps - 1))
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
