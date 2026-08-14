import SwiftUI

/// THE SHOP panel — sectioned catalog, VIC TIDIES UP, wallet header. Extracted
/// from LoungeView so shop work stays off room / chrome / missions files.
/// Sections are a map of the room (SHOP_PLAN.md §4): membership is "where
/// does it live," prices ascend inside each aisle, and the water aisle splits
/// into SHALLOW/DEEP sub-bands so the cheap doorway isn't buried.
struct LoungeShopPanel: View {
    let size: CGSize
    let coachOnBuy: Bool
    let shopScrollTarget: String?
    @Binding var tidyConfirm: Bool
    var onClose: () -> Void
    var onBuy: (LoungeItem) -> Void

    @Environment(PlayerStore.self) private var store

    /// One flavor line per catalog item — Vic's voice, shop-row subtitles.
    /// View-layer only (keyed by itemID) so the SwiftData model is untouched.
    private static let shopCaptions: [String: String] = [
        "flamingMug": "THE HOUSE POUR, ON FIRE",
        "umbrellaDrink": "THE UMBRELLA IS LOAD-BEARING",
        "cornerFronds": "EVERY CORNER DESERVES A JUNGLE",
        "palmPlant": "WATERED MOST TUESDAYS",
        "glassFloat": "DRIFTED IN FROM SOMEWHERE",
        "tikiStatue": "SEES ALL. APPROVES OF MOST.",
        "blowfishLamp": "MOOD LIGHTING WITH OPINIONS",
        "recordCredenza": "EXOTICA ON SIDE B",
        "martiniWoman": "HERE SINCE OPENING NIGHT",
        "highballMan": "TIPS IN STORIES",
        "backBarShelf": "WHERE THE GOOD STUFF LIVES",
        "sunsetWindow": "THE SUN NEVER QUITE SETS",
        "suspiciousCat": "SUSPICIOUS OF YOU, SPECIFICALLY",
        "barStools": "FIRST COME, FIRST PERCHED",
        "ceilingFan": "STIRS THE EVENING AROUND",
        "marlin": "CAUGHT FAIR AND SQUARE, MOSTLY",
        "parrot": "HEARS ALL. REPEATS MOST.",
        "neonTikiSign": "YOU'LL KNOW WHEN IT'S ON",
        "aquarium": "MOUNTED, LIT, AND QUIETLY BUSY",
        "plantBush": "FILLING IN NICELY",
        "plantSnake": "THRIVES ON NEGLECT",
        "plantTiered": "TRIMMED TO IMPRESS",
        "loungeRug": "TIES THE WEST WING TOGETHER",
        "highTable": "FOR STANDING-ROOM EVENINGS",
        "bayWindow": "A VIEW WITH COMMITMENT",
        "loungeCouch": "DEEP ENOUGH TO STAY AWHILE",
        "grandPiano": "TAKES REQUESTS AFTER TEN",
        "buoy": "MARKS NOTHING IN PARTICULAR",
        "lagoonDuck": "UNBOTHERED BY THE SHARK",
        "messageBottle": "STILL SEALED. STILL FLOATING.",
        "dolphin": "SHOWS OFF AT SUNSET",
        "seaTurtle": "OLDER THAN THE LOUNGE",
        "sailboat": "IN NO PARTICULAR HURRY",
        "shark": "JUST PASSING THROUGH, PROBABLY",
        "orca": "THE LAGOON'S BIG SHOT",
        "farIsland": "CLOSER THAN IT LOOKS",
        "volcano": "TECHNICALLY DORMANT",
        "yacht": "SOMEBODY'S DOING WELL",
    ]

    /// A run of rows inside a section. Only the water aisle names its bands.
    struct ShopBand {
        let title: String?
        let caption: String?
        let itemIDs: [String]
    }

    /// A shop aisle: Vic-voice header + tagline, rows priced low → high.
    struct ShopSection {
        let title: String
        let caption: String
        let bands: [ShopBand]
        var itemIDs: [String] { bands.flatMap(\.itemIDs) }
    }

