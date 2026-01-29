import { useEffect, useMemo, useState } from "react";
import "./App.css";

const SIZE = 8;
const EMPTY = 0;
const BLACK = 1;
const WHITE = 2;
const DIRS = [
  [-1, -1],
  [-1, 0],
  [-1, 1],
  [0, -1],
  [0, 1],
  [1, -1],
  [1, 0],
  [1, 1],
];

function createInitialBoard() {
  const board = Array.from({ length: SIZE }, () => Array(SIZE).fill(EMPTY));
  const mid = SIZE / 2;
  board[mid - 1][mid - 1] = WHITE;
  board[mid][mid] = WHITE;
  board[mid - 1][mid] = BLACK;
  board[mid][mid - 1] = BLACK;
  return board;
}

function getFlips(board, row, col, player) {
  if (board[row][col] !== EMPTY) return [];
  const opponent = player === BLACK ? WHITE : BLACK;
  const flips = [];

  for (const [dr, dc] of DIRS) {
    let r = row + dr;
    let c = col + dc;
    const line = [];
    while (r >= 0 && r < SIZE && c >= 0 && c < SIZE) {
      const cell = board[r][c];
      if (cell === opponent) {
        line.push([r, c]);
      } else if (cell === player) {
        if (line.length > 0) {
          flips.push(...line);
        }
        break;
      } else {
        break;
      }
      r += dr;
      c += dc;
    }
  }

  return flips;
}

function findValidMoves(board, player) {
  const moves = new Map();
  for (let r = 0; r < SIZE; r += 1) {
    for (let c = 0; c < SIZE; c += 1) {
      if (board[r][c] !== EMPTY) continue;
      const flips = getFlips(board, r, c, player);
      if (flips.length > 0) moves.set(`${r},${c}`, flips);
    }
  }
  return moves;
}

function countDisks(board) {
  let black = 0;
  let white = 0;
  for (const row of board) {
    for (const cell of row) {
      if (cell === BLACK) black += 1;
      if (cell === WHITE) white += 1;
    }
  }
  return { black, white };
}

function nextPlayer(board, current) {
  const opponent = current === BLACK ? WHITE : BLACK;
  const opponentMoves = findValidMoves(board, opponent);
  if (opponentMoves.size > 0) return opponent;
  const currentMoves = findValidMoves(board, current);
  if (currentMoves.size > 0) return current;
  return EMPTY;
}

export default function App() {
  const [board, setBoard] = useState(createInitialBoard);
  const [player, setPlayer] = useState(BLACK);

  const validMoves = useMemo(() => findValidMoves(board, player), [board, player]);
  const { black, white } = useMemo(() => countDisks(board), [board]);
  const hasAnyMoves = validMoves.size > 0;

  useEffect(() => {
    if (player === EMPTY) return;
    if (validMoves.size > 0) return;
    const nextP = nextPlayer(board, player);
    if (nextP !== player) setPlayer(nextP);
  }, [board, player, validMoves]);

  const status = (() => {
    if (player === EMPTY) {
      if (black === white) return "引き分け";
      return black > white ? "黒の勝ち" : "白の勝ち";
    }
    if (!hasAnyMoves) return "パス（置ける場所がありません）";
    return player === BLACK ? "黒の番" : "白の番";
  })();

  function handleCellClick(r, c) {
    if (player === EMPTY) return;
    const key = `${r},${c}`;
    const flips = validMoves.get(key);
    if (!flips) return;
    const next = board.map((row) => row.slice());
    next[r][c] = player;
    for (const [fr, fc] of flips) {
      next[fr][fc] = player;
    }
    const nextP = nextPlayer(next, player);
    setBoard(next);
    setPlayer(nextP);
  }

  function handleReset() {
    setBoard(createInitialBoard());
    setPlayer(BLACK);
  }

  return (
    <main className="app">
      <header className="app__header">
        <div>
          <h1>Othello / Reversi</h1>
          <p>置ける場所が光ります。クリックで石をひっくり返します。</p>
        </div>
        <button type="button" className="ghost-button" onClick={handleReset}>
          リセット
        </button>
      </header>

      <section className="status">
        <div className={`badge ${player === BLACK ? "is-active" : ""}`}>黒: {black}</div>
        <div className={`badge ${player === WHITE ? "is-active" : ""}`}>白: {white}</div>
        <div className="status__text">{status}</div>
      </section>

      <section className="board">
        {board.map((row, r) =>
          row.map((cell, c) => {
            const key = `${r}-${c}`;
            const moveKey = `${r},${c}`;
            const isHint = validMoves.has(moveKey);
            return (
              <button
                key={key}
                type="button"
                className={`cell ${isHint ? "cell--hint" : ""}`}
                onClick={() => handleCellClick(r, c)}
                aria-label={`row ${r + 1} col ${c + 1}`}
              >
                {cell !== EMPTY && <span className={`disk ${cell === BLACK ? "disk--black" : "disk--white"}`} />}
              </button>
            );
          })
        )}
      </section>
    </main>
  );
}
