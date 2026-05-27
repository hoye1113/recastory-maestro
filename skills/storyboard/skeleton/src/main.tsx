import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './theme.css'
import './App.css'
// Chapter CSS imports injected by scaffold.sh
import App from './App'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
