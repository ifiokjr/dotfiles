---
name: slopper
description: Ship to slopper.day from the terminal with the `slopper` CLI (npm @slopperday/cli). Use when the user says to deploy, ship, post or put a project on Slopper or slopper.day, wants to launch a project as today's slop or schedule launches for later days, post an update or field test, edit and upload a Slopper promo video, manage social drafts and schedules, set a daily shipping goal, log costs or revenue, check today's slop of the day race, search slops, vote on slops, review slops they tried, or read their slops' reviews.
---

# Slopper

[slopper.day](https://slopper.day) is where people throw slop at the wall every day: they ship something small
daily (a site, a TestFlight or Play beta, a repo), set a goal like 30 slops in 30 days, and keep slopping until one is
slopcessful. Every UTC day the slops launched that day race on votes; the leader at midnight UTC wins slop of the day
and goes slopcessful. Slopcessful is earned, never declared: nobody can mark their own slop slopcessful.

"Deploy this to Slopper" means launch the project as a slop (see [Launch a slop](#launch-a-slop)). Slopper doesn't
host apps: a slop links to where the project already runs, so deploy it to its own host first if it isn't live yet. Only
something to read (a PDF or EPUB) is uploaded to Slopper itself. Inside the slopper.day repository, deploying means
releasing the site: follow that repository's `AGENTS.md` instead.

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
Saved tokens stay with their saved origin (scheme, host and port); for another site, log in there or supply its token
explicitly. Use HTTPS except for loopback HTTP addresses during local development.

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

When the user wrote something to read (a book, zine, guide or paper), launch it with `--publication ./guide.pdf`
(a PDF or EPUB up to 4 MB, uploaded for you). People read it from the slop page, and `--link` becomes optional.
Files with scripts, auto-run actions, forms, attachments, a password or DRM are refused, and so are EPUBs that load
anything from the web; export a plain PDF or EPUB instead.
`slopper edit <slop> --remove-publication` takes it off.

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

## Post to social accounts

The user's connected accounts (X, LinkedIn, Bluesky, Threads, Facebook Pages, Instagram, TikTok, YouTube, Mastodon,
Discord, Telegram, Reddit) can all post
one message at once, each copy fitted to its network and checked first:

```sh
slopper social accounts                                         # ids, networks and brands
slopper social post "Tiltmaze 2.0 is out" --account <id> --account <id> --link https://tiltmaze.app \
  --thread "40 new levels" --first-comment "#indiegames" --at draft --key launch-2-0
slopper social edit <post> --text "Revised announcement"        # keeps it a draft
slopper social edit <post> --copy x="Short version for X" --copy <account-id>="Brand-specific version"
slopper social edit <post> --link-for linkedin=https://tiltmaze.app/blog --comment-for x="Play it: tiltmaze.app" \
  --media-for instagram=<media-id>,<media-id> --time-for <account-id>=2026-11-24T18:00
slopper social post "Idea: a 2.0 teaser thread" --at draft  # an idea: no accounts yet
slopper social status <post>                                    # per-account previews and readiness warnings
slopper social edit <post> --options '{"instagram":{"format":"story"}}' # update one network's format
slopper social edit <post> --at 2026-11-24T09:30               # schedule all selected accounts
slopper social edit <post> --at 2026-11-25T10:00               # move the scheduled time
slopper social cancel <post>                                    # delete draft or cancel schedule
slopper social posts                                            # drafts, scheduled and sent
slopper social status <post>                                    # each copy's link and stats
slopper social resolve <delivery> --posted --link https://x.com/… # an uncertain copy did post
slopper social resolve <delivery> --resend                      # it didn't: send it again
```

Use `--at draft` to save without publishing; `social edit` changes only flags provided and keeps the existing
accounts, media, network options and schedule. Use `social accounts` for account IDs and repeat `--account` to replace
the selected accounts. Times without offsets use the user's time zone; include `Z` or an offset for an explicit zone.
Each `--copy` changes only that network or account; account-specific text takes precedence over network text, and
`--copy x=` removes that override. `--link-for`, `--comment-for` and `--media-for` give a network or account its own
link, first comment or subset of the post's media the same way (an empty value means none there), and `--time-for`
gives one account its own time. Two X accounts can't post the same words (X's automation rules): give each its own
`--copy`. A draft with no accounts is an idea; pick accounts before scheduling. `social status` gives each fitted preview and warnings about missing media,
network options, unavailable accounts or text that would be shortened. Discuss useful improvements with the user;
preflight does not predict content-check or network acceptance. Set network-specific formats through `--options`
with JSON; `social status` shows the current settings. Each supplied network replaces its settings, preserving the rest. Scheduling runs the content check. Cancel a scheduled
post before it goes out. A copy marked uncertain was lost mid-send and is never resent on its own: ask the user to check
the network, then `social resolve` it. Post or schedule when the user has
authorized it; otherwise save a draft for review. The corresponding MCP operations are `list_social_accounts`,
`create_social_post`, `list_social_posts`, `get_social_post`, `edit_social_post`, `cancel_social_post` and
`resolve_social_delivery`; REST uses `GET/POST /api/v1/social/posts`, `GET/PATCH/DELETE /api/v1/social/posts/:post`
and `POST /api/v1/social/deliveries/:delivery/resolve`.

To make a promo video, edit the user's source files locally with the available video tools (for example, ffmpeg),
preview the result and keep it MP4 or WebM under 4 MB. Then run `slopper video <slop> <file>`: it uploads the file and
sets it as that Slop's promo. The response says whether it is pending moderation or live. MCP can do the same with
`upload_video` followed by `set_video`; REST uses `POST /api/v1/videos` and `PUT /api/v1/slops/:slop/video`.
This publishes the promo to Slopper subject to moderation, without sending it to the connected social platforms.

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
closes at the end of the day after launch, at least 24 hours after it goes out (`editableUntil` in `slopper slops`).
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
