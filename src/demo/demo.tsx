import { useState } from 'react';

export default function Demo() {
    const [text, setText] = useState('');

    return (
        <section>
            <h1>Hello World Input</h1>
            <input
                type="text"
                value={text}
                onChange={(e) => setText(e.target.value)}
                placeholder="helloworld"
            />
            <p>入力値: {text}</p>
        </section>
    );
}
