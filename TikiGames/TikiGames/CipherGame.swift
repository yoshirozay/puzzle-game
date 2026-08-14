import Foundation
import Observation

/// Cabana Cipher — hangman-style letter guessing over a substitution cipher.
/// Each phrase is encrypted with a deterministic per-phrase cipher (so a
/// SwiftData-restored run re-derives the same board) and the unsolved tiles
/// show symbols — same symbol, same letter — as a pattern-hint layer. Input
/// is Wheel of Fortune-simple: tap any letter; if it is in the phrase it
/// fills every position at once, if not it is a mistake and strikes out on
/// the keyboard. Every board opens with its busiest letter revealed free
/// (the house pour) and a category label keeps recognition fair. The round
/// ends in defeat at `mistakeCap` misses (shared lives economy).
@Observable
final class CipherGame {
    /// Wrong letters that end the phrase — the fifth goes cold.
    static let mistakeCap = 5
    /// A themed set of six phrases — the content unit of the drawer.
    struct Matchbook: Identifiable {
        let id: String
        let name: String
        let phrases: [String]
    }

    /// Category shown on the strike-strip above the board — the Wheel of
    /// Fortune-style genre hint that keeps recognition fair.
    enum CipherCategory: String, CaseIterable {
        case oldWisdom = "OLD WISDOM"
        case workHustle = "WORK & HUSTLE"
        case moneyTalk = "MONEY TALK"
        case loveLuck = "LOVE & LUCK"
        case critters = "CRITTERS"
        case weather = "WEATHER"
        case eatsDrinks = "EATS & DRINKS"
        case modernTalk = "MODERN TALK"
        case seaShore = "SEA & SHORE"
        case gameOn = "GAME ON"
    }

