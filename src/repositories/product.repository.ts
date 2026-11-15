import {
  DynamoDBClient
} from "@aws-sdk/client-dynamodb";

import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand
} from "@aws-sdk/lib-dynamodb";

import { Product } from "../types/product";

const client = new DynamoDBClient({});

const docClient = DynamoDBDocumentClient.from(client);

const getTableName = () => {
  const table = process.env.PRODUCTS_TABLE;

  if (!table) {
    throw new Error("PRODUCTS_TABLE is not configured");
  }

  return table;
};

export class ProductRepository {

  async create(product: Product): Promise<void> {
    await docClient.send(
      new PutCommand({
        TableName: getTableName(),
        Item: product,
        ConditionExpression:
          "attribute_not_exists(productId)"
      })
    );
  }

  async findById(
    productId: string
  ): Promise<Product | null> {

    const result = await docClient.send(
      new GetCommand({
        TableName: getTableName(),
        Key: { productId }
      })
    );

    return (result.Item as Product) ?? null;
  }
}
