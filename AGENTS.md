# Windows Listener specification maintenance

Before finishing Listener feature work, read `C:/Users/bayua/Documents/ChatGPT/WMS/specifications/WMS_WINDOWS_LISTENER_SPEC_TRACKING.md` and compare with both active FSD/TSD Markdown snapshots and accumulated pending changes. The initial version is 1.0.0, explicitly selected by the user on 13 October 2026; always consult the tracker for the current version.

- Ask whether to update both documents only if scope, behavior, rules, data, API or integration changes, including new features. Show concrete changes and all applicable pending items, and ask for major, minor or patch with concrete version options. Do not select or increment automatically.
- Only after explicit update and version confirmation generate both FSD/TSD Markdown snapshots and Word copies, and update the Listener tracker and changelog together. Preserve historical snapshots. Markdown is the editing reference.
- Synchronize `ListenerConstants.appVersionLabel` in `lib/core/constants/listener_constants.dart` to `v<approved version>` in the same task. This is standing authorization, not a separate approval. Verify FSD, TSD, tracker and label match. Do not automatically change pubspec or installer package/build versions.
- If declined, deferred or unanswered, retain the baseline/version, record development in progress in the pending tracker, and ask again only after a later relevant update. Continue authorized development. Refactors and formatting without specification impact do not trigger a bump.
- Listener and Mobile have separate documentation versions. Listener-only updates must not change the Mobile label or baseline. Assess both trackers for shared contract changes; approval for one product does not approve a version update for the other.

## WMS mobile specification coordination

For listener changes affecting mobile connectivity, document search, printing, APIs or behavior, read:
`C:/Users/bayua/Documents/ChatGPT/WMS/specifications/WMS_MOBILE_SPEC_TRACKING.md`.
The initial documentation baseline is 1.3.0; consult the tracker for the current version and FSD/TSD Markdown snapshots.

Compare the change with the baseline and accumulated pending changes. If the mobile specifications are affected, ask whether to update both Mobile FSD and TSD and whether to increase **major, minor or patch**, showing the actual changes and version options. Only after explicit confirmation and version selection generate updated Mobile documents and Markdown snapshots, advance the Mobile documentation version and update its changelog/tracker and appVersionLabel under the shared workspace rules. Preserve historical versions.

If declined, deferred or unanswered, leave the generated baseline and version unchanged, record pending changes, and ask again after another relevant update. Do not ask again for the same unchanged work or block authorized development. Listener work with no Mobile specification impact does not trigger a Mobile version bump; assess Listener impact separately. Report inability to read the relevant tracker before generating a new baseline.