    /// Famous sayings, ALL CAPS A-Z and spaces — every phrase graded A under
    /// CIPHER_PHRASE_RUBRIC.md (recognition-first: obscurity is unfair in a
    /// lives economy). Books 1-16 keep their original ids so pre-expansion
    /// save indices still line up; the catalog and wall order are generated
    /// from CIPHER_PHRASES_DRAFT.md — edit that doc and re-generate rather
    /// than hand-editing this literal.
    static let matchbooks: [Matchbook] = [
        Matchbook(id: "house", name: "HOUSE RULES", phrases: [
            "THE EARLY BIRD GETS THE WORM",
            "PIECE OF CAKE",
            "WHEN PIGS FLY",
            "LOVE IS BLIND",
            "COME RAIN OR SHINE",
            "GO THE EXTRA MILE",
        ]),
        Matchbook(id: "regulars", name: "THE REGULARS", phrases: [
            "PRACTICE MAKES PERFECT",
            "IT IS WHAT IT IS",
            "HOLD YOUR HORSES",
            "SAVE IT FOR A RAINY DAY",
            "SPILL THE BEANS",
            "ROLL UP YOUR SLEEVES",
        ]),
        Matchbook(id: "nightair", name: "NIGHT AIR", phrases: [
            "BETTER SAFE THAN SORRY",
            "NO PAIN NO GAIN",
            "TIME IS MONEY",
            "WHEN IT RAINS IT POURS",
            "IN A NUTSHELL",
            "MANY HANDS MAKE LIGHT WORK",
        ]),
        Matchbook(id: "lastcall", name: "LAST CALL", phrases: [
            "KNOWLEDGE IS POWER",
            "READ THE ROOM",
            "CASH IS KING",
            "BEGINNERS LUCK",
            "COOL AS A CUCUMBER",
            "BACK TO THE DRAWING BOARD",
        ]),
        Matchbook(id: "vic", name: "VICS ADVICE", phrases: [
            "HONESTY IS THE BEST POLICY",
            "LONG STORY SHORT",
            "BREAK THE BANK",
            "LOVE CONQUERS ALL",
            "LET SLEEPING DOGS LIE",
            "STRIKE WHILE THE IRON IS HOT",
        ]),
        Matchbook(id: "lagoon", name: "THE LAGOON", phrases: [
            "LOOK BEFORE YOU LEAP",
            "EASIER SAID THAN DONE",
            "RAGS TO RICHES",
            "LUCK OF THE DRAW",
            "A FISH OUT OF WATER",
            "EVERY CLOUD HAS A SILVER LINING",
        ]),
        Matchbook(id: "band", name: "THE BAND", phrases: [
            "ONE DAY AT A TIME",
            "PENNY FOR YOUR THOUGHTS",
            "HOME IS WHERE THE HEART IS",
            "CURIOSITY KILLED THE CAT",
            "TAKE A RAIN CHECK",
            "THE CREAM OF THE CROP",
        ]),
        Matchbook(id: "cat", name: "THE CAT", phrases: [
            "ANOTHER DAY ANOTHER DOLLAR",
            "THIRD TIME IS THE CHARM",
            "THE ELEPHANT IN THE ROOM",
            "THE CALM BEFORE THE STORM",
            "THE BEST THING SINCE SLICED BREAD",
            "BLOOD SWEAT AND TEARS",
        ]),
        Matchbook(id: "weather", name: "WEATHER REPORT", phrases: [
            "ACTIONS SPEAK LOUDER THAN WORDS",
            "THE LUCK OF THE IRISH",
            "EVERY DOG HAS ITS DAY",
            "THE TIP OF THE ICEBERG",
            "HAVE YOUR CAKE AND EAT IT TOO",
            "MAKE HAY WHILE THE SUN SHINES",
        ]),
        Matchbook(id: "menu", name: "THE MENU", phrases: [
            "SLOW AND STEADY WINS THE RACE",
            "TRUST THE PROCESS",
            "LET THE CAT OUT OF THE BAG",
            "CHASING RAINBOWS",
            "AN APPLE A DAY KEEPS THE DOCTOR AWAY",
            "BURNING THE MIDNIGHT OIL",
        ]),
        Matchbook(id: "islandtime", name: "ISLAND TIME", phrases: [
            "NEVER JUDGE A BOOK BY ITS COVER",
            "OUT OF SIGHT OUT OF MIND",
            "MORE BANG FOR YOUR BUCK",
            "THROW CAUTION TO THE WIND",
            "TOO MANY COOKS SPOIL THE BROTH",
            "THE SQUEAKY WHEEL GETS THE GREASE",
        ]),
        Matchbook(id: "totem", name: "THE TOTEM", phrases: [
            "MEASURE TWICE CUT ONCE",
            "BETTER LATE THAN NEVER",
            "A PENNY SAVED IS A PENNY EARNED",
            "MATCH MADE IN HEAVEN",
            "BITE OFF MORE THAN YOU CAN CHEW",
            "JACK OF ALL TRADES MASTER OF NONE",
        ]),
        Matchbook(id: "castaway", name: "CASTAWAY MAIL", phrases: [
            "WHEN IN ROME DO AS THE ROMANS DO",
            "THINK OUTSIDE THE BOX",
            "THE BEST THINGS IN LIFE ARE FREE",
            "WEAR YOUR HEART ON YOUR SLEEVE",
            "THE WORLD IS YOUR OYSTER",
            "IF YOU WANT IT DONE RIGHT DO IT YOURSELF",
        ]),
        Matchbook(id: "volcano", name: "THE VOLCANO SPEAKS", phrases: [
            "THE PEN IS MIGHTIER THAN THE SWORD",
            "THE BALL IS IN YOUR COURT",
            "PUT YOUR MONEY WHERE YOUR MOUTH IS",
            "ALL IS FAIR IN LOVE AND WAR",
            "KILL TWO BIRDS WITH ONE STONE",
            "LIGHTNING NEVER STRIKES TWICE",
        ]),
        Matchbook(id: "moonlight", name: "MOONLIGHT SWIM", phrases: [
            "WHAT GOES AROUND COMES AROUND",
            "A FOOL AND HIS MONEY ARE SOON PARTED",
            "ABSENCE MAKES THE HEART GROW FONDER",
            "BIRDS OF A FEATHER FLOCK TOGETHER",
            "APRIL SHOWERS BRING MAY FLOWERS",
            "VARIETY IS THE SPICE OF LIFE",
        ]),
        Matchbook(id: "philosophy", name: "THE PHILOSOPHY SHELF", phrases: [
            "FORTUNE FAVORS THE BOLD",
            "BORN WITH A SILVER SPOON IN YOUR MOUTH",
            "WILD GOOSE CHASE",
            "RED SKY AT NIGHT SAILORS DELIGHT",
            "ALL WORK AND NO PLAY MAKES JACK A DULL BOY",
            "THE PROOF IS IN THE PUDDING",
        ]),
        Matchbook(id: "outrigger", name: "THE OUTRIGGER", phrases: [
            "A RISING TIDE LIFTS ALL BOATS",
            "BEAT THEM AT THEIR OWN GAME",
            "THE BENEFIT OF THE DOUBT",
            "THE GRASS IS ALWAYS GREENER ON THE OTHER SIDE",
            "WHEN THE GOING GETS TOUGH THE TOUGH GET GOING",
            "MONEY BURNS A HOLE IN YOUR POCKET",
        ]),
        Matchbook(id: "conch", name: "THE CONCH", phrases: [
            "UP THE CREEK WITHOUT A PADDLE",
            "KNOCK IT OUT OF THE PARK",
            "LOVE IS A TWO WAY STREET",
            "THE STRAW THAT BROKE THE CAMELS BACK",
            "EVERYTHING UNDER THE SUN",
            "NO USE CRYING OVER SPILLED MILK",
        ]),
        Matchbook(id: "driftwood", name: "DRIFTWOOD", phrases: [
            "TIME AND TIDE WAIT FOR NO MAN",
            "TAKE ONE FOR THE TEAM",
            "FAKE IT TILL YOU MAKE IT",
            "A CHAIN IS ONLY AS STRONG AS ITS WEAKEST LINK",
            "WHERE THERE IS A WILL THERE IS A WAY",
            "LAUGHING ALL THE WAY TO THE BANK",
        ]),
        Matchbook(id: "tradewinds", name: "THE TRADE WINDS", phrases: [
            "PLENTY OF FISH IN THE SEA",
            "PLAY YOUR CARDS RIGHT",
            "A BLESSING IN DISGUISE",
            "A LEOPARD NEVER CHANGES ITS SPOTS",
            "COME HELL OR HIGH WATER",
            "TAKE IT WITH A GRAIN OF SALT",
        ]),
        Matchbook(id: "hammock", name: "THE HAMMOCK", phrases: [
            "WHATEVER FLOATS YOUR BOAT",
            "STEP UP TO THE PLATE",
            "HIT THE NAIL ON THE HEAD",
            "THE APPLE NEVER FALLS FAR FROM THE TREE",
            "BURN THE CANDLE AT BOTH ENDS",
            "MONEY MAKES THE WORLD GO ROUND",
        ]),
        Matchbook(id: "torchlight", name: "TORCHLIGHT", phrases: [
            "BATTEN DOWN THE HATCHES",
            "THE WHOLE NINE YARDS",
            "THANK YOUR LUCKY STARS",
            "STRAIGHT FROM THE HORSES MOUTH",
            "THE DOG DAYS OF SUMMER",
            "WAKE UP AND SMELL THE COFFEE",
        ]),
        Matchbook(id: "reef", name: "THE REEF", phrases: [
            "WATER UNDER THE BRIDGE",
            "LEVEL PLAYING FIELD",
            "THE BEST OF BOTH WORLDS",
            "BEAUTY IS IN THE EYE OF THE BEHOLDER",
            "THE DEVIL IS IN THE DETAILS",
            "A DAY LATE AND A DOLLAR SHORT",
        ]),
        Matchbook(id: "lowtide", name: "LOW TIDE", phrases: [
            "A SHOT ACROSS THE BOW",
            "PAR FOR THE COURSE",
            "HAPPY WIFE HAPPY LIFE",
            "THE CANARY IN THE COAL MINE",
            "THE EYE OF THE STORM",
            "THE ICING ON THE CAKE",
        ]),
        Matchbook(id: "pineapple", name: "THE PINEAPPLE", phrases: [
            "THAT SHIP HAS SAILED",
            "THROW IN THE TOWEL",
            "IT TAKES TWO TO TANGO",
            "OUT OF THE FRYING PAN INTO THE FIRE",
            "PUT YOUR BEST FOOT FORWARD",
            "MONEY IS THE ROOT OF ALL EVIL",
        ]),
        Matchbook(id: "coconutgrove", name: "COCONUT GROVE", phrases: [
            "THE COAST IS CLEAR",
            "MOVE THE GOALPOSTS",
            "LIGHTNING IN A BOTTLE",
            "TAKE THE BULL BY THE HORNS",
            "ONCE IN A BLUE MOON",
            "WALKING ON EGGSHELLS",
        ]),
        Matchbook(id: "sandbar", name: "THE SANDBAR", phrases: [
            "DEAD IN THE WATER",
            "THE GLOVES ARE OFF",
            "AT THE END OF THE DAY",
            "NEVER BITE THE HAND THAT FEEDS YOU",
            "PRACTICE WHAT YOU PREACH",
            "THE CUSTOMER IS ALWAYS RIGHT",
        ]),
        Matchbook(id: "highseason", name: "HIGH SEASON", phrases: [
            "ALL HANDS ON DECK",
            "GAME SET AND MATCH",
            "THE MORE THE MERRIER",
            "AN ELEPHANT NEVER FORGETS",
            "HEAD IN THE CLOUDS",
            "A TOUGH NUT TO CRACK",
        ]),
        Matchbook(id: "veranda", name: "THE VERANDA", phrases: [
            "GET YOUR FEET WET",
            "DOWN FOR THE COUNT",
            "NO NEWS IS GOOD NEWS",
            "WHERE THERE IS SMOKE THERE IS FIRE",
            "GET THE SHOW ON THE ROAD",
            "YOU GET WHAT YOU PAY FOR",
        ]),
        Matchbook(id: "seaglass", name: "SEA GLASS", phrases: [
            "IN THE SAME BOAT",
            "SAVED BY THE BELL",
            "LOVE AT FIRST SIGHT",
            "UNTIL THE COWS COME HOME",
            "HEAT OF THE MOMENT",
            "SELL LIKE HOTCAKES",
        ]),
        Matchbook(id: "lantern", name: "THE LANTERN", phrases: [
            "GO WITH THE FLOW",
            "DOWN TO THE WIRE",
            "THROWN UNDER THE BUS",
            "GOOD THINGS COME TO THOSE WHO WAIT",
            "WORK SMARTER NOT HARDER",
            "WORTH ITS WEIGHT IN GOLD",
        ]),
        Matchbook(id: "coralcove", name: "CORAL COVE", phrases: [
            "UNCHARTED WATERS",
            "FULL COURT PRESS",
            "THE APPLE OF MY EYE",
            "THE BIRDS AND THE BEES",
            "THE PERFECT STORM",
            "A LOT ON MY PLATE",
        ]),
        Matchbook(id: "catamaran", name: "THE CATAMARAN", phrases: [
            "X MARKS THE SPOT",
            "THE HOME STRETCH",
            "THE REST IS HISTORY",
            "TWO HEADS ARE BETTER THAN ONE",
            "NOSE TO THE GRINDSTONE",
            "PENNY WISE POUND FOOLISH",
        ]),
        Matchbook(id: "mangoseason", name: "MANGO SEASON", phrases: [
            "MISSED THE BOAT",
            "ACE IN THE HOLE",
            "CROSS YOUR FINGERS",
            "A LITTLE BIRD TOLD ME",
            "RAIN ON MY PARADE",
            "NOT MY CUP OF TEA",
        ]),
        Matchbook(id: "boardwalk", name: "THE BOARDWALK", phrases: [
            "TEST THE WATERS",
            "CALL THE SHOTS",
            "SPEAK OF THE DEVIL",
            "A STITCH IN TIME SAVES NINE",
            "HIT THE GROUND RUNNING",
            "BRING HOME THE BACON",
        ]),
        Matchbook(id: "pearl", name: "THE PEARL", phrases: [
            "TAKE THE PLUNGE",
            "SHOW YOUR HAND",
            "OPPOSITES ATTRACT",
            "BULL IN A CHINA SHOP",
            "A RAY OF SUNSHINE",
            "BREAD AND BUTTER",
        ]),
        Matchbook(id: "gecko", name: "THE GECKO", phrases: [
            "SMOOTH SAILING",
            "LAST BUT NOT LEAST",
            "DROP THE BALL",
            "THE TRUTH WILL SET YOU FREE",
            "NO REST FOR THE WEARY",
            "PAY THROUGH THE NOSE",
        ]),
        Matchbook(id: "sundown", name: "SUNDOWN", phrases: [
            "DOWN THE HATCH",
            "IN SEVENTH HEAVEN",
            "MONKEY SEE MONKEY DO",
            "UNDER THE WEATHER",
            "FOOD FOR THOUGHT",
            "LOW HANGING FRUIT",
        ]),
        Matchbook(id: "atoll", name: "THE ATOLL", phrases: [
            "WALK THE PLANK",
            "ROLL THE DICE",
            "ALL IS WELL THAT ENDS WELL",
            "THE SHOW MUST GO ON",
            "PUT IN MY TWO CENTS",
            "LOVE THY NEIGHBOR",
        ]),
        Matchbook(id: "bambooroom", name: "THE BAMBOO ROOM", phrases: [
            "LIKE A DUCK TO WATER",
            "WEATHER THE STORM",
            "CUT THE MUSTARD",
            "ON THE SAME PAGE",
            "ANCHORS AWEIGH",
            "GAME CHANGER",
        ]),
        Matchbook(id: "saltspray", name: "SALT SPRAY", phrases: [
            "HINDSIGHT IS TWENTY TWENTY",
            "MOVERS AND SHAKERS",
            "TIGHTEN YOUR BELT",
            "TWO PEAS IN A POD",
            "BIGGER FISH TO FRY",
            "TURN UP THE HEAT",
        ]),
        Matchbook(id: "hibiscus", name: "THE HIBISCUS", phrases: [
            "EAT HUMBLE PIE",
            "CUT TO THE CHASE",
            "ROCK THE BOAT",
            "ON THE ROPES",
            "IF THE SHOE FITS WEAR IT",
            "BACK TO SQUARE ONE",
        ]),
        Matchbook(id: "galley", name: "THE GALLEY", phrases: [
            "HIGHWAY ROBBERY",
            "HEAD OVER HEELS",
            "STUBBORN AS A MULE",
            "STEAL MY THUNDER",
            "COUCH POTATO",
            "THE BOTTOM LINE",
        ]),
        Matchbook(id: "emberglow", name: "EMBER GLOW", phrases: [
            "LOOSE CANNON",
            "POKER FACE",
            "EVERY ROSE HAS ITS THORN",
            "GO BIG OR GO HOME",
            "STRIKE IT RICH",
            "STROKE OF LUCK",
        ]),
        Matchbook(id: "compassrose", name: "THE COMPASS ROSE", phrases: [
            "EAGER BEAVER",
            "BREAK THE ICE",
            "SOUR GRAPES",
            "OUT OF THE LOOP",
            "SINK OR SWIM",
            "WILD CARD",
        ]),
        Matchbook(id: "sirensong", name: "SIREN SONG", phrases: [
            "STILL WATERS RUN DEEP",
            "IRONS IN THE FIRE",
            "FOOT THE BILL",
            "KNOCK ON WOOD",
            "DARK HORSE",
            "RIGHT AS RAIN",
        ]),
        Matchbook(id: "lookout", name: "THE LOOKOUT", phrases: [
            "IN A PICKLE",
            "GOOD VIBES ONLY",
            "HIGH AND DRY",
            "HAIL MARY",
            "OLD HABITS DIE HARD",
            "PULL YOUR WEIGHT",
        ]),
        Matchbook(id: "maitai", name: "THE MAI TAI", phrases: [
            "GRAVY TRAIN",
            "ON CLOUD NINE",
            "PUPPY LOVE",
            "SNOWED UNDER",
            "EASY AS PIE",
            "THE NEW NORMAL",
        ]),
        Matchbook(id: "horizon", name: "THE HORIZON", phrases: [
            "LOST AT SEA",
            "SLAM DUNK",
            "IGNORANCE IS BLISS",
            "LEARN THE ROPES",
            "NEST EGG",
            "BREAK A LEG",
        ]),
        Matchbook(id: "closingtime", name: "CLOSING TIME", phrases: [
            "CRY WOLF",
            "ON THIN ICE",
            "BIG CHEESE",
            "KEEP IT REAL",
            "MAKE WAVES",
            "ON A ROLL",
        ]),
    ]