    /// The room-map catalog order (SHOP_PLAN.md §4). View-layer only, same
    /// contract as `shopCaptions` — the SwiftData model knows no categories.
    /// Internal (not private) so a test can pin it against the catalog: an
    /// item missing from every section would render NOWHERE.
    static let sections: [ShopSection] = [
        .init(title: "BEHIND THE BAR", caption: "WHERE THE EVENING STARTS",
              bands: [.init(title: nil, caption: nil, itemIDs: [
                "flamingMug", "umbrellaDrink", "barStools",
                "recordCredenza", "backBarShelf", "neonTikiSign"])]),
        .init(title: "A LITTLE GREENERY", caption: "IT'S CALLED ATMOSPHERE",
              bands: [.init(title: nil, caption: nil, itemIDs: [
                "cornerFronds", "plantBush", "plantSnake",
                "plantTiered", "palmPlant"])]),
        .init(title: "THE REGULARS", caption: "COMPANY THAT STAYS",
              bands: [.init(title: nil, caption: nil, itemIDs: [
                "suspiciousCat", "parrot", "martiniWoman", "highballMan"])]),
        .init(title: "WALLS AND RAFTERS", caption: "LOOK UP ONCE IN A WHILE",
              bands: [.init(title: nil, caption: nil, itemIDs: [
                "glassFloat", "blowfishLamp", "ceilingFan",
                "sunsetWindow", "bayWindow", "marlin", "aquarium"])]),
        .init(title: "TAKE THE FLOOR", caption: "THE GOOD FURNITURE",
              bands: [.init(title: nil, caption: nil, itemIDs: [
                "tikiStatue", "loungeRug", "highTable",
                "loungeCouch", "grandPiano"])]),
        .init(title: "OUT ON THE WATER", caption: "THE LAGOON KEEPS ITS OWN HOURS",
              bands: [
                .init(title: "THE SHALLOW END", caption: "IF IT FITS IN A ROCK POOL",
                      itemIDs: ["buoy", "lagoonDuck", "messageBottle",
                                "dolphin", "seaTurtle"]),
                .init(title: "THE DEEP END", caption: "IF IT COULD CAPSIZE THE DUCK",
                      itemIDs: ["sailboat", "shark", "orca",
                                "farIsland", "volcano", "yacht"]),
              ]),
    ]

    /// Panel reading order — the flat id sequence the player scrolls past.
    /// Both the nearest-save pick and the WITHIN REACH jump resolve against
    /// this (not the price-sorted fetch), so ties land on the row the player
    /// actually meets first.
    static let panelOrder: [String] = sections.flatMap(\.itemIDs)

