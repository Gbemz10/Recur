import { and, eq, inArray, isNull, or, sql } from 'drizzle-orm';
import { db } from '../../db/client.js';
import { merchants, rawTransactions, userCategoryRules } from '../../db/schema.js';

/**
 * Local, rule-based transaction categorizer.
 *
 * Mono sells a Transaction Categorisation API built for exactly this, and it
 * is almost certainly better than what is below. It is also activation-gated
 * per business with pricing that is not public, so it cannot be a launch
 * dependency. This engine is therefore the real v1, and Mono's answer is
 * treated as a stronger signal to layer in if and when it is switched on
 * (see `MONO_CATEGORY_MAP` and the precedence rules in `resolveCategory`).
 * That ordering is deliberate: the feature has to work on day one without a
 * commercial conversation, and has to get better without a rewrite.
 *
 * Precedence, weakest to strongest: RULE -> MONO -> USER. A user correction
 * is never recomputed, which is why `category_source` is stored alongside the
 * answer rather than just the answer itself.
 */

type SpendCategory = (typeof rawTransactions.$inferSelect)['spendCategory'];
type Merchant = typeof merchants.$inferSelect;

// Ordered most specific to most generic, and matched in this order: the first
// hit wins. Ordering is load-bearing. "TRANSFER" appears in a great many
// narrations that are not transfers ("TRANSFER TO PIGGYVEST" is savings), so
// the narrower buckets have to get their chance first.
//
// Keywords are matched against the normalized narration, so they are written
// without punctuation or digits.
const KEYWORD_RULES: [NonNullable<SpendCategory>, string[]][] = [
  // Savings and investment platforms read as transfers at the bank, so they
  // have to be claimed before the TRANSFERS bucket sees them.
  ['SAVINGS', [
    'PIGGYVEST', 'PIGGY VEST', 'COWRYWISE', 'RISEVEST', 'RISE VEST', 'BAMBOO', 'TROVE', 'CHAKA',
    'STANBIC IBTC ASSET', 'ARM INVEST', 'MERISTEM', 'FIXED DEPOSIT', 'SAVINGS PLAN', 'INVESTMENT',
  ]],

  // Same reasoning: loan repayments are debits to a fintech that would
  // otherwise look like an ordinary transfer.
  ['LOANS', [
    'CARBON', 'FAIRMONEY', 'FAIR MONEY', 'RENMONEY', 'REN MONEY', 'AELLA', 'OKASH', 'PALMCREDIT',
    'BRANCH INTL', 'QUICKCHECK', 'LOAN REPAYMENT', 'LOAN', 'REPAYMENT', 'CREDITVILLE',
  ]],

  ['EDUCATION', [
    'SCHOOL FEES', 'TUITION', 'WAEC', 'JAMB', 'NECO', 'UDEMY', 'COURSERA', 'ALTSCHOOL',
    'UNIVERSITY', 'POLYTECHNIC', 'ACADEMY', 'TUTOR', 'LESSON', 'EXAM FEE',
  ]],

  ['HEALTH', [
    'PHARMACY', 'MEDPLUS', 'HEALTHPLUS', 'HEALTH PLUS', 'HOSPITAL', 'CLINIC', 'MEDICAL', 'DENTAL',
    'OPTICAL', 'DIAGNOSTIC', 'LABORATORY', 'HMO', 'RELIANCE HEALTH', 'DRUG',
  ]],

  ['ENTERTAINMENT', [
    'NETFLIX', 'SPOTIFY', 'SHOWMAX', 'APPLE MUSIC', 'YOUTUBE', 'PRIME VIDEO', 'AUDIOMACK', 'BOOMPLAY',
    'FILMHOUSE', 'SILVERBIRD', 'GENESIS CINEMA', 'CINEMA', 'PLAYSTATION', 'STEAM GAMES', 'XBOX',
    'CANVA', 'OPENAI', 'CHATGPT', 'SPOTIFY AB', 'ICLOUD', 'GOOGLE ONE',
  ]],

  // Airtime, data, power and pay-TV all sit under Bills, which is how people
  // actually think about them, rather than split across a telecom bucket.
  ['BILLS', [
    'DSTV', 'GOTV', 'STARTIMES', 'MULTICHOICE',
    'MTN', 'GLO', 'AIRTEL', 'MOBILE', 'ETISALAT', 'AIRTIME', 'RECHARGE', 'DATA BUNDLE', 'DATA PLAN',
    'IKEDC', 'EKEDC', 'AEDC', 'PHED', 'KEDCO', 'IBEDC', 'JEDC', 'EEDC', 'NEPA', 'PHCN',
    'ELECTRICITY', 'PREPAID METER', 'WATER BOARD', 'WASTE', 'LAWMA', 'RENT', 'SERVICE CHARGE',
    'SPECTRANET', 'SMILE COMMS', 'STARLINK', 'INTERNET', 'SUBSCRIPTION',
  ]],

  ['TRANSPORT', [
    'BOLT', 'UBER', 'TAXIFY', 'GOKADA', 'MAXNG', 'MAX NG', 'RIDE', 'LAGRIDE',
    'NNPC', 'TOTAL ENERGIES', 'TOTALENERGIES', 'OANDO', 'MOBIL', 'CONOIL', 'ARDOVA', 'FORTE OIL',
    'FILLING STATION', 'PETROL', 'FUEL', 'DIESEL', 'PMS',
    'AIR PEACE', 'ARIK', 'IBOM AIR', 'GREEN AFRICA', 'DANA AIR', 'FLIGHT', 'BRT', 'TRANSPORT', 'PARKING',
  ]],

  ['FOOD', [
    'CHICKEN REPUBLIC', 'KFC', 'DOMINOS', 'PIZZA', 'MR BIGGS', 'TANTALIZERS', 'SWEET SENSATION',
    'COLD STONE', 'THE PLACE', 'KILIMANJARO', 'BUKKA', 'EATERY', 'RESTAURANT', 'CAFE', 'FOOD',
    'SHOPRITE', 'SPAR', 'MARKET SQUARE', 'EBEANO', 'PRINCE EBEANO', 'JUSTRITE', 'ADDIDE',
    'GROCER', 'SUPERMARKET', 'PROVISION', 'FARMS', 'CHOWDECK', 'GLOVO', 'JUMIA FOOD',
  ]],

  ['SHOPPING', [
    'JUMIA', 'KONGA', 'SLOT SYSTEMS', 'SLOT NG', 'ALIEXPRESS', 'AMAZON', 'EBAY', 'TEMU', 'SHEIN',
    'BOUTIQUE', 'FASHION', 'CLOTHING', 'STORE', 'MALL', 'SUPERSTORE', 'ELECTRONICS', 'PAYPORTE',
  ]],

  // Deliberately last of the real categories: these words are the most
  // generic in Nigerian narrations and would otherwise swallow everything
  // above them.
  ['TRANSFERS', [
    'TRANSFER TO', 'TRF TO', 'TRF', 'XFER', 'SENT TO', 'TO ACCT', 'NIP TRANSFER', 'NIP',
    'CASH WITHDRAWAL', 'ATM WITHDRAWAL', 'POS WITHDRAWAL', 'WITHDRAWAL', 'ATM', 'POS ',
    'OPAY', 'PALMPAY', 'MONIEPOINT', 'KUDA', 'PAYSTACK', 'FLUTTERWAVE', 'TRANSFER',
  ]],
];

