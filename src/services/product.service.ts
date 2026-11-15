
import { randomUUID } from "node:crypto";

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
    private readonly repository = new ProductRepository()
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

  async getProduct(
    productId: string
  ): Promise<Product | null> {

    if (!productId?.trim()) {
      throw new ValidationError("Product ID is required");
    }

    return this.repository.findById(productId);
  }
}
