import { useState } from 'react'
import './App.css'

function App() {
  const [text, setText] = useState('HelloWorld！')

  return (
    <div className="app">
      <label className="label" htmlFor="text-input">
        Input
      </label>
      <input
        id="text-input"
        className="text-input"
        type="text"
        value={text}
        onChange={(event) => setText(event.target.value)}
      />
      <div className="display" aria-live="polite">
        {text}
      </div>
    </div>
  )
}

export default App
