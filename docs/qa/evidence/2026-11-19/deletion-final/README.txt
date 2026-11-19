Final verification of conversation deletion and cache clearing
Date: 2026-11-19, 14:06–14:15 (local). Device: Nubia NX679J, Android 13 (only device).

WHERE THIS RAN — read first
All destructive steps ran in an isolated setup, NOT on AWS:
- App: a second package `com.nexa.nexa_example.qa` (debug build of the working
  tree after commit 769f7e6 plus the "؟" fix, NEXA_APP_ID_SUFFIX=.qa), with its
  own data, installed next to the owner's app and uninstalled at the end.
- Server: the local reference gateway of this repo (tools/nexa_reference_gateway,
  contract labeeb.sdk/1 routes) on the Mac, reached through `adb reverse`.
  Its account is application `app_example_host` with tokens minted locally.
- The owner's AWS token was never built into the QA app.
Every PASS below means "device + local reference gateway". It is not an AWS result.

AWS (the authoritative backend): BLOCKED for "Delete all conversations".
The only AWS credential on this machine is the owner's account. No isolated QA
account exists there, so the action would delete the owner's history.
Needed: a second SDK token for a QA user.

OWNER DATA — read-only checks
14:06:08 AWS GET /v1/sdk/conversations -> 200 | owner account total 1
14:15:23 AWS GET /v1/sdk/conversations -> 200 | owner account total 1
Owner app `com.nexa.nexa_example` lastUpdateTime 2026-11-19 13:26:28 before and after.
No write request was sent to AWS in this run.

OBSERVATION (not caused by this run, cause not established)
At 13:27:15 the owner account had 42 conversations (previous evidence file).
At 14:06:08, before any step of this run, it had 1, created at 13:52 local.
Between those times this session sent no request to AWS. The build with
"Delete all conversations" was on the owner's phone from 13:26.

SEED (local gateway)
14:06:18 three conversations: "QA chat one", "QA chat two", "QA call record"
(the last with two spoken turns through POST …/voice-turns -> 200). The gateway
lists it as kind `chat` with 1 message; a conversation of kind `voice` was not available.

1. Delete the currently open conversation                              PASS
   Opened "QA chat one", sent one message (it is the open conversation), went
   back to the list, row menu -> "حذف هذه المحادثة" -> "حذف".
   Sheet: "حُذف من هذا الجهاز" / "حُذف من الخادم". open-confirm.png
   14:08:10 local GET -> total 2 (call record, chat two). Row gone from the list.
   "محادثة جديدة" -> message sent -> 14:08:36 local GET -> total 3, a new
   conversation exists (the deleted id was not reused).

2. Server failure, one conversation                                    PASS
   A proxy in front of the gateway answered 500 to every DELETE (failure-proxy.log).
   Sheet: "حُذف من هذا الجهاز" / "لم تؤكد الخدمة الحذف." with "إعادة المحاولة". fail-single.png
   "Deleted on the server" was not shown. 14:09:17 local GET -> total 3 (unchanged).
   After "تم" the row "QA chat two" is in the list again.

3. Clear cache                                                         PASS
   Before/after file lists with checksums: clear-cache-files-before.txt / -after.txt.
   Removed: cached summaries (files/history_*.json), QA logs (nexa_qa records;
   index emptied), temporary files (cache/…), local image copy (files/nexa_media/…).
   Unchanged: installation_id, labeeb_theme.json (appearance set to light before
   the test, still light after relaunch), shared_prefs, and a placeholder file at
   the voice-profile path (no_backup/nexa_assistant/voice_profile.bin).
   Server untouched: no request reached the proxy during the action;
   14:11:13 local GET -> total 3; the uploaded attachment still answers 200.
   The files in cache/, nexa_media/ and the voice-profile path were synthetic text
   placeholders written for this test. A real approved voice profile: NOT TESTED.
   Sign-in: the QA app has no stored sign-in (it mints a token per start), so
   "login is kept" is NOT TESTED.

4. Server failure, delete all                                          PASS
   Sheet: "حُذف من هذا الجهاز" / "لم تؤكد الخدمة الحذف." fail-all.png
   14:12:24 local GET -> total 3 (unchanged). After "تم": the list shows all three rows.

5. Delete all conversations                                            PASS (local gateway only)
   Sheet: "حُذف من هذا الجهاز" / "حُذف من الخادم". delete-all-result.png
   14:12:56 DELETE /v1/sdk/conversations -> 200; 14:13:01 local GET -> total 0.
   App returned to the root: "لا توجد محادثات بعد…".
   Force-stop and relaunch: after reload the list is empty;
   14:13:54 local GET -> total 0. The attachment of the deleted conversation -> 404.
   (The first reload after relaunch failed with "تعذّر تحميل السجل": the test proxy
   cannot forward the app's chunked token request. With the phone pointed straight
   at the gateway, "إعادة المحاولة" loaded the empty list.)

6. Deletion during an active call
   Device: NOT TESTED (the local gateway has no LiveKit; no AWS call was placed).
   Focused test apps/nexa_example/test/delete_during_call_test.dart (mock voice):
   while the call page is open no delete action can be reached; a conversation
   reset arriving during the call does not drop the call.

7. Arabic question mark                                                PASS
   Sheet titles on the device: "حذف هذه المحادثة؟", "حذف كل المحادثات؟",
   "مسح ذاكرة الجهاز المؤقتة؟".

NOTED, not changed
- Returning from a chat to the list does not reload the list (a new
  conversation appears only after the next reload).
- At about 14:11:15–14:11:30 the QA app was sent to the background (launcher in
  front, process alive, no crash in logcat); it resumed on the same screen.
  A guard that checks the foreground package stopped the script until then.

CLEAN-UP
QA package uninstalled; `adb reverse` removed; gateway and proxy stopped.
