# Todo and focus timer

The Todo feature is optional. The first launch shows the pet. Move the pointer near the pet and select `할 일`.
The menu bar also has `할 일 표시`.

## Add and manage Todos

1. Enter a title in `할 일 추가…` at the top of the list.
2. Press Enter. The new Todo appears right below the field, and the field keeps focus for the next one.
   Open Todos are listed newest first.
3. Select the circle to complete the Todo. The check appears first, then the row moves to `오늘 완료`.

The list keeps open Todos across dates. `오늘 완료` shows only Todos completed on the current local date.
Open that section to undo completion.
Click a title to rename the Todo in place. The caret lands where you click; nothing is selected or swapped, so the row does not move.
Each title is one AppKit field (`InlineTitleField`) that shows two lines with a trailing `…` and edits in place.
Enter saves and Esc restores the old title.
Clicking another title, the add field, or another app also saves. An empty title keeps the old one.
The row menu and context menu also offer `제목 수정`.
The add field and the title editor are ghost inputs with no box or underline.
The add field shows a faint plus and gains a light wash on hover or while a draft exists. An edited title keeps the row wash and shows the caret.

### Long titles

| Where | Rule |
|---|---|
| Length | 1–120 characters after trimming. Hangul syllables and emoji count as one character each. |
| Spacing | Line breaks and runs of spaces, typed or pasted, become one space. |
| Typing | A `n/120` counter appears from 100 characters. Input stops at 120. |
| Add field | Grows to three lines, then scrolls. |
| List rows | Two lines, then a trailing `…`. The tooltip shows the full title. |
| Editing | Up to four lines. Titles of up to two lines keep the row height; longer titles open up while editing. |
| Focus bubble, active card, delete prompt | One line with a trailing `…`. |
| Switch prompt | Each quoted title is cut at 24 characters. |
| Older records | Titles saved before this rule stay as they are until you change them. |

The rule lives in `TodoTitlePolicy` in `TodoState.swift`.

Text fields in the bubble accept ⌘A, ⌘C, ⌘V, ⌘X, ⌘Z, and ⇧⌘Z, including with a Korean input source.
The app has no menu bar, so the bubble panel routes these shortcuts itself, and a hidden Edit menu covers popovers and Settings.
With Full Keyboard Access, Tab reaches each title as a button. VoiceOver offers `완료`, `타이머 시작`, and `삭제` actions on it.
The row menu and context menu also delete a Todo. The row asks for confirmation in place.
Deletion hides the Todo and keeps its sessions. The title tooltip shows the full title.

The bubble sizes itself to its content. Its tail points at the pet.
The header shows the local date and the number of open Todos.

## Bubble size and visibility

The text size button in the header (가가 on a Korean system) and Settings > `할 일` > `말풍선` change the bubble size.
Sizes step like a browser: 80, 90, 100, 110, 125, 150, 175, and 200%. Text and controls are laid out at each size, not scaled as an image.
While the bubble has keyboard focus, ⌘+ (or ⌘=), ⌘−, and ⌘0 also work. A short badge shows the new size.

`표시 방식` keeps the bubble visible (`항상 표시`, the default) or shows it only on pointer hover (`마우스를 올렸을 때`).
In hover mode, move the pointer over the pet to show the bubble. It stays while the pointer is over the bubble and fades out shortly after the pointer leaves.
`상시 투명도` and `호버 시 투명도` work like the pet settings of the same names. 100% is opaque and 0% is invisible.
`상시 투명도` applies in `항상 표시` mode while the pointer is away. `호버 시 투명도` applies while the pointer is over the pet or the bubble.
A bubble at 0% passes clicks through until the pointer shows it again.
Typing, an open popover or menu, an expired countdown, and save errors keep the bubble visible and fully opaque.
Size and visibility are stored in the app preferences, not in the Todo record.

### Compact view