    static let phrases: [String] = matchbooks.flatMap(\.phrases)

    /// Parallel to `phrases` (flat wall order): one category per phrase.
    static let categories: [CipherCategory] = [
        .oldWisdom, .eatsDrinks, .critters, .loveLuck, .weather, .workHustle,
        .oldWisdom, .modernTalk, .critters, .weather, .eatsDrinks, .workHustle,
        .oldWisdom, .modernTalk, .moneyTalk, .weather, .eatsDrinks, .workHustle,
        .oldWisdom, .modernTalk, .moneyTalk, .loveLuck, .eatsDrinks, .workHustle,
        .oldWisdom, .modernTalk, .moneyTalk, .loveLuck, .critters, .workHustle,
        .oldWisdom, .modernTalk, .moneyTalk, .loveLuck, .critters, .weather,
        .modernTalk, .moneyTalk, .loveLuck, .critters, .weather, .eatsDrinks,
        .moneyTalk, .loveLuck, .critters, .weather, .eatsDrinks, .workHustle,
        .oldWisdom, .loveLuck, .critters, .weather, .eatsDrinks, .workHustle,
        .oldWisdom, .modernTalk, .critters, .weather, .eatsDrinks, .workHustle,
        .oldWisdom, .modernTalk, .moneyTalk, .weather, .eatsDrinks, .workHustle,
        .oldWisdom, .modernTalk, .moneyTalk, .loveLuck, .eatsDrinks, .workHustle,
        .oldWisdom, .modernTalk, .moneyTalk, .loveLuck, .critters, .workHustle,
        .oldWisdom, .gameOn, .moneyTalk, .loveLuck, .critters, .weather,
        .modernTalk, .moneyTalk, .loveLuck, .critters, .weather, .eatsDrinks,
        .loveLuck, .moneyTalk, .critters, .weather, .workHustle, .eatsDrinks,
        .seaShore, .gameOn, .modernTalk, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .gameOn, .loveLuck, .critters, .weather, .eatsDrinks,
        .seaShore, .gameOn, .modernTalk, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .gameOn, .loveLuck, .critters, .weather, .eatsDrinks,
        .seaShore, .gameOn, .modernTalk, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .gameOn, .loveLuck, .critters, .weather, .eatsDrinks,
        .seaShore, .gameOn, .modernTalk, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .gameOn, .loveLuck, .critters, .weather, .eatsDrinks,
        .seaShore, .gameOn, .modernTalk, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .gameOn, .loveLuck, .critters, .weather, .eatsDrinks,
        .seaShore, .gameOn, .modernTalk, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .gameOn, .loveLuck, .critters, .weather, .eatsDrinks,
        .seaShore, .gameOn, .modernTalk, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .gameOn, .loveLuck, .critters, .weather, .eatsDrinks,
        .seaShore, .gameOn, .modernTalk, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .gameOn, .loveLuck, .critters, .weather, .eatsDrinks,
        .seaShore, .gameOn, .modernTalk, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .gameOn, .loveLuck, .critters, .weather, .eatsDrinks,
        .seaShore, .gameOn, .modernTalk, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .gameOn, .loveLuck, .critters, .weather, .eatsDrinks,
        .seaShore, .modernTalk, .gameOn, .oldWisdom, .workHustle, .moneyTalk,
        .seaShore, .loveLuck, .critters, .weather, .eatsDrinks, .modernTalk,
        .seaShore, .gameOn, .oldWisdom, .workHustle, .moneyTalk, .loveLuck,
        .critters, .weather, .eatsDrinks, .modernTalk, .seaShore, .gameOn,
        .oldWisdom, .workHustle, .moneyTalk, .loveLuck, .critters, .weather,
        .eatsDrinks, .modernTalk, .seaShore, .gameOn, .oldWisdom, .workHustle,
        .moneyTalk, .loveLuck, .critters, .weather, .eatsDrinks, .modernTalk,
        .seaShore, .gameOn, .oldWisdom, .workHustle, .moneyTalk, .loveLuck,
        .critters, .weather, .eatsDrinks, .modernTalk, .seaShore, .gameOn,
        .oldWisdom, .workHustle, .moneyTalk, .loveLuck, .critters, .weather,
        .eatsDrinks, .modernTalk, .seaShore, .gameOn, .oldWisdom, .workHustle,
        .moneyTalk, .loveLuck, .critters, .weather, .eatsDrinks, .modernTalk,
        .seaShore, .gameOn, .oldWisdom, .workHustle, .moneyTalk, .loveLuck,
        .critters, .weather, .eatsDrinks, .modernTalk, .seaShore, .gameOn,
    ]

