PaperRoute - TBC 2.5.3 Mailbox Helper
Version: 1.0.1

Install:
1. Unzip PaperRoute.zip.
2. Put the PaperRoute folder into:
   World of Warcraft/_classic_/Interface/AddOns/
   or your server client's Interface/AddOns folder.
3. Restart WoW or type /reload.
4. Enable PaperRoute on the AddOns screen.

What it does:
- Adds a PaperRoute "Clear All" button to the Inbox.
- Clear All first collects mail gold and attachments.
- After attachments/gold are gone, it deletes mail with no attachments/money, such as AH sale pending notices.
- COD and GM mail are skipped.
- Right-click a tradeable inventory item while the Send Mail tab is open to attach it to the next free mail attachment slot.

Slash commands:
/paperroute
/proute
/paperroute clear

Notes:
- This addon cannot create bag space. If bags are full, Blizzard's mailbox API may stop attachment pickup until you clear room.
- The cleanup runs slowly on purpose to avoid mailbox throttling and index-shift bugs.

Changelog 1.0.1:
- Moved the PaperRoute Clear All button above Blizzard's Open All button so it no longer overlaps the bottom-right Next arrow.