// Mono's own categories, lowercased, mapped down onto Recur's eleven. Anything
// Mono returns that is not listed here resolves to null rather than OTHER, so
// an unrecognised provider label falls through to the local rules instead of
// being confidently mislabelled as miscellaneous.
const MONO_CATEGORY_MAP: Record<string, NonNullable<SpendCategory>> = {
  food: 'FOOD', groceries: 'FOOD', restaurant: 'FOOD', 'food and drinks': 'FOOD',
  transport: 'TRANSPORT', transportation: 'TRANSPORT', travel: 'TRANSPORT', fuel: 'TRANSPORT',
  utility: 'BILLS', utilities: 'BILLS', bills: 'BILLS', airtime: 'BILLS', data: 'BILLS',
  rent: 'BILLS', 'cable tv': 'BILLS', internet: 'BILLS', electricity: 'BILLS',
  entertainment: 'ENTERTAINMENT', subscription: 'ENTERTAINMENT', subscriptions: 'ENTERTAINMENT',
  gaming: 'ENTERTAINMENT',
  health: 'HEALTH', healthcare: 'HEALTH', medical: 'HEALTH', pharmacy: 'HEALTH',
  shopping: 'SHOPPING', retail: 'SHOPPING', ecommerce: 'SHOPPING', clothing: 'SHOPPING',
  transfer: 'TRANSFERS', transfers: 'TRANSFERS', withdrawal: 'TRANSFERS', cash: 'TRANSFERS',
  savings: 'SAVINGS', investment: 'SAVINGS', investments: 'SAVINGS',
  loan: 'LOANS', loans: 'LOANS', credit: 'LOANS',
  education: 'EDUCATION', school: 'EDUCATION', tuition: 'EDUCATION',
  // Mono has a `betting` category. It has no Recur bucket of its own, and
  // inventing one for v1 would mean a category most users never see; it lands
  // in Entertainment, which is where a budget for it would sit anyway.
  betting: 'ENTERTAINMENT', gambling: 'ENTERTAINMENT',
};