    var currentCategory: CipherCategory {
        Self.categories[phraseIndex % Self.phrases.count]
    }

    /// The matchbook containing the phrase at a (wrapped) flat index.
    static func matchbook(forPhraseAt index: Int) -> (book: Matchbook, number: Int) {
        // Swift's % keeps the sign; fold negatives so number stays 1-based.
        var i = ((index % phrases.count) + phrases.count) % phrases.count
        for book in matchbooks {
            if i < book.phrases.count { return (book, i + 1) }
            i -= book.phrases.count
        }
        return (matchbooks[0], 1)
    }

    var currentMatchbook: (book: Matchbook, number: Int) {
        Self.matchbook(forPhraseAt: phraseIndex)
    }

    private(set) var phraseIndex = 0
    private(set) var mapping: [Character: Character] = [:]           // plain -> cipher
    private(set) var reverse: [Character: Character] = [:]  // cipher -> plain (autoplay + guess checks)
    /// Confirmed cipher -> plain assignments.
    private(set) var solvedLetters: [Character: Character] = [:]
    /// Plain letters guessed and absent from the phrase — struck out on the
    /// keyboard. A miss is globally wrong (hangman model), unlike the old
    /// per-tile cryptogram where a wrong tile could still be right elsewhere.
    private(set) var misses: Set<Character> = []
    private(set) var mistakes = 0
    private(set) var hints = 0
    private(set) var mistakeBeat = 0
    private(set) var lockBeat = 0
    private(set) var isComplete = false
    /// True once mistakes hit `mistakeCap` — the phrase goes cold.
    private(set) var isFailed = false
    private(set) var solvedCount = 0
    /// Coach boards never trip the mistake cap — the script owns the board.
    private(set) var coachShield = false

