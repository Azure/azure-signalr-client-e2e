// Negotiate server for the Web PubSub chat client E2E tests.
//
// Exposes GET /negotiate?userId=<id> and returns a client access URL for the
// `chat` hub, mirroring examples/quickstart/server.js from the chat client SDK.
//
// Connection string is read (in order) from:
//   WebPubSubConnectionString            (native chat-client env)
//   E2E_WEBPUBSUB_CHAT_CONNECTION_STRING      (E2E convention)
//   process.argv[2]                      (command-line argument)
import express from "express";
import { WebPubSubServiceClient } from "@azure/web-pubsub";

const hubName = process.env.WEBPUBSUB_CHAT_HUB || "chat";
const port = process.env.PORT || 3000;

const connectionString =
  process.env.WebPubSubConnectionString ||
  process.env.E2E_WEBPUBSUB_CHAT_CONNECTION_STRING ||
  process.argv[2];

if (!connectionString) {
  console.error(
    "Please provide the Web PubSub connection string via WebPubSubConnectionString, " +
      "E2E_WEBPUBSUB_CHAT_CONNECTION_STRING, or as a command-line argument.",
  );
  process.exit(1);
}

const app = express();
const serviceClient = new WebPubSubServiceClient(connectionString, hubName, {
  allowInsecureConnection: true,
});

app.get("/negotiate", async (req, res) => {
  const userId = req.query.userId;
  if (!userId) {
    return res.status(500).json({ error: "userId is required" });
  }
  try {
    const token = await serviceClient.getClientAccessToken({ userId });
    res.json({ url: token.url });
  } catch (err) {
    console.error(`negotiate failed: ${err}`);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(port, () => {
  console.log(`Chat negotiate server listening at http://localhost:${port} (hub: ${hubName})`);
});
