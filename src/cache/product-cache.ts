
import { getValkeyClient } from "./valkey.client";
import { Product } from "../types/product";

const CACHE_TTL_SECONDS = 300;

export class ProductCache {
  private getKey(productId: string): string {
    return `product:${productId}`;
  }

  async get(productId: string): Promise<Product | null> {
    const client = await getValkeyClient();

    const cachedValue = await client.get(this.getKey(productId));

    if (!cachedValue) {
      return null;
    }

    try {
      return JSON.parse(cachedValue) as Product;
    } catch {
      // Remove corrupted cache entries.
      await client.del(this.getKey(productId));
      return null;
    }
  }

  async set(product: Product): Promise<void> {
    const client = await getValkeyClient();

    await client.set(
      this.getKey(product.productId),
      JSON.stringify(product),
      {
        EX: CACHE_TTL_SECONDS
      }
    );
  }

  async delete(productId: string): Promise<void> {
    const client = await getValkeyClient();

    await client.del(this.getKey(productId));
  }
}
