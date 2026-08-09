// F4.1 — profaniteitsfilter op namen (§9.1). Genormaliseerd tegen leet-speak
// en tussenvoegsels; bewust een KORTE lijst van ondubbelzinnige woorden.
// Vals-positieven zijn hier erger dan vals-negatieven: een gemiste
// scheldnaam wordt gerapporteerd (F6.5-moderatie), een geweigerde echte
// naam is meteen frictie bij het eerste contact.

const VERBODEN = [
  // NL
  "kanker", "tering", "tyfus", "hoer", "kut", "neuk", "flikker", "mongool",
  "nazi", "hitler",
  // EN
  "fuck", "shit", "cunt", "bitch", "nigger", "nigga", "faggot", "retard",
  "whore", "penis", "vagina",
];

const LEET: Record<string, string> = {
  "0": "o", "1": "i", "2": "z", "3": "e", "4": "a", "5": "s",
  "6": "g", "7": "t", "8": "b", "9": "g", "@": "a", "$": "s", "!": "i",
};

export function normaliseer(naam: string): string {
  return naam
    .toLowerCase()
    .split("")
    .map((c) => LEET[c] ?? c)
    .join("")
    .normalize("NFKD")
    .replace(/[^a-z]/g, "");
}

export function naamProbleem(naam: string): string | null {
  const kaal = naam.trim();
  if (kaal.length < 2 || kaal.length > 20) {
    return "Een naam is 2 tot 20 tekens";
  }
  if (!/^[\p{L}\p{N} _.-]+$/u.test(kaal)) {
    return "Alleen letters, cijfers, spaties en _.-";
  }
  const genormaliseerd = normaliseer(kaal);
  for (const woord of VERBODEN) {
    if (genormaliseerd.includes(woord)) {
      return "Die naam kan niet";
    }
  }
  return null;
}
