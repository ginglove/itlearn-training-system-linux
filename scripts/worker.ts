import cron from "node-cron";
import * as dotenv from "dotenv";

dotenv.config({ path: ".env" });

const APP_URL = process.env.APP_URL || "http://localhost:3000";
const INTERNAL_CRON_SECRET = process.env.INTERNAL_CRON_SECRET;

if (!INTERNAL_CRON_SECRET) {
  console.error("INTERNAL_CRON_SECRET is not set in .env");
  process.exit(1);
}

async function runWorker() {
  try {
    const res = await fetch(`${APP_URL}/api/v1/internal/execute-code`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${INTERNAL_CRON_SECRET}`,
        "content-type": "application/json",
      },
    });

    const data = await res.json();
    if (data.status !== "IDLE") {
      console.log(`[worker] ${new Date().toISOString()}`, data);
    }
  } catch (err) {
    console.error("[worker] fetch failed:", err);
  }
}

// Run every minute
cron.schedule("* * * * *", runWorker);

console.log("[worker] Code execution worker started. Running every minute.");
console.log(`[worker] Targeting: ${APP_URL}/api/v1/internal/execute-code`);
