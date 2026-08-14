from collections import deque
from time import monotonic

from fastapi import HTTPException, status


class InMemoryRateLimiter:
    def __init__(
        self,
        *,
        max_requests: int,
        window_seconds: int,
        max_identities: int = 10_000,
    ) -> None:
        self._max_requests = max_requests
        self._window_seconds = window_seconds
        self._max_identities = max_identities
        self._requests: dict[str, deque[float]] = {}

    def check(self, identity: str) -> None:
        now = monotonic()
        cutoff = now - self._window_seconds
        requests = self._requests.setdefault(identity, deque())

        while requests and requests[0] <= cutoff:
            requests.popleft()

        if len(requests) >= self._max_requests:
            retry_after = max(1, int(requests[0] + self._window_seconds - now) + 1)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Please try again later.",
                headers={"Retry-After": str(retry_after)},
            )

        requests.append(now)
        self._remove_inactive_identities(cutoff)

    def _remove_inactive_identities(self, cutoff: float) -> None:
        if len(self._requests) <= self._max_identities:
            return

        inactive = [
            identity
            for identity, requests in self._requests.items()
            if not requests or requests[-1] <= cutoff
        ]
        for identity in inactive:
            self._requests.pop(identity, None)
            if len(self._requests) <= self._max_identities:
                break
