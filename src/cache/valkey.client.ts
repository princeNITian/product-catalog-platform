
import { createCluster } from "redis";

type ValkeyCluster = ReturnType<typeof createCluster>;

let client: ValkeyCluster | undefined;
let connectionPromise: Promise<ValkeyCluster> | undefined;

export async function getValkeyClient(): Promise<ValkeyCluster> {
  if (client?.isReady) {
    return client;
  }

  if (connectionPromise) {
    return connectionPromise;
  }

  const host = process.env.VALKEY_HOST;
  const port = Number(process.env.VALKEY_PORT ?? 6379);

  if (!host) {
    throw new Error("VALKEY_HOST is not configured");
  }

  client = createCluster({
    rootNodes: [
      {
        url: `rediss://${host}:${port}`
      }
    ],
    defaults: {
      socket: {
        tls: true,
        connectTimeout: 10000
      }
    }
  });

  client.on("error", (error) => {
    console.error("Valkey connection error:", error);
  });

  const currentClient = client;

  connectionPromise = currentClient
    .connect()
    .then(() => currentClient)
    .catch((error) => {
      currentClient.destroy();

      if (client === currentClient) {
        client = undefined;
      }

      throw error;
    })
    .finally(() => {
      connectionPromise = undefined;
    });

  return connectionPromise;
}