A bubble that stays open can take less room. The header button ⤡ or Settings > `할 일` > `목록 보기` switches the list to the compact view.
The compact view is 260 points wide and shows only up to three open Todos, one line each, with their checkboxes.
The active Todo comes first with its timer. More Todos show as `+N개 더`, which opens the full view.
It has no header: on hover, ⤢ (full view) and ⌄ (back to the focus bubble, while a timer is active) appear in the top-right corner.
The context menu has the same actions.
Right-click a Todo to control its timer from the compact view.
The active Todo offers `일시정지` or `재개` and `종료`. Another Todo offers its saved setting, count-up, and 20 minutes,
without repeating the saved one. A chosen setting becomes the Todo's setting, as in the full view's timer popover.
Starting a Todo while another timer runs asks for confirmation inside the compact bubble.
A timer started from the compact view keeps the compact view, with the active Todo and its time on top.
An ending or an absence needs more room, so it shows its own bubble until answered, then the compact view returns.
After a restart with an active session, the compact view stays open too.
Adding, editing, deleting, and custom durations happen in the full view.
The choice is stored with the other display preferences. Switching saves a title being edited.

## Use a timer

Each Todo starts with a 20-minute setting. The main button starts the selected setting.
The arrow opens a popover. Select 10, 20, or 30 minutes, a custom duration, or count-up.
Custom durations use whole minutes from 1 through 999. Selecting a setting does not start a timer.
Each Todo keeps its own setting.

Starting a timer from the full view opens the compact focus view. It shows the title, a tomato, and the timer.
The ring around the tomato shows the remaining countdown. Count-up has no limit, so it shows the tomato alone in the same place.
A paused timer shows a gray tomato and `일시정지`.
Move the pointer over the view to show pause, resume, and stop controls.
Select the view to open the list. The timer continues while you use the list.
The list shows the active Todo in a card at the top with its own controls.
The header chevron or Esc returns to the compact view.

A countdown stops at zero. The compact expiry view offers extension and finish.
The bubble bounces away from the pet, like a Dock icon asking for attention.
If you were away when it ended, it bounces again at your next keyboard or mouse input.
The extension arrow changes the duration. The main extension button starts that duration in the same session.
Time spent at zero does not count. Finishing a timer leaves its Todo open.
Completing the active Todo finishes its timer first.

Starting another Todo asks for confirmation inside the bubble. The old timer keeps its current state until you select `전환`.
Cancel keeps the old session. Confirmation finishes it and starts one new session.

### Away from the Mac

A running timer pauses itself when you seem to be away: no keyboard or mouse input for 15 minutes, a locked screen, or sleep.
It also takes back the time since your last input, so a timer you forgot to stop does not collect the night.
The input check reads the system idle time and needs no permission.
The bubble stays visible, says how long you were away, and offers three choices.
It bounces at your first input after the absence, or when you unlock the screen.

| Choice | Away time | Timer |
| --- | --- | --- |
| `이어서 재기` | Left out | Runs again |
| `포함해서 재기` | Counted, as if the timer never paused | Runs again. A countdown that passes its limit ends instead |
| `끝내기` | Left out | Session ends |

Until you choose, the timer stays paused and the time stays out of the record.
The card in the list shows the same choices in place of its own controls.
`포함해서 재기` measures with uptime, which stops while the Mac sleeps, so it never adds sleep.
Settings > `할 일` > `자리 비움 감지` sets the idle time to 5, 10, 15, 30, or 60 minutes, or turns detection off.
Off keeps the earlier behavior: only sleep pauses the timer, and nothing is taken back.
The notice lives in memory. After a restart the session is paused as usual.

The bounce copies the macOS Dock, measured frame by frame from a 48-point Dock:
three parabolic hops of 53, 26, and 13 points that last 0.50, 0.32, and 0.22 seconds.
Where the canvas has less room, the bounce is lower and quicker with the same gravity.
Like a critical Dock request, it repeats every 2 seconds until the pointer reaches the bubble or the pet, or you answer.
It stops after five rounds. With Reduce Motion on, the bubble does not bounce.

