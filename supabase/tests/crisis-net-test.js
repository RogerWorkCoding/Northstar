// Crisis safety-net phrase check. Run: node supabase/tests/crisis-net-test.js
// Reads the phrase list straight from the brain, so it always tests the real thing.
const fs = require("fs");
const path = require("path");
const src = fs.readFileSync(path.join(__dirname, "../functions/northstar-chat/index.ts"), "utf8");
const block = src.slice(src.indexOf("const CRISIS_PHRASES"), src.indexOf("const CRISIS_FALLBACK"));
const str = (v, m = 2000) => (typeof v === "string" ? v.trim().slice(0, m) : "");
const crisisNet = new Function("str", block.replace(/: (unknown|boolean)/g, "") + "\nreturn crisisNet;")(str);

const SHOULD_MATCH = [
  "I don’t want to live anymore",            // curly apostrophe (iPhone keyboard)
  "i dont want to be here",
  "I don't want to be here anymore. Everyone would be fine.",
  "I just don’t want to wake up, ever",
  "I want to end my life",
  "im thinking about ending it all",
  "I want to die",
  "im suicidal",
  "thoughts of suicide every night",
  "I keep hurting myself",
  "I’ve been cutting myself",
  "I self harm",
  "everyone would be better off without me",
  "there's no reason to live",
  "I dont want to live anymore lol",
  "I don't want to live like this anymore",
  "hurting myself again",
];
const SHOULD_NOT_MATCH = [
  "my phone is going to die",
  "I cut myself shaving",
  "I hurt myself by accident at the gym",
  "Suicide Squad poster ideas",
  "This deadline is killing me",
  "killing it at work",
  "I want to end the meeting early",
  "I don’t want to be here for the whole meeting",
  "I don’t want to live in Ohio",
  "I cut myself a slice of cake",
  "I hurt myself at the gym",
  "I don’t want to be here until midnight",
];

let fails = 0;
for (const t of SHOULD_MATCH) if (!crisisNet(t)) { fails++; console.log("MISSED     ", t); }
for (const t of SHOULD_NOT_MATCH) if (crisisNet(t)) { fails++; console.log("FALSE ALARM", t); }
console.log(fails ? `${fails} problem(s)` : `All ${SHOULD_MATCH.length + SHOULD_NOT_MATCH.length} phrase checks pass`);
process.exit(fails ? 1 : 0);
