import React, { createContext, useCallback, useContext, useMemo, useReducer, useState } from 'react';

type User = {
    id: string;
    name: string;
    role: 'admin' | 'member';
};

type Action =
    | { type: 'add'; payload: User }
    | { type: 'remove'; payload: { id: string } };

type State = {
    users: User[];
};

const initialState = {
    users: [],
} as const satisfies State;

const UserContext = createContext<{
    state: State;
    dispatch: React.Dispatch<Action>;
} | null>(null);

function reducer(state: State, action: Action): State {
    switch (action.type) {
    case 'add':
        return { users: [...state.users, action.payload] };
    case 'remove':
        return { users: state.users.filter((u) => u.id !== action.payload.id) };
    default:
        return state;
    }
}

export function UserProvider({ children }: { children: React.ReactNode }) {
    const [state, dispatch] = useReducer(reducer, initialState);
    const value = useMemo(() => ({ state, dispatch }), [state]);

    return <UserContext.Provider value={value}>{children}</UserContext.Provider>;
}

export function UserList() {
    const ctx = useContext(UserContext);
    if (!ctx) return null;

    const { state, dispatch } = ctx;
    const [query, setQuery] = useState('');

    const filtered = useMemo(
    () => state.users.filter((u) => u.name.toLowerCase().includes(query.toLowerCase())),
    [state.users, query]
    );

    const onAdd = useCallback(() => {
    dispatch({
        type: 'add',
        payload: { id: crypto.randomUUID(), name: `User ${state.users.length + 1}`, role: 'member' },
    });
    }, [dispatch, state.users.length]);

    return (
    <section>
        <h2>Users</h2>
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="search" />
        <button onClick={onAdd}>Add</button>
        <ul>
        {filtered.map((u) => (
            <li key={u.id}>
            {u.name} ({u.role})
            </li>
        ))}
        </ul>
    </section>
    );
}

export function HelloWorld() {
    return <h1>Hello World</h1>;
}
