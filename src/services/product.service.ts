
import { randomUUID } from "node:crypto";
import { ProductCache } from "../cache/product-cache";

import {
  Product,
  CreateProductInput
} from "../types/product";

import {
  ProductRepository
} from "../repositories/product.repository";

export class ValidationError extends Error {}

export class ProductService {

  constructor(
    private readonly repository = new ProductRepository(),
    private readonly cache = new ProductCache()
  ) {}

  async createProduct(
    input: CreateProductInput
  ): Promise<Product> {

    if (!input.name?.trim()) {
      throw new ValidationError("Product name is required");
    }

    if (!input.category?.trim()) {
      throw new ValidationError("Category is required");
    }

    if (!Number.isFinite(input.price) || input.price < 0) {
      throw new ValidationError("Invalid product price");
    }

    if (
      !Number.isInteger(input.stock) ||
      input.stock < 0
    ) {
      throw new ValidationError("Invalid stock quantity");
    }

    const product: Product = {
      productId: randomUUID(),
      name: input.name.trim(),
      category: input.category.trim(),
      price: input.price,
      stock: input.stock,
      createdAt: new Date().toISOString()
    };

    await this.repository.create(product);

    return product;
  }

  
  async getProduct(productId: string): Promise<Product | null> {
    if (!productId?.trim()) {
      throw new ValidationError("Product ID is required");
    }

    // 1. Try cache first
    try {
      const cachedProduct = await this.cache.get(productId);

      if (cachedProduct) {
        console.info("CACHE HIT:", productId);
        return cachedProduct;
      }

      console.info("CACHE MISS:", productId);
    } catch (error) {
      // Cache failure must not break product retrieval.
      console.error("Valkey read failed. Falling back to DynamoDB:", error);
    }

    // 2. Fetch from DynamoDB
    const product = await this.repository.findById(productId);

    if (!product) {
      return null;
    }

    // 3. Populate cache
    try {
      await this.cache.set(product);
      console.info("CACHE POPULATED:", productId);
    } catch (error) {
      console.error("Valkey write failed:", error);
    }

    // 4. Return product
    return product;
  }

}
