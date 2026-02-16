from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

@dataclass(frozen=True)
class User:
    id: int
    name: str
    active: bool = True

def load_users(path: Path) -> list[User]:
    rows = path.read_text(encoding="utf-8").splitlines()
    users = [User(id=i, name=row.strip()) for i, row in enumerate(rows)]
    return users

def filter_users(users: Iterable[User], keyword: str) -> list[User]:
    return [u for u in users if keyword.lower() in u.name.lower()]

def main() -> None:
    root = Path(".")
    users = load_users(root / "users.txt")
    active = [u for u in users if u.active]
    result = filter_users(active, "alice")
    print(result)

if __name__ == "__main__":
    main()
