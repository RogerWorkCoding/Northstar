# TestFlight checklist (Northstar)

Done in the app (Oct 15):
- [x] Privacy manifest: `Northstar/PrivacyInfo.xcprivacy` (no tracking; UserDefaults reason CA92.1; data types match the privacy page)
- [x] Plain-language permission messages: camera, microphone, speech, saving to Photos
- [x] Export compliance answered in the app (`ITSAppUsesNonExemptEncryption = NO`, HTTPS only), so uploads don't stop to ask
- [x] App category: Productivity
- [x] App icon 1024×1024
- [x] About screen with version number

Still needed (Roger):
- [ ] Contact email and business address for the privacy page, then a public web address for it
- [ ] Put that address in App Store Connect (Privacy Policy URL) and in `AboutView.privacyURL`
- [ ] App Store Connect: create the app record (bundle id `app.mynorthstarlabs.Northstar`), fill App Privacy answers to match the manifest
- [ ] Each upload: raise the build number (Xcode → target → General → Build)
- [ ] Xcode → Product → Archive → Distribute App → TestFlight
- [ ] Add testers in App Store Connect → TestFlight (internal first; external needs a short Beta App Review)
