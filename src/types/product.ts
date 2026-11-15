
export interface Product {
  productId: string;
  name: string;
  category: string;
  price: number;
  stock: number;
  createdAt: string;
}

export interface CreateProductInput {
  name: string;
  category: string;
  price: number;
  stock: number;
}
