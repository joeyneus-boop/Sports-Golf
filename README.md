# ⛳ Sports Golf

A daily sports-stats trivia game. Each of the nine holes asks for the player at a specific rank on a stat leaderboard (NFL, college football, NBA, college basketball, NHL, MLB). The closer you are, the better your golf score.

**Play:** https://playsportsgolf.com

## Scoring
| Spots off | Result | Score |
|---|---|---|
| 0 | Hole in one | −3 |
| 1–5 | Eagle | −2 |
| 6–10 | Birdie | −1 |
| 11–20 | Par | E |
| 21–30 | Bogey | +1 |
| 31–40 | Double bogey | +2 |
| 41+ | Triple bogey | +3 |

**Unlimited mode:** play random courses as many times as you want; those rounds don't count toward the daily leaderboard.

A name that isn't on the leaderboard is a strike. Three strikes (or Give up) is a splash for +3. Ties break on total spots off (a splash counts as 100), then fewest strikes, then who posted first.

## Leaderboard setup (Supabase)
1. Create a free project at supabase.com.
2. SQL Editor → paste `supabase/schema.sql` → Run.
3. Project Settings → API Keys: copy the Project URL and the publishable key into `SUPABASE_URL` and `SUPABASE_ANON_KEY` near the leaderboard section of `index.html`. (Already done for the live site.)

To hide an offensive name, open the `scores` table in the Supabase dashboard and set `hidden` to true on that row.

## Data
Rankings are a snapshot from Nov 17, 2026 (Basketball/Hockey/Baseball/Sports Reference, footballdb, drafthistory.com, Wikipedia).
