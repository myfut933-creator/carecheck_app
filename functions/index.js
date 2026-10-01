// Cloud Function proxy for the optional AI "improve wording" feature.
// - Requires a valid Firebase Auth ID token (Authorization: Bearer <token>).
// - Keeps the LLM API key server-side as a secret (never in the app).
// - Receives only: category, severity, client ALIAS and the free-text description.
//
// Deploy:
//   firebase functions:secrets:set ANTHROPIC_API_KEY
//   firebase deploy --only functions
// Then build the app with --dart-define=AI_ENDPOINT=<function URL>.
// NOTE: deploying functions needs the Firebase Blaze plan; set a budget alert.

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();
const API_KEY = defineSecret("ANTHROPIC_API_KEY");

const SYSTEM_PROMPT =
  "You help aged care support workers write objective incident notes. " +
  "Rewrite the worker's description in clear, neutral, factual language. " +
  "Rules: do NOT add facts, causes, names, times or diagnoses that are not in the input; " +
  "do NOT give medical advice; keep under 120 words; keep the worker's meaning. " +
  "Then list up to 3 questions about missing details. " +
  'Return ONLY JSON: {"draft": string, "missing_details": [string]}.';

exports.improveIncident = onRequest(
  { secrets: [API_KEY], region: "australia-southeast1", cors: true, timeoutSeconds: 30 },
  async (req, res) => {
    try {
      if (req.method !== "POST") return res.status(405).json({ error: "POST only" });

      // 1. Authenticate the caller.
      const header = req.get("Authorization") || "";
      const token = header.startsWith("Bearer ") ? header.slice(7) : null;
      if (!token) return res.status(401).json({ error: "Missing token" });
      await admin.auth().verifyIdToken(token);

      // 2. Validate and minimise input.
      const { category, severity, client, text } = req.body || {};
      if (typeof text !== "string" || text.trim().length < 10 || text.length > 2000) {
        return res.status(400).json({ error: "Invalid text" });
      }
      const userMsg =
        `category=${String(category || "").slice(0, 40)}; ` +
        `severity=${String(severity || "").slice(0, 10)}; ` +
        `client=${String(client || "").slice(0, 40)}; text=${text.trim()}`;

      // 3. Call the LLM (server-side key).
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": API_KEY.value(),
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-haiku-4-5-20251001",
          max_tokens: 400,
          temperature: 0.2,
          system: SYSTEM_PROMPT,
          messages: [{ role: "user", content: userMsg }],
        }),
      });
      if (!r.ok) return res.status(502).json({ error: "AI unavailable" });

      const data = await r.json();
      const raw = (data.content && data.content[0] && data.content[0].text) || "";
      const jsonText = raw.replace(/```json|```/g, "").trim();
      const parsed = JSON.parse(jsonText);

      return res.json({
        draft: String(parsed.draft || "").slice(0, 1500),
        missing_details: Array.isArray(parsed.missing_details)
          ? parsed.missing_details.slice(0, 3).map(String)
          : [],
      });
    } catch (e) {
      console.error("improveIncident error", e && e.code ? e.code : e);
      return res.status(500).json({ error: "Server error" });
    }
  }
);