// The subscription taxonomy the merchants table already uses, mapped onto the
// spending one. Reusing that table is the whole reason a merchant match is
// worth more than a keyword hit: those rows are curated.
const MERCHANT_CATEGORY_MAP: Record<string, NonNullable<SpendCategory>> = {
  STREAMING: 'ENTERTAINMENT',
  // Consumer software subscriptions have no bucket of their own in a
  // taxonomy this coarse. Entertainment is where a Netflix-adjacent spend
  // review expects to find them.
  SOFTWARE: 'ENTERTAINMENT',
  TELECOM: 'BILLS',
  FITNESS: 'HEALTH',
  FINANCE: 'SAVINGS',
  // OTHER carries no information, so it is left unmapped on purpose and the
  // keyword pass gets its turn.
};

/** Uppercase, strip long digit runs (references, account and phone numbers), collapse whitespace. */
export function normalizeNarration(raw: string): string {
  return raw
    .toUpperCase()
    .replace(/\d{3,}/g, ' ')
    .replace(/[^A-Z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * The key a user's correction is stored against. Deliberately coarser than
 * the narration: the first three meaningful tokens of the normalized string,
 * which is enough to identify a merchant while staying stable across the
 * per-transaction reference numbers and branch codes that make every raw
 * narration unique.
 */
export function matchKeyFor(narration: string): string {
  const words = normalizeNarration(narration)
    .split(' ')
    .filter((w) => w.length > 1 && !/^\d+$/.test(w));
  return words.slice(0, 3).join(' ');
}

function titleCase(text: string): string {
  return text
    .toLowerCase()
    .split(' ')
    .filter(Boolean)
    .map((w) => w[0]!.toUpperCase() + w.slice(1))
    .join(' ');
}

/** Matches a narration against the curated merchant table, same approach the detection engine uses. */
export function matchMerchant(narration: string, merchantList: Merchant[]): Merchant | null {
  const upper = narration.toUpperCase();
  for (const merchant of merchantList) {
    const domainKeyword = merchant.domain.split('.')[0]?.toUpperCase();
    const slugKeyword = merchant.slug.replace(/_/g, ' ').toUpperCase();
    if (
      (domainKeyword && domainKeyword.length > 2 && upper.includes(domainKeyword)) ||
      upper.includes(slugKeyword) ||
      upper.includes(merchant.name.toUpperCase())
    ) {
      return merchant;
    }
  }
  return null;
}

/** A readable counterparty for the UI, e.g. "NETFLIX.COM 41725LAGOS NG" -> "Netflix". */
export function extractPayee(narration: string, merchant: Merchant | null): string {
  if (merchant) return merchant.name;
  const normalized = normalizeNarration(narration);
  if (!normalized) return 'Unknown';
  // Drop the leading channel noise banks prepend before the actual payee.
  const cleaned = normalized
    .replace(/^(POS|ATM|NIP|TRF|WEB|USSD|MOB|TRANSFER TO|TRANSFER FROM|PAYMENT TO)\s+/g, '')
    .trim();
  const words = (cleaned || normalized).split(' ').filter((w) => w.length > 1).slice(0, 3);
  return titleCase(words.join(' ')) || 'Unknown';
}

/** First keyword bucket whose terms appear in the normalized narration. */
export function categorizeByKeyword(narration: string): NonNullable<SpendCategory> | null {
  const normalized = ` ${normalizeNarration(narration)} `;
  for (const [category, keywords] of KEYWORD_RULES) {
    for (const keyword of keywords) {
      if (normalized.includes(keyword)) return category;
    }
  }
  return null;
}

export function mapMonoCategory(raw: string | null): NonNullable<SpendCategory> | null {
  if (!raw) return null;
  return MONO_CATEGORY_MAP[raw.trim().toLowerCase()] ?? null;
}

export interface ResolveInput {
  narration: string;
  monoCategory: string | null;
  merchantList: Merchant[];
  /** matchKey -> category, from this user's saved corrections. */
  userRules: Map<string, NonNullable<SpendCategory>>;
}

export interface ResolveResult {
  category: NonNullable<SpendCategory>;
  source: 'RULE' | 'MONO' | 'USER';
  payee: string;
}

/**
 * Resolves one transaction. Order of authority:
 *   1. a rule the user themselves created for this merchant
 *   2. Mono's category, when it maps onto a bucket we recognise
 *   3. the curated merchants table
 *   4. keyword rules
 *   5. OTHER
 * Steps 3 and 4 both report as RULE: they are the same local pass from the
 * client's point of view, and collapsing them keeps the source enum about
 * authority rather than implementation detail.
 */
export function resolveCategory(input: ResolveInput): ResolveResult {
  const merchant = matchMerchant(input.narration, input.merchantList);
  const payee = extractPayee(input.narration, merchant);

  const userRule = input.userRules.get(matchKeyFor(input.narration));
  if (userRule) return { category: userRule, source: 'USER', payee };

  const mono = mapMonoCategory(input.monoCategory);
  if (mono) return { category: mono, source: 'MONO', payee };

  if (merchant) {
    const mapped = MERCHANT_CATEGORY_MAP[merchant.category];
    if (mapped) return { category: mapped, source: 'RULE', payee };
  }

  return { category: categorizeByKeyword(input.narration) ?? 'OTHER', source: 'RULE', payee };
}

/**
 * Categorizes a user's transactions in place.
 *
 * Only touches rows this engine is allowed to own: those never categorized,
 * and those last categorized by RULE or MONO. A row whose `category_source`
 * is USER is skipped entirely, so re-running this after every sync can never
 * walk back a correction someone made by hand.
 *
 * Writes back in one statement via UPDATE ... FROM (VALUES ...) rather than a
 * query per row. The detection engine still loops (see the note in its own
 * file about per-user subscription counts being small); transaction volume is
 * a different order of magnitude, so it is worth doing properly here.
 */
export async function categorizeTransactionsForUser(
  userId: string,
  options: { includeUserCategorized?: boolean } = {},
): Promise<{ categorized: number }> {
  const [pending, merchantList, rules] = await Promise.all([
    db
      .select({
        id: rawTransactions.id,
        narration: rawTransactions.narration,
        monoCategory: rawTransactions.monoCategory,
      })
      .from(rawTransactions)
      .where(
        and(
          eq(rawTransactions.userId, userId),
          options.includeUserCategorized
            ? undefined
            : or(
                isNull(rawTransactions.categorySource),
                inArray(rawTransactions.categorySource, ['RULE', 'MONO']),
              ),
        ),
      ),
    // Ordered, for the same reason the detection engine orders it:
    // matchMerchant returns the first keyword hit and Postgres guarantees no
    // row order without an ORDER BY, so two merchants that could both match a
    // narration must resolve the same way on every run.
    db.select().from(merchants).orderBy(merchants.slug),
    db
      .select({ matchKey: userCategoryRules.matchKey, category: userCategoryRules.category })
      .from(userCategoryRules)
      .where(eq(userCategoryRules.userId, userId)),
  ]);

  if (pending.length === 0) return { categorized: 0 };

  const userRules = new Map(rules.map((r) => [r.matchKey, r.category]));

  const resolved = pending.map((txn) => ({
    id: txn.id,
    ...resolveCategory({
      narration: txn.narration,
      monoCategory: txn.monoCategory,
      merchantList,
      userRules,
    }),
  }));

  // Chunked so a first sync of a few thousand transactions never builds a
  // single statement with more bind parameters than Postgres will accept.
  const CHUNK = 500;
  for (let i = 0; i < resolved.length; i += CHUNK) {
    const chunk = resolved.slice(i, i + CHUNK);
    const values = chunk.map(
      (r) => sql`(${r.id}::uuid, ${r.category}::spending_category, ${r.source}::category_source, ${r.payee})`,
    );
    await db.execute(sql`
      UPDATE raw_transactions AS t
      SET spend_category = v.category,
          category_source = v.source,
          payee = v.payee
      FROM (VALUES ${sql.join(values, sql`, `)}) AS v(id, category, source, payee)
      WHERE t.id = v.id
    `);
  }

  return { categorized: resolved.length };
}