    /// Arms or clears the coach shield. Clearing re-evaluates the cap.
    func setCoachShield(_ on: Bool) {
        coachShield = on
        if !on { evaluateFailure() }
    }

    /// Wipes counters a scripted coach board accrued (stray taps and charged
    /// hints during the teach). Without this, misses collected under the
    /// shield would detonate into an instant defeat — and a real life spend —
    /// the moment the shield drops.
    func clearCoachResidue() {
        mistakes = 0
        hints = 0
        misses = []
        isFailed = false
    }
    /// yyyy-mm-dd of the last free Vic's Tip (persisted; view owns "today").
    var lastFreeHintDay: String?
    var lastRunSummary: RunSummary?

    var phrase: String { Self.phrases[phraseIndex % Self.phrases.count] }

    /// Cipher form of the current phrase (spaces preserved).
    var cipherText: String {
        String(phrase.map { $0 == " " ? " " : (mapping[$0] ?? $0) })
    }

    func plainFor(cipherLetter: Character) -> Character? {
        solvedLetters[cipherLetter]
    }

    var uniqueCipherLetters: Set<Character> {
        Set(cipherText.filter { $0 != " " })
    }

    /// Plain letters already locked in (dim these on the keyboard).
    var usedPlainLetters: Set<Character> {
        Set(solvedLetters.values)
    }

