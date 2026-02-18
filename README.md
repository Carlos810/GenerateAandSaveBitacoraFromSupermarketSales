# Oracle PL/SQL Sales Processing System

A robust, production-ready PL/SQL solution for processing sales with real-time inventory validation, atomic transactions, and comprehensive audit trails. Built for scalability and high-value data integrity.

## Overview

This system implements a complete sales processing workflow that validates customers and stock availability before any transaction, processes multiple items in a single database call using collection parameters, updates inventory with row-level locking to prevent overselling, maintains a complete audit trail through logical deletes, and returns meaningful error messages for each validation failure. Perfect for e-commerce platforms, point-of-sale systems, or any application requiring ACID-compliant sales transactions.

## Why This Approach?

Traditional approaches often require multiple database round-trips: checking customer existence, verifying each product's stock individually, inserting the sale header, inserting each line item separately, and updating stock for each product. This leads to race conditions, poor performance, and complex error handling. Our solution uses a single stored procedure call that receives all products at once as a collection, validates everything in one pass, processes the entire transaction atomically, and returns control only when complete.

## Core Components

The system uses object types to create a flexible key-value structure that passes product-quantity pairs from frontend to database. A sale_product_type object holds each product ID and quantity, while a sale_product_table collection type allows multiple products to be passed as a single parameter. This approach eliminates the need for temporary tables or XML parsing, provides a self-documenting interface, and makes it easy to extend functionality later.

The main stored procedure implements a complete transaction workflow. It first validates that the products list is not empty, confirms the client exists and is active, then checks every product for sufficient inventory using a cursor that locks each product row. If all validations pass, it inserts the sale header, adds each line item with a snapshot of the current price, updates stock quantities atomically, and commits the transaction. If any validation fails, it rolls back completely and returns a specific error message with a result code for programmatic handling.

## How It Works

The frontend prepares a simple collection of products with quantities, similar to a shopping cart array. This collection is passed to the stored procedure in a single database call. Inside the procedure, the system first validates that the client exists and is active, then checks every product for sufficient inventory before making any changes. If all validations pass, the procedure inserts the sale header, adds all line items, and updates stock for each product atomically. If any validation fails, the entire transaction is rolled back and a specific error message is returned. The procedure returns both a result code for programmatic handling and a human-readable message explaining exactly what happened.

## Key Advantages

### Data Integrity and Traceability
The system uses logical deletes with ACTIVE and CANCELED flags instead of physically removing records, ensuring historical sales data is never lost even when customers or products are deactivated. Every table includes CREATED_DATE and MODIFIED_DATE timestamps, creating a complete audit trail of all changes. This design preserves full transaction history for regulatory compliance and business analysis, allowing complete reconstruction of any past transaction state.

### Real-time Stock Management
Atomic stock updates using FOR UPDATE row-level locking prevent overselling even under high concurrency. Stock validation and deduction happen in the same transaction, ensuring inventory accuracy. The system provides immediate visibility of available inventory while preserving historical stock levels through sale records for trend analysis. This eliminates the common problem of multiple customers purchasing the last item simultaneously.

### Performance and Scalability
The collection-based approach eliminates the N+1 query problem common in traditional implementations, requiring only a single database round-trip for the entire transaction. Row-level locking minimizes contention, allowing thousands of transactions per minute. The architecture is designed to scale horizontally with read replicas and supports Oracle partitioning for large-volume deployments. Database overhead is minimized by processing all operations in a single server-side call.

### Error Handling and User Experience
Every validation failure returns a specific, meaningful error message that clearly explains what went wrong and why. The transaction automatically rolls back on any error, preventing partial or inconsistent saves. Parameter names and return codes are self-documenting, making integration straightforward with any frontend technology. Error scenarios include client not found, inactive client, insufficient stock for specific products, empty cart, and duplicate products in the same sale.

### Business Intelligence Ready
The schema is designed from the ground up to support analytics and reporting. Complete sales history enables trend analysis and demand forecasting. Product performance can be tracked over time, customer purchase patterns are easily queryable, and inventory turnover calculations are straightforward. Cancellation tracking provides insights into return patterns and product quality issues. All data is structured to feed directly into dashboards for executive decision-making.

## Example Usage

A successful sale call creates a collection with product IDs and quantities, passes it to the procedure with a client ID and registration user, and receives back a success message containing the new sale ID. The result code of zero indicates success, allowing the application to proceed with confirmation screens or receipts.

A failed sale due to insufficient stock returns a result code of one with a detailed message specifying exactly which products have stock issues, showing the available quantity versus the requested quantity for each problematic item. This allows the frontend to display specific errors to the user rather than generic failure messages.

## Future-Ready Architecture

This system is designed to grow with your business. Immediate dashboard capabilities include real-time top-selling product analysis, customer purchase history with lifetime value calculations, inventory turnover metrics, and sales trend visualization. Easy extensions include discount code integration, partial cancellation support, loyalty points implementation, inventory alert thresholds, and BI tool connectivity through views.

Scalability features include partition-ready table designs, optimized primary and foreign key indexes, parallel execution capabilities for large reporting queries, and support for read replicas to separate transactional from analytical workloads. The object type approach allows adding fields like price override or special instructions without breaking existing integrations.

## Contributing

This project welcomes contributions from developers, DBAs, data analysts, and students. Areas for contribution include adding unit tests for edge cases, improving error messages and handling, creating frontend examples in various languages, adding monitoring queries and performance metrics, and translating documentation. The code is clean, well-commented, and designed to be educational while solving real-world business problems.