## Show, hide, and move

The pet and Todo UI use separate panels. Position lock keeps mouse clicks passing through the pet.
The Todo panel and entry button continue to receive clicks.
The Todo panel is a fixed transparent canvas beside the pet, so the bubble animates without the window resizing.
The bubble draws its own shadow, so the shadow follows animations and does not change when the panel takes keyboard focus.
Clicks outside the bubble, and all clicks while it is hidden, pass through to the windows below.
Hover inside the bubble comes from the pointer position and SwiftUI's current layout, not from AppKit tracking areas,
so row actions stay reachable while a title grows during editing or the list scrolls.
Icon buttons and the `…` and size menus show a round wash on hover. Text inputs show a text cursor on hover before the panel is clicked.
macOS ignores cursor changes from an app that is not frontmost, so `BackgroundCursor` enables an undocumented WindowServer property at launch.
It is looked up at run time; if a future macOS removes it, the pointer keeps the arrow until a panel is clicked.
Buttons in the Todo panel work without keyboard focus, so typing stays in the frontmost app.
The panel takes keyboard focus only when you open it with `할 일`, select the input field, rename a Todo, or enter a custom duration.
The Todo panel follows pet movement and size changes. It uses the pet display's visible frame.
It first tries the space above the pet, then the sides and the space below.
The Todo panel uses the same window level and Space policy as the pet.
Pointer avoidance stops while you operate the Todo panel or entry button.

`할 일 숨기기` hides the Todo UI and keeps the timer running. Hiding the pet hides both panels.
Use `할 일 표시` in the menu bar to restore the pet and list.
Settings has a `할 일` tab with feature and visibility controls.

## Time and local storage

The production record file is:

```text
~/Library/Application Support/TypingPet/todo-state.json
```

Development builds use `~/Library/Application Support/TypingPetDev/todo-state.json`.
See [local development](DEVELOPMENT.md) for the separate app identity and runtime command.

Settings > `할 일` > `기록 데이터 열기` reveals the active file in Finder.
The file holds schema version 1, feature preferences, Todos, sessions, and extension segments.
Dates use UTC ISO 8601. The completed list uses the current local calendar.
Actual seconds keep fractions. Each session total equals the sum of its segments.

The engine measures monotonic elapsed time. It does not count timer callbacks.
Countdown segments clamp at their configured duration. Paused time and expired waiting time do not count.
The app saves each state change and checkpoints running time about every five seconds.
Writes use atomic replacement. A damaged or unsupported file blocks changes and remains unchanged.
Save errors appear in the panel. A failed save during normal quit offers retry, cancel, or quit without saving.

Sleep pauses and saves the active timer. Wake does not resume it.
Normal quit saves a paused session. A restart restores a running checkpoint as paused.
The app does not add offline time. A crash can lose the time since the last successful checkpoint.
Copy the JSON file to make a backup. Quit the app before you restore or edit it.
The app has no account, server, sync, notifications, or statistics screen.

## Tests

With full Xcode selected:

```sh
swift test
swift build -c release
```

The tests cover accumulation, extension, pause, absence, switching, local midnight, JSON storage, and recovery.
The existing pet tests remain in the test target.
CI runs tests and a release build on macOS for `main`, `feat/**`, and pull requests.

Command Line Tools can lack XCTest. Run the separate executable checks in that environment:

```sh
./scripts/check_todo.sh
```

These checks use temporary files and injected clocks. They do not use your Todo record.
They supplement the XCTest suite. They do not replace it.

For an isolated debug UI test, set `TYPINGPET_TODO_TEST_PATH` to a temporary JSON path.
Run a debug build with `--todo-preview --show-todos` to skip input permission prompts and open the list.
Use a separate bundle identifier to keep pet preferences separate.
Release builds ignore these test options and always use the normal record path.

Manual checks still require real displays, Space changes, sleep/wake, and input permission changes.
A successful compile does not prove those checks.