    // MARK: setup

    func begin(index: Int, restoring solved: [Character: Character]? = nil, mistakes: Int = 0, hints: Int = 0, misses: Set<Character> = []) {
        phraseIndex = index
        buildMapping()
        // Drop restored pairs that contradict this phrase's derived cipher —
        // guards corrupt payloads and pre-matchbook saves whose in-progress
        // index wrapped mod 24 instead of the expanded list.
        let restored = solved ?? [:]
        solvedLetters = restored.filter { reverse[$0.key] == $0.value }
        // A save whose assignments ALL contradict the mapping was written
        // against different content (catalog swap): keep the wall position
        // but hand back a clean board — inherited mistakes against a phrase
        // the player never saw would be unfair.
        let contentDrift = !restored.isEmpty && solvedLetters.isEmpty
        // A board with nothing locked gets the house pour — fresh phrases,
        // post-solve restores, and pre-pour saves alike. Boards restored
        // mid-phrase already carry theirs in the assignments.
        if solvedLetters.isEmpty { seedStartingReveal() }
        self.mistakes = contentDrift ? 0 : mistakes
        self.hints = contentDrift ? 0 : hints
        self.misses = contentDrift ? [] : misses
        isComplete = false
        isFailed = false
        lastRunSummary = nil
        checkComplete()
        // Mid-round kill at the cap re-arms defeat so force-quit can't
        // launder a cold phrase.
        evaluateFailure()
    }

    /// Cipher letters whose board symbols are filled/hollow twins of each
    /// other (● ○, ■ □, … — see cipherSymbols in CipherView). A board that
    /// shows both members of a pair invites a fill-state misread of the
    /// "same symbol = same letter" rule, so buildMapping avoids seating both
    /// on one phrase whenever the roll budget allows.
    static let confusableCipherPairs: [(Character, Character)] = [
        ("A", "B"), ("C", "D"), ("E", "F"), ("G", "H"), ("I", "J"),
        ("K", "L"), ("Q", "R"), ("S", "T"), ("U", "V"), ("X", "Y"),
    ]

