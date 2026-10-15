# Video (Google Veo): one-time setup

## 1. Google API key (you)
1. Go to **aistudio.google.com** and sign in with your Google account.
2. Click **Get API key**, then **Create API key**.
3. Turn on **billing** for that key's project (Set up billing / Upgrade to paid). Veo isn't on the free plan.
4. Copy the key. Keep it private.

## 2. Put the key in Supabase (you)
1. In Supabase, go to **Edge Functions → Secrets**.
2. Click **Add new secret**.
3. Name: `GEMINI_API_KEY`. Value: paste your key.
4. Click **Save**.

## 3. Database (you)
Run `supabase/migrations/20261017_videos.sql` in the **SQL Editor**.

## Settings you can change (optional secrets)
- `NS_VEO_MODEL`: `veo-3.1-lite-generate-preview` (default, cheapest) or `veo-3.1-fast-generate-preview`
- `NS_VEO_DOLLARS_PER_SECOND`: `0.05` for Lite (default), `0.10` for Fast
- `NS_USER_DAILY_VIDEOS`: `3` by default
- `NS_VEO_RESOLUTION`: `720p` (default) or `1080p` (8-second clips only)
