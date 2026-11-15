
import {
  APIGatewayProxyHandlerV2
} from "aws-lambda";

import {
  ProductService,
  ValidationError
} from "../services/product.service";

const service = new ProductService();

export const handler: APIGatewayProxyHandlerV2 =
  async (event) => {

    try {
      const productId =
        event.pathParameters?.productId;

      const product = await service.getProduct(
        productId ?? ""
      );

      if (!product) {
        return {
          statusCode: 404,
          body: JSON.stringify({
            message: "Product not found"
          })
        };
      }

      return {
        statusCode: 200,
        headers: {
          "content-type": "application/json"
        },
        body: JSON.stringify({
          data: product
        })
      };

    } catch (error) {

      if (error instanceof ValidationError) {
        return {
          statusCode: 400,
          body: JSON.stringify({
            message: error.message
          })
        };
      }

      console.error("Get product failed:", error);

      return {
        statusCode: 500,
        body: JSON.stringify({
          message: "Internal server error"
        })
      };
    }
  };
