import os
import select
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

vnode_changes = select.KQ_NOTE_WRITE | select.KQ_NOTE_DELETE | select.KQ_NOTE_RENAME | select.KQ_NOTE_EXTEND


@dataclass(frozen=True)
class Watched:
    path: Path
    session: str | None


def registered(queue: select.kqueue, paths: list[Watched]) -> dict[int, Watched]:
    opened = {}
    for watched in paths:
        try:
            opened[os.open(watched.path, os.O_EVTONLY)] = watched
        except OSError:
            continue
    queue.control([select.kevent(fd, filter=select.KQ_FILTER_VNODE, flags=select.KQ_EV_ADD | select.KQ_EV_CLEAR,
                                 fflags=vnode_changes) for fd in opened], 0, 0)
    return opened


def watch(paths: Callable[[], list[Watched]], on_change: Callable[[set[str] | None], None]) -> None:
    queue = select.kqueue()
    opened: dict[int, Watched] = {}
    names: set[str] | None = None
    while True:
        stale = [fd for fd, watched in opened.items() if names is None or watched.session in names]
        for fd in stale:
            os.close(fd)
            del opened[fd]
        opened |= registered(queue, [watched for watched in paths() if names is None or watched.session in names])
        on_change(names)
        fired = {opened[event.ident].session for event in queue.control(None, 64, None) if event.ident in opened}
        names = None if not fired or None in fired else fired
