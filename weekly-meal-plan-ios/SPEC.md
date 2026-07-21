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
- **Recipe parsing:** AI-parsed via a small serverless proxy (keeps the API
  key off both phones). Pasted text or fetched web pages get sent to an LLM
  to extract structured ingredients/instructions.
- **Weekly plan:** one meal slot per day (dinner) — not separate
  breakfast/lunch/dinner slots.
- **Shopping list:** same ingredient appearing in multiple recipes in a week
  gets **combined into one line** with summed quantity, not listed
  separately. See §2.1 for what this requires.
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

**Primary workflow** — the app is used in this order each week:
1. **Plan** — assign recipes to dinner slots for the week (§2.3).
2. **Pick stores** — choose which of your configured stores (§2.1) you're
   actually shopping at this week; you don't have to hit all of them every
   week.
3. **Generate** — build the shopping list from that week's recipes, each
   item routed to one of the stores you picked (§2.1's generation logic) and
   sorted by that store's aisle order.

### 2.1 Shared shopping list
- Live-synced across both phones.
- Items added manually, or generated from recipes / the weekly plan.
- Each item tagged with a **category** (produce, dairy, meat, frozen, pantry,
  etc.).
- **Stores:** user-defined list of stores you shop at. Your actual list:
  Whole Foods, Avedano's, Billingsgate, Safeway, The Good Life, and a
  catch-all "Other" for occasional trips elsewhere. Each store has its own
  **aisle/section order** you configure once (drag-to-reorder categories) —
  the shopping list for that store sorts items by that order so you walk the
  store once, front to back.
  - Note: a full-service grocery store (Whole Foods, Safeway, The Good Life)
    will use most/all categories in its order. A specialty single-category
    shop (Avedano's = butcher, Billingsgate = seafood) just needs the one or
    two categories it actually carries — the data model (§5, `Store.
    sectionOrder`) already supports a short list, no special-casing needed.
  - "Other" has no fixed section order; items assigned to it just show
    unsorted, or sorted by the app-wide default category order.
- **Store admin screen:** where you manage all of the above —
  add/edit/remove stores, and for each store, drag-and-drop reorder its
  categories into shopping order.
- **Preferred store per category:** also in the admin screen, set a default
  store for each grocery category — e.g. Meat → Avedano's, Seafood →
  Billingsgate, Produce → Whole Foods. This is what auto-routes each
  ingredient to a store when the list is generated (see §6 for the default
  category list, split into `Meat` / `Seafood` specifically so each can have
  its own preferred store).
- **List generation logic:** for the stores picked that week (see workflow
  above), each merged ingredient (quantity-merging rules above) looks up its
  category's preferred store:
  - If that store was picked for this week → item lands there, sorted by
    that store's category order.
  - If its preferred store wasn't picked this week → item lands in an
    **Unassigned** section at the top of the list, so you manually assign it
    to one of this week's chosen stores (or to "Other") with a tap.
  - Any item can also be manually re-assigned to a different store than its
    category default, for one-off overrides.
- The list is a standing "next week" list: items persist and get added to /
  checked off continuously rather than being wiped each week — checked-off
  items clear, but the list itself carries forward.
- **Quantity merging:** when two recipes need the same ingredient in the
  same week, the list shows one combined line (e.g. "Onions: 3") instead of
  duplicates. This requires:
  - **Canonical ingredient names.** The AI parser must normalize ingredient
    names during import (e.g. "yellow onion", "onion, diced" → `onion`) so
    matching is reliable. Store both the canonical name (used for merging)
    and the original text (shown in the recipe view).
  - **Unit families for safe conversion.** Only auto-sum within a compatible
    unit family: volume (tsp/tbsp/cup/fl oz), weight (oz/lb/g), or count
    (whole items). Never guess across families (e.g. "1 onion" + "1 cup
    diced onion") — when units don't reconcile, show both quantities on one
    line for the human to eyeball ("Onions: 2 whole + 1 cup diced") rather
    than silently dropping or mis-adding one.

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
- Simple week view, **one meal (dinner) slot per day**, with a recipe
  assigned to each day. (Breakfast/lunch tracking is out of scope for v1 —
  revisit only if it turns out you actually want to plan those too.)
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
- **AI recipe parsing:** call an LLM (Claude API) through a small serverless
  proxy (one Cloudflare Worker or Vercel function that holds the API key and
  forwards parse requests) — **never embed the key in the app binary**, even
  for personal use, since a hardcoded key in a pushed repo/Xcode project
  leaks. Send pasted text or extracted page text; ask for structured JSON
  back: title, servings, ingredients array (original text, canonical name,
  qty, unit, unit family, shopping category), instructions array, tags.
  The parser prompt is responsible for producing the **canonical ingredient
  name** and **unit family** used for shopping-list merging (§2.1) — get
  this right in the parser rather than trying to reconcile inconsistent
  names later in the app.
- **Web fetching:** `URLSession` to fetch recipe page HTML; parse
  `<script type="application/ld+json">` blocks for `@type: Recipe` first;
  fall back to AI parsing of the visible article text.

## 5. Data model (sketch)

- `Recipe`: id, title, source, sourceURL?, servings, tags[], notes?, photo?,
  createdAt
- `Ingredient`: id, recipeId, originalText, canonicalName, quantity, unit,
  unitFamily (volume/weight/count), category
- `Store`: id, name, sectionOrder: [Category] (ordered)
- `CategoryPreference`: category, preferredStoreId (admin-configured default
  routing, e.g. Meat → Avedano's)
- `ShoppingListItem`: id, canonicalName, displayQuantities: [(quantity, unit)]
  (one entry per unit family present, so mismatched units show side by side
  per §2.1), category, isChecked, storeId? (resolved from
  `CategoryPreference`, or nil while Unassigned, or manually overridden),
  sourceRecipeIds: [Recipe]
- `PantryItem`: id, canonicalName, category, inStock (bool), lastUpdated
- `WeeklyPlanEntry`: id, date, recipeId (one dinner slot per day)

## 6. Open questions to settle when you start building at home

1. **CloudKit share owner** — whose Apple ID holds the canonical zone that
   gets shared to the other phone. Deliberately left open; decide together
   before Phase 0 (whoever's phone you set up first is the natural owner).
2. **Apple Developer Program** ($99/yr) — needed for CloudKit in production
   and for installs that don't expire every 7 days. Confirm you're enrolled
   (or plan to enroll) before Phase 0.
3. ~~Initial store list~~ — **resolved:** Whole Foods, Avedano's,
   Billingsgate, Safeway, The Good Life, Other (see §2.1). Aisle/section
   order per store still to be configured in-app.
4. **Serverless proxy hosting** — where the AI-parsing function lives
   (Cloudflare Workers and Vercel both have free tiers that comfortably
   cover two people's recipe imports). Pick whichever you already have an
   account with.
5. **Default grocery category taxonomy** — draft below; adjust as needed.
   `Meat` and `Seafood` are split (rather than one "Meat & Seafood" category)
   specifically so each can get its own preferred store:
   Produce, Dairy & Eggs, Meat, Seafood, Frozen, Bakery, Pantry/Dry Goods,
   Spices & Condiments, Beverages, Household/Other.
   Suggested starting preferences given your stores: Meat → Avedano's,
   Seafood → Billingsgate, everything else → whichever of Whole
   Foods/Safeway/The Good Life you tend to default to — confirm at home.

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