    var body: some View {
        // ONE fetch per render pass: `loungeItems` is a computed SwiftData
        // fetch, so the per-row lookups below index this dictionary instead
        // of re-fetching (~40 fetches/pass before).
        let all = store.loungeItems
        // uniquingKeysWith, never uniqueKeysWithValues: that variant TRAPS on a
        // duplicate key, and a duplicate LoungeItem row is exactly the state
        // PlayerStoreAdversarialTests guards against — the shop must degrade,
        // not crash, if one ever slips through.
        let byID = Dictionary(all.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        let rows = Self.panelOrder.compactMap { byID[$0] }
        let owned = rows.filter(isOwned).count
        // Count what the panel actually RENDERS (deduped, section-mapped),
        // never the raw fetch — otherwise "N OF TOTAL" could promise a row
        // that no aisle shows.
        let total = rows.count
        let nextUp = nearestSaveID(in: rows)
        let reach = withinReachIDs(in: rows)
        return ZStack {
            P.ink.color.opacity(0.55)
                .onTapGesture(perform: onClose)
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("THE SHOP")
                                .font(.custom("Futura-Bold", size: 21, relativeTo: .body))
                                .tracking(3)
                                .foregroundStyle(P.blossom.color)
                            if owned == total {
                                Text("THE ROOM IS COMPLETE. THE CAT APPROVES.")
                                    .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                                    .tracking(1.5)
                                    .foregroundStyle(P.cream.color.opacity(0.8))
                            } else {
                                Text("\(owned) OF \(total) IN THE ROOM")
                                    .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                                    .tracking(1.5)
                                    .foregroundStyle(P.cream.color.opacity(0.8))
                                // Wayfinding: what the SHOP badge promises is
                                // often below the fold, so the header says how
                                // many rows are in reach and jumps to the first.
                                if let first = reach.first {
                                    Button {
                                        // .top, not .center: the arrival frame
                                        // should LEAD with the affordable row,
                                        // not bury it under whatever precedes it.
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            proxy.scrollTo(first, anchor: .top)
                                        }
                                    } label: {
                                        // Reads as a control, not a stat line:
                                        // filled capsule + a 44pt tap target
                                        // (bare 11pt text was ~12pt tall).
                                        Text("\(reach.count) WITHIN REACH ›")
                                            .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                                            .tracking(1.5)
                                            .foregroundStyle(P.ink.color)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(P.torch.color))
                                            .frame(minHeight: 44, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(SoftPressStyle())
                                } else {
                                    Text("EARN POINTS PLAYING ANY GAME")
                                        .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                                        .tracking(1.5)
                                        .foregroundStyle(P.torch.color)
                                }
                            }
                        }
                        Spacer()
                        PointsChip(points: store.points)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(P.woodDark.color)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(Self.sections.enumerated()), id: \.element.title) { index, section in
                                sectionHeader(section, first: index == 0, rows: byID)
                                ForEach(section.bands, id: \.itemIDs.first) { band in
                                    if let title = band.title {
                                        bandHeader(title, caption: band.caption)
                                    }
                                    // Declared order, not fetch order: tied
                                    // prices must render in the designed
                                    // sequence (SHOP_PLAN.md §4).
                                    ForEach(band.itemIDs.compactMap { byID[$0] }, id: \.itemID) { item in
                                        shopRow(item, nextUp: nextUp)
                                            .id(item.itemID)
                                        Rectangle()
                                            .fill(P.woodDark.color.opacity(0.15))
                                            .frame(height: 1)
                                    }
                                }
                            }
                            if !store.itemPositions.isEmpty {
                                Button {
                                    tidyConfirm = true
                                } label: {
                                    Text("VIC TIDIES UP")
                                        .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                                        .tracking(2)
                                        .foregroundStyle(P.rum.color)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                                .alert("Vic likes it how it was.", isPresented: $tidyConfirm) {
                                    Button("TIDY UP", role: .destructive) {
                                        withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                                            store.resetPlacements()
                                        }
                                    }
                                    Button("LEAVE IT", role: .cancel) {}
                                }
                            }
                        }
                    }
                    .onAppear {
                        #if DEBUG
                        // Dev hook: SIMCTL_CHILD_TIKI_SHOP_SCROLL=1 jumps to the
                        // bottom of the catalog for screenshot protocols.
                        if ProcessInfo.processInfo.environment["TIKI_SHOP_SCROLL"] == "1",
                           let last = Self.panelOrder.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                        #endif
                        // Ghost-tap entry: land on the tapped item's row.
                        if let target = shopScrollTarget {
                            proxy.scrollTo(target, anchor: .center)
                        }
                    }
                    .background(P.cream.color)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(P.ink.color, lineWidth: 2)
                )
                .frame(width: size.width * 0.87, height: size.height * 0.66)
            }
        }
    }

    /// Ownership decides owned-ness, placement only mirrors it. `purchase`
    /// guards on `purchasedAt`, so keying rows off placement alone would
    /// regrow a BUY button whose tap silently no-ops — the same bug class
    /// already fixed in `canAffordNewItem`.
    private func isOwned(_ item: LoungeItem) -> Bool {
        item.purchasedAt != nil || store.placedItemIDs.contains(item.itemID)
    }

    /// The Sign's cost is play, not points, and the unclaimed welcome mug is
    /// free — neither can be what a wallet is saving toward.
    private func isBuyableWithPoints(_ item: LoungeItem) -> Bool {
        (item.itemID != PlayerStore.signItemID || store.signUnlocked)
            && (item.itemID != PlayerStore.welcomeGiftItemID || store.welcomeGiftClaimed)
    }

    /// The nearest save: first unowned row in panel order the wallet can't
    /// cover yet.
    private func nearestSaveID(in rows: [LoungeItem]) -> String? {
        rows.first { !isOwned($0) && $0.price > store.points && isBuyableWithPoints($0) }?.itemID
    }

    /// Everything buyable right now, in panel order. The unclaimed gift counts
    /// (it is free), matching `canAffordNewItem` so the SHOP badge and this
    /// count never disagree.
    private func withinReachIDs(in rows: [LoungeItem]) -> [String] {
        rows.filter { item in
            guard !isOwned(item) else { return false }
            if item.itemID == PlayerStore.welcomeGiftItemID, !store.welcomeGiftClaimed { return true }
            return item.price <= store.points && isBuyableWithPoints(item)
        }.map(\.itemID)
    }

    private func sectionHeader(_ section: ShopSection, first: Bool,
                               rows: [String: LoungeItem]) -> some View {
        let ids = section.itemIDs
        let owned = ids.compactMap { rows[$0] }.filter(isOwned).count
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title)
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(2.5)
                    .foregroundStyle(P.rum.color)
                Spacer()
                Text("\(owned) OF \(ids.count)")
                    .font(.custom("Futura-Medium", size: 9, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.woodDark.color.opacity(0.5))
            }
            Text(section.caption)
                .font(.custom("Futura-Medium", size: 9, relativeTo: .body))
                .tracking(1.5)
                .foregroundStyle(P.woodDark.color.opacity(0.45))
        }
        .padding(.horizontal, 16)
        .padding(.top, first ? 14 : 24)
        .padding(.bottom, 8)
    }

    private func bandHeader(_ title: String, caption: String?) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.lagoon.color)
            if let caption {
                Text("· \(caption)")
                    .font(.custom("Futura-Medium", size: 9, relativeTo: .body))
                    .tracking(1.2)
                    .foregroundStyle(P.woodDark.color.opacity(0.4))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func shopRow(_ item: LoungeItem, nextUp: String?) -> some View {
        let owned = isOwned(item)
        let isWelcome = item.itemID == PlayerStore.welcomeGiftItemID
        // Free gift bypass matches the guard in `PlayerStore.purchase(_:)` —
        // the welcome mug is always affordable until claimed.
        let onTheHouse = isWelcome && !store.welcomeGiftClaimed
        let affordable = onTheHouse || store.points >= item.price
        // The Sign is the one play-gated row: visible, priced, not buyable
        // until every game has its first milestone (mirror of `purchase`).
        let lockedSign = item.itemID == PlayerStore.signItemID && !owned && !store.signUnlocked
        return HStack(spacing: 13) {
            LoungeSprites.thumbnail(for: item.itemID)
                .frame(width: 44, height: 44)
                .opacity(lockedSign ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.uppercased())
                    .font(.custom("Futura-Medium", size: 14, relativeTo: .body))
                    .tracking(0.5)
                    .foregroundStyle(P.woodDark.color)
                // Flavor line — hidden on the locked Sign row, whose lock
                // copy already owns the subtitle slot.
                if !lockedSign, let caption = Self.shopCaptions[item.itemID] {
                    Text(caption)
                        .font(.custom("Futura-Medium", size: 10, relativeTo: .body))
                        .tracking(1.2)
                        .foregroundStyle(P.woodDark.color.opacity(0.55))
                }
                if onTheHouse && !owned {
                    Text("FREE")
                        .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                        .tracking(1.5)
                        .foregroundStyle(P.coral.color)
                } else {
                    Text("\(item.price) PTS")
                        .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                        .tracking(1)
                        .foregroundStyle(owned ? P.woodDark.color.opacity(0.4) : Color(red: 0.910, green: 0.702, blue: 0.235))
                }
                // NEXT UP — honest progress toward the nearest save, straight
                // from the live wallet. One row wears it at a time. Held to a
                // single line: the text column is narrow beside the BUY
                // capsule and a wrapped badge orphans its own payoff.
                if !owned, !lockedSign, !affordable, item.itemID == nextUp {
                    HStack(spacing: 6) {
                        Capsule()
                            .fill(P.woodDark.color.opacity(0.15))
                            .frame(width: 48, height: 4)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(P.torch.color)
                                    .frame(width: 48 * min(1, max(0, CGFloat(store.points) / CGFloat(max(1, item.price)))), height: 4)
                            }
                        Text("NEXT UP · \(max(0, item.price - store.points)) TO GO")
                            .font(.custom("Futura-Bold", size: 9, relativeTo: .body))
                            .tracking(1.2)
                            // P.rum, not coral: this is the smallest text in
                            // the panel and it carries the goal readout, so
                            // it needs the section-header's contrast on cream,
                            // not a decorative tint.
                            .foregroundStyle(P.rum.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.top, 2)
                }
                if lockedSign {
                    Text("VIC SAVES THIS FOR REGULARS")
                        .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                        .tracking(1.2)
                        .foregroundStyle(P.coral.color)
                        .padding(.top, 2)
                    if let rung = signRequirement {
                        Text(rung)
                            .font(.custom("Futura-Medium", size: 10, relativeTo: .body))
                            .tracking(1.2)
                            .foregroundStyle(P.woodDark.color.opacity(0.65))
                    }
                }
            }
            Spacer()
            if lockedSign {
                EmptyView()
            } else if owned {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(P.cream.color)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(P.driftwood.color))
            } else {
                Button {
                    onBuy(item)
                } label: {
                    Text("BUY")
                        .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                        .tracking(1.5)
                        .foregroundStyle(P.ink.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(P.torch.color))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(!affordable)
                .opacity(affordable ? 1 : 0.35)
                .overlay {
                    if coachOnBuy, isWelcome {
                        ZStack {
                            CoachPulse(skin: .lounge, diameter: 66)
                            CoachArrow(skin: .lounge, direction: .right, size: 24)
                                .offset(x: -42, y: 0)
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// The Sign's unmet-rung copy: the quickest missing first milestone, in
    /// Vic's voice, cheapest-first. Lines derive from bit 0 of each game's
    /// range in the milestoneMask table (`PlayerStore.recordMilestone`) —
    /// never wallet points, never system-speak.
    private var signRequirement: String? {
        let rungs: [(TikiGame, String)] = [
            (.tikiStacks, "STACK 150 AT THE TOTEM"),
            (.luau, "SCORE 150 AT THE LUAU"),
            (.zombie, "MIX A PIÑA COLADA"),
            (.blueprints, "DRAFT 5 BLUEPRINTS"),
            (.cabanaCipher, "FINISH A MATCHBOOK"),
        ]
        return rungs.first { store.record(for: $0.0).milestoneMask == 0 }?.1
    }
}
