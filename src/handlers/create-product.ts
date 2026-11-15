
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
      if (!event.body) {
        return {
          statusCode: 400,
          body: JSON.stringify({
            message: "Request body is required"
          })
        };
      }

      let input;

      try {
        input = JSON.parse(event.body);
      } catch {
        return {
          statusCode: 400,
          body: JSON.stringify({
            message: "Invalid JSON"
          })
        };
      }

      const product = await service.createProduct(input);

      return {
        statusCode: 201,
        headers: {
          "content-type": "application/json"
        },
        body: JSON.stringify({
          message: "Product created successfully",
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

      console.error("Create product failed:", error);

      return {
        statusCode: 500,
        body: JSON.stringify({
          message: "Internal server error"
        })
      };
    }
  };
