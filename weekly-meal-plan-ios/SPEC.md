# Weekly Meal Plan — iOS App Spec

A native iOS app for two people (a couple) to share a live shopping list, a
recipe library, a weekly meal plan, and a pantry/spice inventory.

Decisions locked in during spec discussion:
- **Native SwiftUI app**, built and run locally in Xcode on a Mac (not a web
  app / PWA). This spec was written in a cloud sandbox that can't compile
  Swift — hand this file to Claude Code running locally on the Mac to start
  the Xcode project.
- **Sync:** Apple CloudKit, shared between the two of you via `CKShare` (like
  sharing a Note or Reminders list) — no custom backend/server to run or pay
  for.
- **Recipe parsing:** AI-parsed. Pasted text or fetched web pages get sent to
  an LLM to extract structured ingredients/instructions.
- **Build order:** roughly all four pillars (list, recipes, weekly plan,
  inventory) in parallel, but see §7 for a sane compile-order.

---

## 1. Users & sharing model

Two iPhones, two separate Apple IDs (you + your wife). CloudKit's *private*
database is only visible to the owning Apple ID, so cross-account sync
requires **CloudKit Sharing (`CKShare`)**:

- One of you is the data **owner** (holds the canonical record zone).
- The owner shares that zone with the other person via a share link (same
  mechanism as sharing a Reminders list) — accepted once, then syncs live
  from then on, including push-based updates so both phones update near
  instantly without a manual refresh.
- Both of you get full read/write on shared records (add/check off items,
  edit recipes, etc.).

## 2. Core features (v1)

### 2.1 Shared shopping list
- Live-synced across both phones.
- Items added manually, or generated from recipes / the weekly plan.
- Each item tagged with a **category** (produce, dairy, meat, frozen, pantry,
  etc.).
- **Stores:** user-defined list of stores you shop at (e.g. "Trader Joe's",
  "Costco"). Each store has its own **aisle/section order** you configure
  once (drag-to-reorder categories) — the shopping list for that store sorts
  items by that order so you walk the store once, front to back.
- The list is a standing "next week" list: items persist and get added to /
  checked off continuously rather than being wiped each week — checked-off
  items clear, but the list itself carries forward.

### 2.2 Recipe library
Import paths:
- **Paste from Notion** — paste raw copied text; AI parses it into a
  structured recipe.
- **Web URL** (NYT Cooking or any recipe blog) — fetch the page, first look
  for embedded `schema.org/Recipe` structured data (most recipe sites,
  including NYT Cooking, embed this — free, instant, no AI needed). If
  absent, fall back to sending extracted page text to the AI parser.
- **Manual entry** as a fallback for anything.

Each recipe stores: title, source (URL or "pasted"/"manual"), servings,
ingredients (structured: name, quantity, unit, shopping category),
instructions, tags (cuisine/meal type), optional photo, notes.

### 2.3 Weekly meal plan
- Simple week view (breakfast/lunch/dinner, or just "meal" slots per day —
  confirm during build) with recipes assigned to days.
- "Add ingredients to shopping list" per meal or for the whole week at once —
  this is the main bridge between planning and shopping.
- Plan rolls forward; you can plan next week while this week is still active.

### 2.4 Pantry / spice inventory
- Track what you already have on hand (spices, staples, freezer items).
- When adding a recipe's ingredients to the shopping list, cross-reference
  inventory and skip (or flag) items you already have.
- Manually mark items used up / restocked.

## 3. Explicit non-goals for v1
- No social/public sharing beyond the two of you.
- No barcode/receipt scanning.
- No nutrition tracking.
- No Android app.
- No support for more than 2 users/households.

## 4. Architecture

- **Platform:** iOS 17+, SwiftUI, Swift 5.9+.
- **Persistence + sync:** SwiftData (or Core Data) backed by
  `NSPersistentCloudKitContainer`, using a shared CloudKit zone + `CKShare`
  as described in §1.
- **AI recipe parsing:** call an LLM (Claude API) with pasted text or
  extracted page text, asking for structured JSON back (title, servings,
  ingredients array with name/qty/unit/category, instructions array, tags).
  - **Do not embed the API key in the app binary**, even for personal use —
    if this repo or the Xcode project is ever pushed anywhere public, a
    hardcoded key leaks. Use one of:
    a) a tiny serverless proxy (a single Cloudflare Worker/Vercel function
       that holds the key and forwards parse requests), or
    b) a user-supplied key entered in Settings and stored in the iOS
       Keychain.
  Recommend (a) for a smoother experience for both of you; (b) if you'd
  rather avoid standing up any hosted piece at all.
- **Web fetching:** `URLSession` to fetch recipe page HTML; parse
  `<script type="application/ld+json">` blocks for `@type: Recipe` first;
  fall back to AI parsing of the visible article text.

## 5. Data model (sketch)

- `Recipe`: id, title, source, sourceURL?, servings, tags[], notes?, photo?,
  createdAt
- `Ingredient`: id, recipeId, name, quantity, unit, category
- `Store`: id, name, sectionOrder: [Category] (ordered)
- `ShoppingListItem`: id, name, quantity?, unit?, category, isChecked,
  storeId?, sourceRecipeId?
- `PantryItem`: id, name, category, inStock (bool), lastUpdated
- `WeeklyPlanEntry`: id, date, mealSlot (breakfast/lunch/dinner), recipeId

## 6. Open questions to settle when you start building at home

1. Which of you is the CloudKit share **owner**?
2. Meal slots: breakfast/lunch/dinner, or just one "dinner" slot per day
   (simpler, probably matches real usage better)?
3. AI parsing proxy: stand up a tiny serverless function, or keep-it-simple
   with a Keychain-stored personal API key for v1?
4. Apple Developer Program ($99/yr) — needed for CloudKit in production and
   for installs that don't expire every 7 days. Confirm you're enrolled (or
   plan to enroll) before Phase 0.
5. Initial store list + aisle order for each (can configure in-app, but
   good to know going in).

## 7. Suggested build order (phases)

Even building "all at once," you need a working compile order:

1. **Phase 0 — scaffold:** New Xcode project, CloudKit container entitlement,
   prove a `CKShare` works between your two Apple IDs with a trivial shared
   record (e.g. a shared counter) before building real features on top.
2. **Phase 1 — data models:** SwiftData/CloudKit entities from §5.
3. **Phase 2 — shopping list:** list UI, store + section-order config, live
   sync between both phones.
4. **Phase 3 — recipe library:** manual entry + display first, to unblock
   everything downstream.
5. **Phase 4 — recipe import:** paste-to-AI-parse, URL fetch +
   schema.org-first parsing.
6. **Phase 5 — weekly plan:** calendar view + "add to shopping list" action.
7. **Phase 6 — pantry inventory:** cross-reference against shopping list
   generation.
8. **Phase 7 — polish:** app icon, optional widgets/Siri shortcuts, TestFlight
   install on both phones.

## 8. Kickoff prompt for Claude Code on your Mac

When you're home, open this repo (or just this file) in Claude Code locally
and paste something like:

> Read `weekly-meal-plan-ios/SPEC.md` in this repo. Set up a new Xcode
> project for this app per Phase 0 — SwiftUI, iOS 17+, CloudKit container
> with a shared zone, and a trivial `CKShare` test to confirm two Apple IDs
> can read/write the same record before we build anything real. Ask me
> anything from §6 you need answered before starting.
