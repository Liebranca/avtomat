# THE VIA MANIFESTO (WIP)

## SYNOPSIS

Proposed and absolutely major change to a large chunk of the `AR/` codebase.

## PREAMBLE

Relating to our immense and still growing library of linguistical abstractions, there is a singular, unsolvable problem that bites like no other: the size of a binary.

For the uninitiated, any piece of quantifiable information can be represented numerically and transmitted as signals through an appropiate medium; programming in it's most basic form is arranging numbers for an intermediary to process according to it's internal logic.

This is very much saying that our field of study is dedicated entirely to human-box communication; thus why software engineering has come to be considered, somewhat ironically, an endlessly soft and social science.

And note that we say 'intermediary' rather than 'computer' or 'device' as direct communication with hardware is forbidden occult knowledge to the vast majority of today's programmers; such interactions, and most complexities for that matter, are more often than not relegated to one or another abstraction layer that in turn might very well be doing the exact same thing albeit at a slightly lower level.

All of this is self-evident to anyone paying enough attention, even if they're unable to put it into words: a whole lot of what we do is convert series of commands into a single one, ie *encapsulate* them, for mere convenience if nothing else, an act that further perpetuates this cycle that has already spiraled ways beyond oblivion.

The problem comes in when this recursive abstraction of an abstraction pathway to avernum goes past a certain threshold of acceptable workload; summoning of a monolith marid for each and every purpose is impracticable -- this means that if every incantation weighs about the same as hell and the devil put together then such is what breaks loose.

Thus, intermediaries are utilized. In the vernacular, this is what they tend to call 'services', see also 'server' and 'client'. The basic principle is the same as routinely practiced: that of abstracting away a complex set of instructions behind a single message, typically only a few bytes long.

Where this differs from routine abstraction is in that the binary that interprets this message exists separately from the invocation, and is usually able to *service* multiple callers at once. In other words, an executable loses the need to bloat itself with those instructions.

There is a latency tradeoff to inter-process communication, big enough to damn the approach for anything small, negligible enough to be utilized anytime a complex *and* common task is involved.

In embracing this model, an application trying to carry out any such task has to concern itself solely with a messaging protocol rather than an endlessly deep dependency iceberg; development is thus greatly eased by having the most complex functionality abstracted away behind a socket.

What follows is a description of the basic `Via` protocol, proposed as a basis for all others.

## BASE STRUC

`Via` stands for route and `Harbor` for destination, deliverately used synonyms as 'routing' and 'port' mean something else entirely.

The concept is quite simple: `Harbor` represents a service and `Via` a connection to it. Any resource or object local to an application -- ie, not shared with others -- exists independently of the system; shared resources and objects, on the other hand, are managed by what we call 'remotes'.

A remote is merely a *handle* to a portion of memory managed by a service, from ROM blocks to objects. Interactions are achieved through messaging, which follows a set of structures.

For the header:

```$

# [$:10] mess head

     /->byte harb[7]         /->brad flg
     |                       |
   : +-----------:         : +-------:
$24: 4E5000000000: 00000040: 00000000:
 +-:             : +-------:         :
 |                 |
 \->byte sig       \->brad sz

```

^Where:

- `sig` is the *type* of message.

- `harb` is a service ID.

- `sz` gives the total size of the message.

- `flg` provide additional switches to the intepreter. See: __(DOC PENDING)__.


Messages are meant to provide multiple instructions for a service; for the body of the message, it is given as an array of operations, where each element takes the following form:

```$

# [$:10+ezy] mess elem

       /->wide kls
       |
     : +---:         :                 :
$0010: 10E4: 0000S14E: 7000000000010C9E:
 +---:     : +-------: +---------------:
 |           |         |
 \->wide ezy |         \->word opcd
             |
             \->brad obid

```

^Where:

- `ezy` gives an element's size in the array.

- `kls` is the remote type.

- `obid` denotes the remote ID.

- `opcd` is an argless instruction code


With an added size of `ezy` bytes, which are `unit` aligned, for passing any additional data required by the instruction.

Remotes are *programmable* through messages so that the client-server interactions can be kept to a minimum: rather than relying on a constant stream of responses, remote objects are given a list of tasks to perform for a certain (preferably long) stretch of an application's lifetime.

For illustration, consider this stripped-down model:

```$

+--------+
| CLIENT |
+--------+
|
\->(handle local)
\->send array of tasks to server
.
.
+--------+
| SERVER |
+--------+
|
\->client scheduled tasks for this frame?
. .
. \->YES
. . \->walk schedule
. . . \->fetch obj
. . . \->exec ins
. . . \->push result to response?
. . . .
. . . \->rept?
. . . . \->YES
. . . . . \->push entry to next frame
. . . . .
. . . . \->NO
. . . . . \->discard entry
. . .
. . \->give response to client?
. .   \-----------------------:
. .               |
. \->NO           |
. . \->sleep      |
.                 |
.                 |
.                 |
+--------+        |
| CLIENT |<-------+
+--------+
|
\->proc response?
\->rept or close

```

In essence: a chain of calls is written, then sent and *remotely executed*, with results __optionally__ given back to the client for local use.

These public interface or `iface` calls must follow the `peso` convention in their signature:

- `nihil` or `void(void)`: no arguments and no return.

- `stark` or `void(void*)`: arguments packed into an input struc, but no return.

- `signal` or `void*(void*)`: arguments packed into an input struc, results given as a packed output struc.


Due to both bytesize __and__ latency concerns, `nihil` should always be preferred, followed by `stark`, and then `signal` when nothing else within reason could possibly work.

The rule of thumb is that a remote should hold sufficient data within it's own or the server's internal state to enable either a purely or mostly `nihil iface`, with arguments or returns only *ever* being used when a full-blown interaction with the 'outside world' is entirely inevitable.

(TO BE CONTINUED...)