    /// Deterministic substitution: seeded LCG shuffle re-rolled until no
    /// phrase letter maps to itself, then a deterministic REPAIR pass moves
    /// twin-pair collisions onto unused cipher letters. Re-rolling alone
    /// left twin pairs on 84 of 600 boards (pre-repair replica sweep,
    /// 2026-07-31); the constructive swap
    /// resolves them outright — the board never asks a player to tell ● from
    /// ○ across two different letters.
    private func buildMapping() {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var seed = UInt64(phraseIndex &* 2654435761 &+ 97)
        func next() -> UInt64 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return seed >> 33
        }
        let letters = Set(phrase.filter { $0 != " " })
        var candidate: [Character: Character] = Dictionary(
            uniqueKeysWithValues: zip(alphabet, alphabet.reversed())
        )
        for _ in 0..<64 {
            var shuffled = alphabet
            for i in (1..<shuffled.count).reversed() {
                let j = Int(next() % UInt64(i + 1))
                shuffled.swapAt(i, j)
            }
            var roll: [Character: Character] = [:]
            for (i, ch) in alphabet.enumerated() { roll[ch] = shuffled[i] }
            if !letters.contains(where: { roll[$0] == $0 }) {
                candidate = roll
                break
            }
        }
        // Repair: for each twin pair with both members on phrase letters,
        // re-seat the second member's plain letter on a safe unused cipher
        // letter (one whose own twin is also off-board). All scans run in
        // alphabet order so the result is deterministic.
        var used = Set(letters.compactMap { candidate[$0] })
        let twin: [Character: Character] = Dictionary(uniqueKeysWithValues:
            Self.confusableCipherPairs.flatMap { [($0.0, $0.1), ($0.1, $0.0)] })
        // Re-seating member `m` can fail only when the sole safe target IS
        // the plain letter being moved (identity guard) — in that case the
        // pair's other member re-seats instead, which is provably safe for
        // phrases of <= 16 distinct letters. 17+ distinct keeps one pair by
        // pigeonhole (only 16 twin-free cipher seats exist).
        func reseat(_ member: Character) -> Bool {
            guard let p = alphabet.first(where: { letters.contains($0) && candidate[$0] == member }),
                  let u = alphabet.first(where: { ch in
                      !used.contains(ch) && ch != p
                          && (twin[ch].map { !used.contains($0) } ?? true)
                  }),
                  let q = alphabet.first(where: { candidate[$0] == u })
            else { return false }
            candidate[p] = u
            candidate[q] = member   // q is off-board (u was unused), identity-safe
            used.remove(member)
            used.insert(u)
            return true
        }
        for (a, b) in Self.confusableCipherPairs where used.contains(a) && used.contains(b) {
            if !reseat(b) { _ = reseat(a) }
        }
        mapping = candidate
        reverse = Dictionary(uniqueKeysWithValues: candidate.map { ($1, $0) })
    }

    // MARK: play

    /// Hangman-style guess: a plain letter that appears in the phrase locks
    /// every tile it owns at once; a letter absent from the phrase is a
    /// mistake and strikes out on the keyboard. Re-guessing a solved or
    /// struck letter is inert. Returns true when the guess locked in.
    @discardableResult
    func guess(_ plain: Character) -> Bool {
        guard !isComplete, !isFailed,
              !usedPlainLetters.contains(plain), !misses.contains(plain) else { return false }
        // mapping only covers A-Z, so spaces and non-letters fall through to
        // the mistake path — the engine stays hostile to junk input even
        // though the view's keyboard is A-Z only.
        if phrase.contains(plain), let cipher = mapping[plain] {
            solvedLetters[cipher] = plain
            lockBeat += 1
            checkComplete()
            return true
        }
        mistakes += 1
        misses.insert(plain)
        mistakeBeat += 1
        evaluateFailure()
        return false
    }

    /// Reveals the most connected unsolved letter (most occurrences — the
    /// generous choice). Charged hints raise the score cost; Vic's daily tip
    /// passes charged: false.
    func hint(charged: Bool = true) {
        guard !isComplete, !isFailed else { return }
        guard let cipher = mostConnectedUnsolved(), let plain = reverse[cipher] else { return }
        if charged { hints += 1 }
        solvedLetters[cipher] = plain
        lockBeat += 1
        checkComplete()
    }

    /// Ends the phrase at the cap unless the coach owns the board.
    private func evaluateFailure() {
        guard !coachShield, !isComplete, mistakes >= Self.mistakeCap else { return }
        isFailed = true
    }

    /// The house pour: reveals the most-connected letter so the opening move
    /// is a deduction instead of a blind stab (a wrong guess here teaches
    /// almost nothing but still costs a mistake). Uncharged — hints/mistakes
    /// stay 0, so CLEAN STRIKE and the score law are untouched.
    private func seedStartingReveal() {
        guard let cipher = mostConnectedUnsolved(), let plain = reverse[cipher] else { return }
        solvedLetters[cipher] = plain
        lockBeat += 1
    }

    private func mostConnectedUnsolved() -> Character? {
        var counts: [Character: Int] = [:]
        for ch in cipherText where ch != " " && solvedLetters[ch] == nil {
            counts[ch, default: 0] += 1
        }
        return counts.max { a, b in
            a.value != b.value ? a.value < b.value : String(a.key) > String(b.key)
        }?.key
    }

    private func checkComplete() {
        if uniqueCipherLetters.allSatisfy({ solvedLetters[$0] != nil }) {
            isComplete = true
            solvedCount += 1
        }
    }

    /// CLEAN STRIKE: no mistakes, no charged hints — strikes a match (+15).
    var isCleanSolve: Bool { mistakes == 0 && hints == 0 }

    /// Letters-only length x3, minus mistake and hint costs, floor 20;
    /// a clean solve strikes a match on top (+15).
    var completionScore: Int {
        let letters = phrase.filter { $0 != " " }.count
        return max(20, letters * 3 - mistakes * 10 - hints * 15) + (isCleanSolve ? 15 : 0)
    }

    /// Coach helper: the most frequent still-hidden plain letter — a
    /// guaranteed hit for the tutorial's "tap a letter" beat.
    var coachTargetPlain: Character? {
        mostConnectedUnsolved().flatMap { reverse[$0] }
    }

    func advance() {
        begin(index: phraseIndex + 1)
    }

    #if DEBUG
    /// Staging hook (SIMCTL_CHILD_TIKI_CIPHER_SOLVED=<n>): n phrases already
    /// solved, fresh board at phrase n — pennants, book banners, and LAST
    /// CALL all stage on demand.
    func debugSeedSolved(_ n: Int) {
        solvedCount = n
        begin(index: n)
    }

    /// Dev hook (TIKI_CIPHER_MISTAKES=<n>): stages the live counter so
    /// one-remaining emphasis and the defeat beat can be sim-verified.
    func debugStageMistakes(_ n: Int) {
        guard !isComplete else { return }
        mistakes = max(0, n)
        mistakeBeat += 1
        isFailed = false
        evaluateFailure()
    }
    #endif

    // MARK: persistence

    struct SavePayload: Codable {
        var seenHowTo: Bool
        var phraseIndex: Int
        var solvedCount: Int
        var assignments: [String: String]
        var mistakes: Int
        var hints: Int
        /// Optional so pre-tip payloads decode.
        var lastFreeHintDay: String?
        /// Struck-out keyboard letters. Optional so pre-hangman payloads decode.
        var misses: [String]?
    }

    func payload(seenHowTo: Bool) -> String {
        let pairs = solvedLetters.map { (String($0.key), String($0.value)) }
        let state = SavePayload(
            seenHowTo: seenHowTo,
            // A completed phrase persists as the NEXT phrase, fresh: restoring
            // must never re-serve a phrase whose answers the player just saw
            // (deterministic ciphers would also re-pay the same solve).
            phraseIndex: isComplete ? phraseIndex + 1 : phraseIndex,
            solvedCount: solvedCount,
            assignments: isComplete ? [:] : Dictionary(uniqueKeysWithValues: pairs),
            mistakes: isComplete ? 0 : mistakes,
            hints: isComplete ? 0 : hints,
            lastFreeHintDay: lastFreeHintDay,
            misses: isComplete ? [] : misses.map(String.init).sorted()
        )
        guard let data = try? JSONEncoder().encode(state) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    @discardableResult
    func restore(from json: String?) -> SavePayload? {
        guard let json, let data = json.data(using: .utf8),
              let state = try? JSONDecoder().decode(SavePayload.self, from: data) else {
            begin(index: 0)
            return nil
        }
        // Clamped like the other counters: a hostile save near Int.max would
        // otherwise overflow-trap on checkComplete's next increment.
        solvedCount = min(max(0, state.solvedCount), 1_000_000)
        lastFreeHintDay = state.lastFreeHintDay
        // Corrupt/hostile payload hygiene — legitimate saves never hit these:
        // single-Character pairs only (multi-char junk would truncate into
        // colliding keys and trap uniqueKeysWithValues), index non-negative
        // and far below anything real play reaches (negatives trap the seed
        // math, Int.max traps advance()), counters non-negative and small
        // enough that the score math can't overflow or inflate.
        let solved = Dictionary(
            state.assignments.compactMap { k, v -> (Character, Character)? in
                guard k.count == 1, let ck = k.first, v.count == 1, let cv = v.first else { return nil }
                return (ck, cv)
            },
            uniquingKeysWith: { a, _ in a }
        )
        let index = (0..<1_000_000).contains(state.phraseIndex) ? state.phraseIndex : 0
        // Same single-Character hygiene as assignments; junk entries drop.
        let misses = Set((state.misses ?? []).compactMap { $0.count == 1 ? $0.first : nil })
        // A pre-hangman save (no misses key) carries mistakes accrued under
        // the DEAD cursor rules — right-letter-wrong-tile guesses that have
        // no meaning here and no struck keys to show for them. Drop them
        // rather than render MISSES 2/5 over a clean keyboard.
        let preHangman = state.misses == nil
        begin(index: index,
              restoring: solved,
              mistakes: preHangman ? 0 : min(max(0, state.mistakes), 100_000),
              hints: preHangman ? 0 : min(max(0, state.hints), 100_000),
              misses: misses)
        return state
    }
}
