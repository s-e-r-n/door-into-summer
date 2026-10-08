import os
import select
from collections.abc import Callable
from pathlib import Path

vnode_changes = select.KQ_NOTE_WRITE | select.KQ_NOTE_DELETE | select.KQ_NOTE_RENAME | select.KQ_NOTE_EXTEND


def registered(queue: select.kqueue, paths: list[Path]) -> list[int]:
    opened = []
    for path in paths:
        try:
            opened.append(os.open(path, os.O_EVTONLY))
        except OSError:
            continue
    queue.control([select.kevent(fd, filter=select.KQ_FILTER_VNODE, flags=select.KQ_EV_ADD | select.KQ_EV_CLEAR,
                                 fflags=vnode_changes) for fd in opened], 0, 0)
    return opened


def watch(paths: Callable[[], list[Path]], on_change: Callable[[], None]) -> None:
    queue = select.kqueue()
    while True:
        opened = registered(queue, paths())
        on_change()
        queue.control(None, 64, None)
        for fd in opened:
            os.close(fd)
