---
name: slopper
description: Ship to slopper.day from the terminal with the `slopper` CLI (npm @slopperday/cli). Use when the user wants to launch a project as today's slop or schedule launches for later days, post an update or field test, set a daily shipping goal, log costs or revenue, check today's slop of the day race, search slops, vote on slops, review slops they tried, or read their slops' reviews.
---

# Slopper

[slopper.day](https://slopper.day) is where people throw slop at the wall every day: they ship something small
daily (a site, a TestFlight or Play beta, a repo), set a goal like 30 slops in 30 days, and keep slopping until one is
slopcessful. Every UTC day the slops launched that day race on votes; the leader at midnight UTC wins slop of the day
and goes slopcessful. Slopcessful is earned, never declared: nobody can mark their own slop slopcessful.

## Setup

Run the CLI without installing it, with the runner the project already uses:

```sh
npx -y @slopperday/cli <command>            # -y, or npx stops to ask "Ok to proceed?" and waits
pnpm dlx @slopperday/cli <command>
bunx @slopperday/cli <command>
yarn dlx -q @slopperday/cli <command>       # -q, or yarn's install log lands in the JSON
deno run -A npm:@slopperday/cli <command>
```

Or install it once (`npm i -g @slopperday/cli`) and run `slopper`. The examples below say `slopper`: put the runner's
command in its place.

It needs to be signed in as the user. Run `slopper login` with no token: it opens their browser on a one-time code and
waits (up to ten minutes) until they approve it, then saves a token of its own. Tell the user to check the code matches
and click Approve. If no browser can open (a remote or sandboxed machine), use `--no-browser`, run it in the
background and give the user the link it prints on stderr. If they hand you a token instead, use it:

```sh
slopper login                          # browser sign-in; saves a token readable by the user only
slopper login --token slp_...          # or check and save a token from /settings/api
SLOPPER_TOKEN=slp_... slopper whoami   # saves nothing: use this when you shouldn't write files
```

`--url` (or `SLOPPER_URL`) points it at another site, like a local one.

Every command prints JSON on stdout. Errors go to stderr with exit code 1 (2 for a usage mistake), and validation
errors list each field that needs fixing. `slopper help <command>` shows every flag. A value that starts with a dash,
like a Markdown list, needs `=`: `--description="- one"`.

## Start with whoami

`slopper whoami` returns the user's username, time zone, today's UTC date, the open goal and its progress, the streak,
and the votes left today. Every day on Slopper is a UTC day: goal days, streaks and the race all end at midnight UTC.

`slopper profile @username` looks anyone up, the user included: their open goal day by day (`shipped`, `missed`,
`today`, `upcoming`, with how many are `scheduled`), how many are still `toGo`, their streak and their slops. It needs
no token, and neither do `today`, `search`, `categories`, `tags` or `reviews`.

## Launch a slop

1. Read the project: README, package.json or pubspec.yaml, and any deployed URL, App Store, TestFlight or Play beta
   links.
2. Take 1 to 3 screenshots of it running. The first is the cover.
3. Pick a category from `slopper categories`, and tags for what built it from `slopper tags`: the model you are
   (Opus 5.5), the harness running you (Claude Code) and the framework.
4. Launch it. Screenshot files are uploaded for you:

```sh
slopper launch \
  --name "TiltMaze" \
  --tagline "A marble maze you play by tilting your phone" \
  --category games \
  --description "Built in a day. Tilt to roll, find the exit before the timer runs out." \
  --link website=https://tiltmaze.app \
  --link testflight=https://testflight.apple.com/join/abc123 \
  --screenshot ./shots/cover.png --screenshot ./shots/level-2.png \
  --made-with "Opus 5.5" --made-with "Claude Code" --made-with Flutter \
  --note "Day 12: a maze you tilt. Try to beat 40 seconds." \
  --autopost
```

Link kinds: `website`, `app_store`, `testflight`, `play_store`, `play_beta`, `source`, `other`. A bare URL is a
website. Store links must use their store's domain.

The result has the slop's `id`, `slug` and `url`. Give the user the URL. `hidden: true` means only they can see it
while it waits for a moderator, and `nsfw: true` that it's blurred.

`--autopost` posts the launch to the accounts the user connected for auto-posting on slopper.day. When it can't be posted yet,
the result says why. Write the `--note` in the user's voice,
two sentences at most.

A new platform or a 2.0 is a new launch with its own shot at slop of the day:
`slopper launch --relaunch-of <slop> --label "iOS app" ...`. A new feature is an update, not a launch.

## Schedule launches

When several things are ready at once, ask the user whether to put them all out now or line them up. Every launch
counts towards the goal on the day it goes out: three today are three slops today, and three lined up fill three days,
each with its own shot at slop of the day.

```sh
slopper launch --at next ...                 # the next day with nothing out or scheduled, as its race starts
slopper launch --at 2026-10-15T09:00 ...     # the user's time zone, unless it has an offset
slopper scheduled                            # what's waiting, soonest first
slopper release <scheduled>                  # put it out now instead
slopper unschedule <scheduled>               # drop it
```

Nobody else sees a scheduled launch until it goes out. `--autopost` posts it then.

## Keep it alive

```sh
slopper post tiltmaze --kind feature --feature "Level editor" --version v1.3 --body "Build a maze and share the link." \
  --image ./shots/editor.png --link https://tiltmaze.app/editor --autopost
slopper post tiltmaze --kind field --outcome worked --who "5 people at the bus stop" --body "3 got hooked."
slopper edit tiltmaze --tagline "Now with a level editor" --screenshot ./shots/editor.png
slopper video tiltmaze ./promo.mp4
slopper money tiltmaze cost 12.99 --category domain --note "tiltmaze.app"
```

Update kinds: `update` (fixes, news), `feature` (something new shipped), `field` (a real-world test: ask the user who
tried it and what they said), `repromote` (bump it back up). An update can carry the `--version` that shipped, up to 4
`--image`s and 3 `--link`s; a feature takes its name (`--feature`), a field test how it went (`--outcome worked|mixed|broke`)
and who tried it (`--who`). `--preview` shows a card read from each linked page: only pass it when the user wants one.
`<slop>` is one of the user's slops, by id or slug (see
`slopper slops`). `edit` changes only the flags passed; `--link` and `--screenshot` replace the whole list. Editing
closes at the end of the launch day, or 12 hours after launch if that's later (`editableUntil` in `slopper slops`).
After that the original post is locked (its `video` isn't): share what's new with `slopper post`.
`video` puts a promo (MP4 or WebM, up to 4 MB) on a slop, replacing its last. It says `pending` while it waits for a
moderator, then `live`. Once one of the user's videos has been approved, later ones can say `live` straight away. `video <slop> --remove` takes it off.

## See how it's doing

```sh
slopper analytics tiltmaze             # the last 30 days
slopper analytics tiltmaze --days 7    # up to 90
```

Views and the people behind them (against the days before, and day by day), where visitors came from, what they clicked
on the slop's page, and its votes, pledges and updates. The user's own visits don't count. Use it to suggest what to do
next: a repromote when views are fading, a post where the visitors come from, a fix where people click and leave.

## Goals

Ask how many days first (7, 14, 30 or 100 are common), then how hard: one slop every five days is safe, every other day
is getting there, one a day is hardcore, two a day is impossible.

```sh
slopper goal --days 30 --target 30
```

Only one goal can be open at a time.

## Find slops

```sh
slopper search "budget tracker"                              # by words and by meaning, best match first
slopper search "maze" --category games --category creative   # only these categories
```

It matches what a slop does as well as its words, so "budget" finds an expense tracker. Each result has the slop's
`id` (for `vote`), `url` and whether it's the user's (`yours`). Hidden slops never show, NSFW ones only for users
who turned them on.

## The race and votes

`slopper today` ranks today's slops by votes, with each slop's `id`, whether it's the user's (`yours`), how they voted
(`yourVote`), and `votesLeft`.

```sh
slopper vote <slop id> up      # or down (private: lowers the ranking, nobody sees it), or clear
```

Everyone gets 5 votes per UTC day. Switching today's vote is free and clearing it gives it back. Nobody can vote on
their own slops. Every vote shows on the slop, but the race only counts votes cast on the race day, from accounts at
least a day old; makers racing that day can't downvote each other, and upvotes they swap don't count. Votes decide slop of the day, so only vote the way the user asks; never spend their votes on your own
judgement.

## Reviews

```sh
slopper reviews tiltmaze                                    # what people who tried it said: feedback on the user's slop
slopper review <slop id> broken --body "Crashes when I tilt left." --image ./shots/crash.png
```

`review` writes the user's review of someone else's slop: how it went (`works`, `mixed` or `broken`), what it is,
what they tried and what broke, with up to 4 `--image`s. It goes up at once; one that isn't fit for a general audience
is refused. One review per slop: writing again replaces it (pass the `--image`s again to keep them). Only review slops
the user actually tried, in their words. Use `reviews` on the user's own slops to suggest what to fix next.

## Don't

- Don't launch ideas, waitlists or anything that isn't live: a slop is something people can try today.
- Don't launch features as new slops; post them as updates.
- Don't retry `edit` once a slop is past its `editableUntil`; post an update instead.
- Don't put the token in files you commit. Use `slopper login` or `SLOPPER_TOKEN`.
