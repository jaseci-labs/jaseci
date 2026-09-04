"""Dispatcher consumer fixture.

Imports a walker (`Greet`) and a function-shaped boundary type
(`NotifyResult`) plus another walker (`Notify`) from `notify_service`
via `sv import`. Exercises the cross-service walker-spawn path: the
consumer constructs `Greet(name=...)`, the runtime turns that into a
POST to `/walker/Greet` on the provider, and a walker instance flows
back carrying the caller's arguments and the provider's `reports`.
"""

import from notify_service { Greet, Notify, NotifyResult }

walker:pub TriggerGreet {
    has who: str;

    can run with Root entry {
        rg = Greet(name=self.who);
        report rg.reports[0];
    }
}

walker:pub Announce {
    has channel: str;
    has subject: str;

    can run with Root entry {
        rn = Notify(channel=self.channel, subject=self.subject);
        report rn.reports[0];
    }
}

def:pub greet_via_walker(who: str) -> str {
    rg = Greet(name=who);
    return rg.reports[0];
}

def:pub remote_walker_fields(who: str) -> dict {
    rg = Greet(name=who);
    rn = Notify(channel="ops", subject="hello");
    return {"name": rg.name, "greeting": rg.reports[0], "body": rn.body};
}
