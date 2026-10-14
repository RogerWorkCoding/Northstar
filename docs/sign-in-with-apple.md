# Sign in with Apple: 3 switches

The code is in the app. It starts working after these 3 switches. Each takes about a minute.

## 1. Xcode: add the capability
1. Click the blue **Northstar** project at the top left.
2. Choose the **Northstar** target, then the **Signing & Capabilities** tab.
3. Click **+ Capability** and double-click **Sign in with Apple**.

Xcode turns it on in your Apple Developer account automatically.

## 2. Supabase: turn on Apple
1. Go to **Authentication → Sign In / Providers → Apple**.
2. Switch it **on**.
3. In **Client IDs**, type: `app.mynorthstarlabs.Northstar`
4. Click **Save**. Leave the secret key empty; it isn't needed for the iPhone app.

## 3. Supabase: allow linking
1. Under **Authentication → Sign In / Providers**, find **Allow manual linking**.
2. Turn it **on**, then click **Save**.

This lets Apple attach to the account you already have, so nothing is lost.

## Test it
In the app, open **Settings → Account → Sign in with Apple**. It should then say **Signed in with Apple ✓**.
