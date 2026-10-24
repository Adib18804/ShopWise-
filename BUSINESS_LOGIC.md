# ShopWise - Business Logic & Analysis Rules

## Overview

This document defines all business logic rules, analysis algorithms, calculation formulas, and edge case handling for ShopWise's intelligent assistant features.

**Core Principle:** ShopWise makes recommendations, not decisions. All suggestions are presented as guidance, never as automatic actions.

---

## Table of Contents

1. [Expiry Intelligence](#1-expiry-intelligence)
2. [Stock-Out Risk Detection](#2-stock-out-risk-detection)
3. [Smart Restock Recommendation](#3-smart-restock-recommendation)
4. [Slow-Moving & Dead Stock Detection](#4-slow-moving--dead-stock-detection)
5. [FEFO (First Expire First Out) Logic](#5-fefo-first-expire-first-out-logic)
6. [Profit & Loss Analysis](#6-profit--loss-analysis)
7. [Daily Smart Summary Generation](#7-daily-smart-summary-generation)
8. [Notification Generation Rules](#8-notification-generation-rules)
9. [Edge Cases & Error Handling](#9-edge-cases--error-handling)

---

## 1. Expiry Intelligence

### Purpose
Track product batch expiry dates and generate risk warnings before products expire to minimize waste and loss.

### Risk Windows

| Risk Level | Days Until Expiry | Color Code | Icon |
|------------|-------------------|------------|------|
| **CRITICAL** | 0-7 days | Red | 🔴 |
| **HIGH** | 8-14 days | Orange | 🟠 |
| **MEDIUM** | 15-30 days | Yellow | 🟡 |
| **NORMAL** | > 30 days | Green | 🟢 |
| **EXPIRED** | < 0 days | Dark Red | ⛔ |

### Algorithm

```javascript
function analyzeExpiryRisk(shopId, riskWindow = 14) {
    // Step 1: Get all active batches with expiry dates
    const batches = await db.query(`
        SELECT 
            pb.id,
            pb.product_id,
            p.name as product_name,
            pb.batch_number,
            pb.expiry_date,
            pb.quantity,
            pb.purchase_price,
            DATEDIFF(pb.expiry_date, CURDATE()) as days_until_expiry
        FROM product_batches pb
        JOIN products p ON pb.product_id = p.id
        WHERE p.shop_id = ?
          AND pb.quantity > 0
          AND pb.expiry_date IS NOT NULL
          AND pb.expiry_date <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
        ORDER BY pb.expiry_date ASC
    `, [shopId, riskWindow]);
    
    // Step 2: Classify by risk level
    const results = {
        critical: [],
        high: [],
        medium: [],
        expired: [],
        total_value_at_risk: 0
    };
    
    for (const batch of batches) {
        const valueAtRisk = batch.quantity * batch.purchase_price;
        
        batch.value_at_risk = valueAtRisk;
        results.total_value_at_risk += valueAtRisk;
        
        if (batch.days_until_expiry < 0) {
            batch.risk_level = 'EXPIRED';
            results.expired.push(batch);
        } else if (batch.days_until_expiry <= 7) {
            batch.risk_level = 'CRITICAL';
            results.critical.push(batch);
        } else if (batch.days_until_expiry <= 14) {
            batch.risk_level = 'HIGH';
            results.high.push(batch);
        } else if (batch.days_until_expiry <= 30) {
            batch.risk_level = 'MEDIUM';
            results.medium.push(batch);
        }
    }
    
    return results;
}
```

### Calculation: Value at Risk

```
Value at Risk = Quantity in Batch × Purchase Price per Unit
```

**Example:**
- Batch: 10 units of Milk
- Purchase Price: Tk 70 per unit
- Value at Risk: 10 × 70 = **Tk 700**

### Edge Cases

| Scenario | Handling |
|----------|----------|
| No expiry date (NULL) | Exclude from expiry analysis |
| Already expired (< 0 days) | Show as EXPIRED, highest priority |
| Quantity = 0 | Exclude (depleted batch) |
| Purchase price missing | Use default_purchase_price from product |
| Multiple batches same product | Analyze each batch independently |

### Recommendation Language

✅ **CORRECT (Assistant tone):**
- "8 products worth approximately Tk 2,450 may expire within 14 days"
- "This batch expires in 5 days. Consider selling first."
- "Review expiring products to minimize potential loss"

❌ **INCORRECT (Manager tone):**
- "Discard these products now"
- "Products will definitely expire"
- "Automatic markdown applied"

---

## 2. Stock-Out Risk Detection

### Purpose
Predict when products may run out based on recent sales trends to enable proactive restocking.

### Algorithm

```javascript
function analyzeStockOutRisk(shopId, analysisPeriod = 30) {
    // Step 1: Calculate average daily sales for each product
    const products = await db.query(`
        SELECT 
            p.id,
            p.name,
            p.minimum_stock,
            COALESCE(SUM(pb.quantity), 0) as current_stock,
            COALESCE(SUM(si.quantity), 0) as total_sold,
            COUNT(DISTINCT s.sale_date) as days_with_sales
        FROM products p
        LEFT JOIN product_batches pb ON p.id = pb.product_id
        LEFT JOIN sale_items si ON p.id = si.product_id
        LEFT JOIN sales s ON si.sale_id = s.id 
            AND s.sale_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
        WHERE p.shop_id = ? AND p.is_active = TRUE
        GROUP BY p.id, p.name, p.minimum_stock
    `, [analysisPeriod, shopId]);
    
    const results = {
        critical: [],
        warning: [],
        low_stock: []
    };
    
    for (const product of products) {
        // Step 2: Calculate average daily sales
        const avgDailySales = analysisPeriod > 0 
            ? product.total_sold / analysisPeriod 
            : 0;
        
        // Step 3: Handle edge cases
        if (avgDailySales === 0) {
            // No sales data - cannot predict stock-out
            product.estimated_stock_days = null;
            product.message = "Not enough sales data to estimate stock-out risk";
            continue;
        }
        
        if (product.current_stock === 0) {
            product.estimated_stock_days = 0;
            product.risk_level = 'CRITICAL';
            product.message = "Out of stock";
            results.critical.push(product);
            continue;
        }
        
        // Step 4: Calculate estimated days until stock-out
        const estimatedDays = product.current_stock / avgDailySales;
        product.avg_daily_sales = avgDailySales;
        product.estimated_stock_days = Math.floor(estimatedDays * 10) / 10; // Round to 1 decimal
        
        // Step 5: Classify risk level
        if (estimatedDays <= 3) {
            product.risk_level = 'CRITICAL';
            product.message = `May run out within approximately ${Math.ceil(estimatedDays)} days`;
            results.critical.push(product);
        } else if (estimatedDays <= 7) {
            product.risk_level = 'WARNING';
            product.message = `May run out within approximately ${Math.ceil(estimatedDays)} days`;
            results.warning.push(product);
        } else if (product.current_stock <= product.minimum_stock) {
            product.risk_level = 'LOW_STOCK';
            product.message = `Stock below minimum threshold (${product.minimum_stock} units)`;
            results.low_stock.push(product);
        }
    }
    
    return results;
}
```

### Formulas

#### Average Daily Sales
```
Average Daily Sales = Total Quantity Sold in Period / Number of Days in Period
```

**Example:**
- Total sold in 30 days: 126 units
- Average Daily Sales: 126 / 30 = **4.2 units/day**

#### Estimated Stock Days
```
Estimated Stock Days = Current Stock / Average Daily Sales
```

**Example:**
- Current Stock: 12 units
- Average Daily Sales: 4.2 units/day
- Estimated Days: 12 / 4.2 = **2.86 days ≈ 3 days**

### Risk Thresholds

| Risk Level | Condition | Action |
|------------|-----------|--------|
| **CRITICAL** | Stock = 0 OR estimated days ≤ 3 | Immediate notification |
| **WARNING** | Estimated days ≤ 7 | Daily notification |
| **LOW_STOCK** | Current stock ≤ minimum_stock | Weekly notification |
| **NORMAL** | Estimated days > 7 AND stock > minimum | No alert |

### Edge Cases

| Scenario | Handling | Message |
|----------|----------|---------|
| Zero sales in period | Cannot calculate | "Not enough sales data to estimate stock-out risk" |
| Current stock = 0 | Immediate alert | "Out of stock" |
| Average daily sales = 0.1 | Calculate normally | "May run out within approximately X days" |
| Negative stock (data error) | Flag as error | "Stock data error - please verify" |
| New product (no history) | Skip prediction | "Insufficient sales history" |

### Recommendation Language

✅ **CORRECT:**
- "Milk may run out within approximately 3 days based on recent sales"
- "Consider restocking soon to avoid stock-out"
- "Stock is running low - estimated X days remaining"

❌ **INCORRECT:**
- "Milk will run out in exactly 3 days"
- "Automatically reordering 20 units"
- "Order now or face stock-out"

---

## 3. Smart Restock Recommendation

### Purpose
Recommend optimal restock quantity based on average daily sales and target coverage days.

### Algorithm

```javascript
function generateRestockRecommendations(shopId, analysisPeriod = 30) {
    // Step 1: Get products with sales data and current stock
    const products = await db.query(`
        SELECT 
            p.id,
            p.name,
            p.target_stock_days,
            p.minimum_stock,
            COALESCE(SUM(pb.quantity), 0) as current_stock,
            COALESCE(SUM(si.quantity), 0) as total_sold
        FROM products p
        LEFT JOIN product_batches pb ON p.id = pb.product_id
        LEFT JOIN sale_items si ON p.id = si.product_id
        LEFT JOIN sales s ON si.sale_id = s.id 
            AND s.sale_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
        WHERE p.shop_id = ? AND p.is_active = TRUE
        GROUP BY p.id, p.name, p.target_stock_days, p.minimum_stock
    `, [analysisPeriod, shopId]);
    
    const recommendations = [];
    
    for (const product of products) {
        // Step 2: Calculate average daily sales
        const avgDailySales = analysisPeriod > 0 
            ? product.total_sold / analysisPeriod 
            : 0;
        
        // Step 3: Skip if no sales data
        if (avgDailySales === 0) {
            continue;
        }
        
        // Step 4: Calculate target stock
        const targetCoverageDays = product.target_stock_days || 7;
        const targetStock = Math.ceil(avgDailySales * targetCoverageDays);
        
        // Step 5: Calculate recommended restock quantity
        const recommendedQuantity = Math.max(0, targetStock - product.current_stock);
        
        // Step 6: Only recommend if quantity > 0
        if (recommendedQuantity > 0) {
            recommendations.push({
                product_id: product.id,
                product_name: product.name,
                current_stock: product.current_stock,
                avg_daily_sales: Math.round(avgDailySales * 10) / 10,
                target_coverage_days: targetCoverageDays,
                target_stock: targetStock,
                recommended_quantity: recommendedQuantity,
                priority: calculatePriority(product.current_stock, avgDailySales),
                reason: `Based on average daily sales of ${Math.round(avgDailySales * 10) / 10} units and target coverage of ${targetCoverageDays} days`
            });
        }
    }
    
    // Step 7: Sort by priority
    return recommendations.sort((a, b) => {
        const priorityOrder = { HIGH: 0, MEDIUM: 1, LOW: 2 };
        return priorityOrder[a.priority] - priorityOrder[b.priority];
    });
}

function calculatePriority(currentStock, avgDailySales) {
    if (avgDailySales === 0) return 'LOW';
    
    const estimatedDays = currentStock / avgDailySales;
    
    if (estimatedDays <= 3) return 'HIGH';
    if (estimatedDays <= 7) return 'MEDIUM';
    return 'LOW';
}
```

### Formulas

#### Target Stock
```
Target Stock = Average Daily Sales × Target Coverage Days
```

**Example:**
- Average Daily Sales: 4.2 units/day
- Target Coverage: 7 days
- Target Stock: 4.2 × 7 = **29.4 ≈ 30 units**

#### Recommended Restock Quantity
```
Recommended Restock = Target Stock - Current Stock
```

**Example:**
- Target Stock: 30 units
- Current Stock: 12 units
- Recommended Restock: 30 - 12 = **18 units**

### Priority Levels

| Priority | Condition | Description |
|----------|-----------|-------------|
| **HIGH** | Estimated days ≤ 3 | Urgent restocking needed |
| **MEDIUM** | Estimated days ≤ 7 | Should restock soon |
| **LOW** | Estimated days > 7 | Consider restocking |

### Edge Cases

| Scenario | Handling |
|----------|----------|
| No sales history | Skip recommendation |
| Current stock > target stock | No recommendation |
| Target stock days not set | Use default 7 days |
| Average sales < 0.1/day | Skip (very slow moving) |
| Recommended quantity < 5 | Still show (might be high-value item) |

### Recommendation Language

✅ **CORRECT:**
- "Consider restocking approximately 18 units"
- "Based on recent sales, target stock is 30 units"
- "Recommended restock: 18 units to maintain 7-day coverage"

❌ **INCORRECT:**
- "Buy exactly 18 units now"
- "Automatic order placed for 18 units"
- "Must restock immediately"

---

## 4. Slow-Moving & Dead Stock Detection

### Purpose
Identify products with low or no sales activity to help shopkeepers make informed purchasing decisions.

### Classification

| Status | Criteria | Action Suggestion |
|--------|----------|-------------------|
| **DEAD_STOCK** | No sales in 30+ days | Review before purchasing more |
| **SLOW_MOVING** | Sales < 20% of average | Consider promotional action |
| **NORMAL** | Regular sales activity | Continue normal operations |

### Algorithm

```javascript
function analyzeSlowMovingProducts(shopId, thresholdDays = 30, analysisPeriod = 30) {
    const products = await db.query(`
        SELECT 
            p.id,
            p.name,
            p.default_purchase_price,
            COALESCE(SUM(pb.quantity), 0) as current_stock,
            COALESCE(SUM(si.quantity), 0) as total_sold_in_period,
            MAX(s.sale_date) as last_sale_date,
            DATEDIFF(CURDATE(), MAX(s.sale_date)) as days_since_last_sale
        FROM products p
        LEFT JOIN product_batches pb ON p.id = pb.product_id
        LEFT JOIN sale_items si ON p.id = si.product_id
        LEFT JOIN sales s ON si.sale_id = s.id
        WHERE p.shop_id = ? AND p.is_active = TRUE
        GROUP BY p.id, p.name, p.default_purchase_price
    `, [shopId]);
    
    // Calculate shop average sales
    const totalSales = products.reduce((sum, p) => sum + p.total_sold_in_period, 0);
    const avgSalesPerProduct = totalSales / products.length;
    
    const results = {
        dead_stock: [],
        slow_moving: [],
        total_value: 0
    };
    
    for (const product of products) {
        const stockValue = product.current_stock * product.default_purchase_price;
        
        // Dead Stock: No sales in threshold days
        if (product.days_since_last_sale >= thresholdDays || product.last_sale_date === null) {
            results.dead_stock.push({
                ...product,
                stock_value: stockValue,
                status: 'DEAD_STOCK',
                message: `No sales recorded for ${product.days_since_last_sale || 'more than ' + thresholdDays} days. Review before purchasing more.`
            });
            results.total_value += stockValue;
        }
        // Slow Moving: Sales < 20% of average
        else if (product.total_sold_in_period < avgSalesPerProduct * 0.2) {
            const avgDailySales = product.total_sold_in_period / analysisPeriod;
            results.slow_moving.push({
                ...product,
                avg_daily_sales: Math.round(avgDailySales * 10) / 10,
                stock_value: stockValue,
                status: 'SLOW_MOVING',
                message: 'Very low sales activity. Consider promotional action.'
            });
            results.total_value += stockValue;
        }
    }
    
    return results;
}
```

### Formulas

#### Days Since Last Sale
```
Days Since Last Sale = Current Date - Last Sale Date
```

**Example:**
- Last Sale Date: September 5, 2026
- Current Date: October 15, 2026
- Days Since Last Sale: **40 days**

#### Stock Value
```
Stock Value = Current Stock Quantity × Purchase Price per Unit
```

**Example:**
- Current Stock: 50 units
- Purchase Price: Tk 50/unit
- Stock Value: 50 × 50 = **Tk 2,500**

### Thresholds (Configurable)

| Threshold | Default Value | Description |
|-----------|---------------|-------------|
| Dead Stock Days | 30 days | No sales threshold |
| Slow Moving % | 20% of average | Sales velocity threshold |
| Analysis Period | 30 days | Historical data window |

### Edge Cases

| Scenario | Handling |
|----------|----------|
| New product (< 7 days old) | Exclude from analysis |
| Seasonal product | Flag for manual review |
| No sales data at all | Mark as "No sales history" |
| High-value low-volume item | Show but note low typical velocity |

### Recommendation Language

✅ **CORRECT:**
- "No sales recorded for 40 days. Review before purchasing more."
- "Very low sales activity. Consider promotional action."
- "This product has moved slowly recently."

❌ **INCORRECT:**
- "Remove this product immediately"
- "Stop selling this product"
- "Product is worthless"

---

## 5. FEFO (First Expire First Out) Logic

### Purpose
Recommend selling priority based on expiry dates to minimize expiry-related waste.

### Algorithm

```javascript
function generateFEFORecommendations(shopId) {
    const products = await db.query(`
        SELECT 
            p.id,
            p.name,
            COALESCE(SUM(pb.quantity), 0) as total_stock
        FROM products p
        JOIN product_batches pb ON p.id = pb.product_id
        WHERE p.shop_id = ? 
          AND pb.quantity > 0
          AND pb.expiry_date IS NOT NULL
        GROUP BY p.id, p.name
        HAVING COUNT(DISTINCT pb.id) > 1
    `, [shopId]);
    
    const recommendations = [];
    
    for (const product of products) {
        // Get all active batches sorted by expiry date
        const batches = await db.query(`
            SELECT 
                id,
                batch_number,
                expiry_date,
                quantity,
                DATEDIFF(expiry_date, CURDATE()) as days_until_expiry
            FROM product_batches
            WHERE product_id = ?
              AND quantity > 0
              AND expiry_date IS NOT NULL
            ORDER BY expiry_date ASC
        `, [product.id]);
        
        // Assign priority
        batches.forEach((batch, index) => {
            batch.priority = index + 1;
            
            if (index === 0) {
                // Highest priority (earliest expiry)
                batch.recommendation = batch.days_until_expiry <= 7
                    ? `Sell this batch first (expires in ${batch.days_until_expiry} days)`
                    : `Sell this batch first (expires on ${batch.expiry_date})`;
            } else if (index === 1) {
                batch.recommendation = 'Sell after first batch is depleted';
            } else {
                batch.recommendation = 'Reserve for later';
            }
        });
        
        recommendations.push({
            product_id: product.id,
            product_name: product.name,
            total_stock: product.total_stock,
            batches: batches
        });
    }
    
    return recommendations;
}
```

### Priority Rules

1. **Sort batches by expiry date** (earliest first)
2. **Exclude depleted batches** (quantity = 0)
3. **Exclude batches without expiry date** (non-perishables)
4. **Assign priority**: 1 = highest (sell first), 2 = second, etc.

### Selling Order

```
Batch Priority = Sort Order by Expiry Date (ASC)
```

**Example:**

| Batch | Expiry Date | Quantity | Priority | Recommendation |
|-------|-------------|----------|----------|----------------|
| A | Oct 20, 2026 | 10 | 1 | Sell first (5 days) |
| B | Oct 27, 2026 | 15 | 2 | Sell after Batch A |
| C | Nov 15, 2026 | 20 | 3 | Reserve for later |

### Edge Cases

| Scenario | Handling |
|----------|----------|
| Only one batch | No FEFO recommendation needed |
| All batches same expiry date | Show all with same priority |
| Batch with no expiry date | Exclude from FEFO (non-perishable) |
| Expired batch still in stock | Show as "Remove expired stock" |
| Two products, similar names | Keep recommendations separate |

Batch expiry comparisons use date-only values in the `Asia/Dhaka` business timezone. An expiry date equal to today's business date is still valid through that date; only earlier dates are expired. FEFO ordering is expiry date, purchase date, then batch ID. A null expiry date remains a valid inventory batch but is omitted from FEFO recommendations.

### Batch Status Calculation

Statuses are derived at read time in this priority order:

1. `DEPLETED` when quantity is zero.
2. `EXPIRED` when expiry date is before today's Bangladesh business date.
3. `NEAR_EXPIRY` when expiry is today through seven calendar days from today.
4. `LOW_STOCK` when the batch quantity is at or below the product's `minimum_stock` threshold.
5. `ACTIVE` otherwise.

`stock_transactions.quantity` is always positive. `PURCHASE`, `ADJUSTMENT_IN`, and `RETURN` add stock; `SALE`, `ADJUSTMENT_OUT`, `EXPIRED`, and `DAMAGED` remove stock. The transaction type carries the direction.

### Recommendation Language

✅ **CORRECT:**
- "Sell Batch A first (expires in 5 days)"
- "Consider selling earlier-expiring batch first"
- "Batch A expires before Batch B"

❌ **INCORRECT:**
- "Only sell from Batch A"
- "Automatically using Batch A for all sales"
- "Block sales from Batch B"

---

## 6. Profit & Loss Analysis

### Purpose
Provide approximate profit insights to help shopkeepers understand business performance.

**Important:** This is NOT full accounting software. Values are estimates based on available data.

### Formulas

#### Revenue
```
Revenue = Σ (Selling Price × Quantity Sold)
```

#### Estimated Cost
```
Estimated Cost = Σ (Purchase Price × Quantity Sold)
```

#### Gross Profit
```
Gross Profit = Revenue - Estimated Cost
```

#### Profit Margin
```
Profit Margin % = (Gross Profit / Revenue) × 100
```

### Algorithm

```javascript
function analyzeProfitAndLoss(shopId, startDate, endDate) {
    const salesData = await db.query(`
        SELECT 
            SUM(si.subtotal) as total_revenue,
            SUM(si.quantity * si.purchase_price) as total_cost,
            COUNT(DISTINCT s.id) as transaction_count
        FROM sales s
        JOIN sale_items si ON s.id = si.sale_id
        WHERE s.shop_id = ?
          AND s.sale_date BETWEEN ? AND ?
    `, [shopId, startDate, endDate]);
    
    const revenue = salesData[0].total_revenue || 0;
    const cost = salesData[0].total_cost || 0;
    const profit = revenue - cost;
    const profitMargin = revenue > 0 ? (profit / revenue) * 100 : 0;
    
    // Top selling products
    const topSelling = await db.query(`
        SELECT 
            p.id,
            p.name,
            SUM(si.quantity) as quantity_sold,
            SUM(si.subtotal) as revenue,
            SUM(si.quantity * si.purchase_price) as cost,
            SUM(si.subtotal - (si.quantity * si.purchase_price)) as profit
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        JOIN products p ON si.product_id = p.id
        WHERE s.shop_id = ?
          AND s.sale_date BETWEEN ? AND ?
        GROUP BY p.id, p.name
        ORDER BY revenue DESC
        LIMIT 10
    `, [shopId, startDate, endDate]);
    
    // Calculate profit margins
    topSelling.forEach(product => {
        product.profit_margin = product.revenue > 0 
            ? (product.profit / product.revenue) * 100 
            : 0;
    });
    
    return {
        period: { start_date: startDate, end_date: endDate },
        summary: {
            total_revenue: revenue,
            total_cost: cost,
            gross_profit: profit,
            profit_margin: Math.round(profitMargin * 100) / 100,
            transactions_count: salesData[0].transaction_count
        },
        top_selling_products: topSelling,
        highest_profit_products: [...topSelling].sort((a, b) => b.profit - a.profit).slice(0, 5),
        low_margin_products: topSelling.filter(p => p.profit_margin < 10 && p.profit_margin > 0)
    };
}
```

### Periods

| Period | Date Range |
|--------|------------|
| Today | Current date |
| Week | Last 7 days |
| Month | Last 30 days |
| Custom | User-specified range |

### Edge Cases

| Scenario | Handling | Display |
|----------|----------|---------|
| No sales in period | Zero values | "No sales data for this period" |
| Missing purchase price | Use default_purchase_price | Note: "Estimated using default prices" |
| Negative profit | Show correctly | "Loss: Tk X" or "Negative margin: -5%" |
| Zero revenue | Cannot calculate margin | "N/A" |

### Important Notes

1. **These are estimates**, not audited financial results
2. Purchase prices may vary per batch
3. Does not include:
   - Operating expenses
   - Rent, utilities, salaries
   - Taxes
   - Expiry-related losses (unless recorded)
4. **Always label as "Estimated" in UI**

### Recommendation Language

✅ **CORRECT:**
- "Estimated gross profit: Tk 1,250"
- "Approximate profit margin: 18%"
- "Note: Excludes operating expenses"

❌ **INCORRECT:**
- "Exact profit: Tk 1,250"
- "Net profit: Tk 1,250"
- "Taxable income: Tk 1,250"

---

## 7. Daily Smart Summary Generation

### Purpose
Generate a concise, assistant-style daily business brief combining multiple insights.

### Algorithm

```javascript
async function generateDailySummary(shopId, date = new Date()) {
    const summaryDate = formatDate(date);
    
    // Check if summary already exists
    const existing = await db.query(
        'SELECT * FROM daily_summaries WHERE shop_id = ? AND summary_date = ?',
        [shopId, summaryDate]
    );
    
    if (existing.length > 0) {
        return existing[0];
    }
    
    // Gather all analysis data
    const [
        todaySales,
        lowStockCount,
        expiryRisk,
        stockOutRisk,
        slowMoving
    ] = await Promise.all([
        getTodaySales(shopId, summaryDate),
        getLowStockCount(shopId),
        analyzeExpiryRisk(shopId, 14),
        analyzeStockOutRisk(shopId),
        analyzeSlowMovingProducts(shopId, 30)
    ]);
    
    // Build summary text
    const summaryParts = [];
    
    if (lowStockCount > 0) {
        summaryParts.push(`${lowStockCount}টি পণ্যের স্টক কম`);
    }
    
    if (expiryRisk.critical.length + expiryRisk.high.length > 0) {
        const count = expiryRisk.critical.length + expiryRisk.high.length;
        summaryParts.push(`${count}টি পণ্য শীঘ্রই মেয়াদ শেষ হবে`);
    }
    
    if (expiryRisk.total_value_at_risk > 0) {
        summaryParts.push(
            `আনুমানিক মেয়াদ ঝুঁকির মূল্য: ৳${formatNumber(expiryRisk.total_value_at_risk)}`
        );
    }
    
    if (todaySales.total_amount > 0) {
        summaryParts.push(`আজকের বিক্রয়: ৳${formatNumber(todaySales.total_amount)}`);
    }
    
    if (todaySales.estimated_profit > 0) {
        summaryParts.push(`আনুমানিক লাভ: ৳${formatNumber(todaySales.estimated_profit)}`);
    }
    
    const summaryText = summaryParts.join('। ') + '।';
    
    // Save summary
    await db.query(`
        INSERT INTO daily_summaries 
        (shop_id, summary_date, summary_text, low_stock_count, 
         expiry_risk_count, expiry_risk_value, sales_amount, estimated_profit)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `, [
        shopId,
        summaryDate,
        summaryText,
        lowStockCount,
        expiryRisk.critical.length + expiryRisk.high.length,
        expiryRisk.total_value_at_risk,
        todaySales.total_amount,
        todaySales.estimated_profit
    ]);
    
    return {
        summary_date: summaryDate,
        summary_text: summaryText,
        low_stock_count: lowStockCount,
        expiry_risk_count: expiryRisk.critical.length + expiryRisk.high.length,
        expiry_risk_value: expiryRisk.total_value_at_risk,
        sales_amount: todaySales.total_amount,
        estimated_profit: todaySales.estimated_profit
    };
}
```

### Summary Components

1. **Low Stock Count**: Products below minimum threshold
2. **Expiry Risk Count**: Products expiring within risk window
3. **Expiry Risk Value**: Total purchase value at risk
4. **Sales Amount**: Today's total sales
5. **Estimated Profit**: Today's approximate profit

### Language Support

**Bangla Example:**
```
আজ ৩টি পণ্যের স্টক কম। ৫টি পণ্য শীঘ্রই মেয়াদ শেষ হবে। 
আনুমানিক মেয়াদ ঝুঁকির মূল্য: ৳১,৮৫০। 
আজকের বিক্রয়: ৳১,২৫০। আনুমানিক লাভ: ৳১৮৫।
```

**English Example:**
```
Today: 3 products have low stock. 5 products are nearing expiry. 
Estimated expiry-risk value: Tk 1,850. 
Today's sales: Tk 1,250. Estimated profit: Tk 185.
```

### Generation Schedule

- **Daily at 6:00 PM** (end of business day)
- **On-demand** via API
- **Cached** for 24 hours

### Edge Cases

| Scenario | Handling |
|----------|----------|
| No sales today | Show "No sales recorded today" |
| All metrics zero | "No significant events today" |
| Summary already exists | Return cached version |
| Shop closed/inactive | Skip generation |

---

## 8. Notification Generation Rules

### Purpose
Create timely, actionable notifications for critical events.

### Notification Types & Triggers

| Type | Trigger | Severity | Frequency |
|------|---------|----------|-----------|
| **EXPIRY_RISK** | Batch expires in ≤ 7 days | CRITICAL | Daily |
| **STOCK_OUT** | Product may run out in ≤ 3 days | WARNING | Daily |
| **RESTOCK** | Product below minimum stock | INFO | Weekly |
| **SLOW_MOVING** | No sales in 30 days | INFO | Weekly |
| **DAILY_SUMMARY** | Daily summary generated | INFO | Daily at 6 PM |

### Notification Generation

```javascript
async function generateNotifications(shopId) {
    const notifications = [];
    
    // 1. Expiry Risk Notifications
    const expiryRisk = await analyzeExpiryRisk(shopId, 7);
    for (const batch of expiryRisk.critical) {
        notifications.push({
            user_id: await getShopOwnerId(shopId),
            type: 'EXPIRY_RISK',
            title: 'Critical Expiry Alert',
            message: `${batch.product_name} (${batch.batch_number}) expires in ${batch.days_until_expiry} days`,
            severity: 'CRITICAL',
            reference_type: 'BATCH',
            reference_id: batch.id
        });
    }
    
    // 2. Stock-Out Notifications
    const stockRisk = await analyzeStockOutRisk(shopId);
    for (const product of stockRisk.critical) {
        notifications.push({
            user_id: await getShopOwnerId(shopId),
            type: 'STOCK_OUT',
            title: 'Low Stock Alert',
            message: `${product.name} may run out within ${Math.ceil(product.estimated_stock_days)} days`,
            severity: 'WARNING',
            reference_type: 'PRODUCT',
            reference_id: product.id
        });
    }
    
    // 3. Restock Recommendations (weekly)
    if (isWeeklyNotificationDay()) {
        const restockRecs = await generateRestockRecommendations(shopId);
        for (const rec of restockRecs.filter(r => r.priority === 'HIGH')) {
            notifications.push({
                user_id: await getShopOwnerId(shopId),
                type: 'RESTOCK',
                title: 'Restock Recommendation',
                message: `Consider restocking ${rec.product_name} (approximately ${rec.recommended_quantity} units)`,
                severity: 'INFO',
                reference_type: 'PRODUCT',
                reference_id: rec.product_id
            });
        }
    }
    
    // Save notifications to database
    for (const notif of notifications) {
        await createNotification(notif);
    }
    
    // Send push notifications
    await sendPushNotifications(notifications);
    
    return notifications;
}
```

### Deduplication

- Don't send same notification type for same product within 24 hours
- Group similar notifications ("5 products expiring soon" vs 5 separate)

### Push Notification Integration

```javascript
async function sendPushNotifications(notifications) {
    for (const notif of notifications) {
        const user = await getUser(notif.user_id);
        const fcmToken = user.fcm_token;
        
        if (fcmToken) {
            await admin.messaging().send({
                token: fcmToken,
                notification: {
                    title: notif.title,
                    body: notif.message
                },
                data: {
                    type: notif.type,
                    reference_type: notif.reference_type,
                    reference_id: String(notif.reference_id)
                },
                android: {
                    priority: notif.severity === 'CRITICAL' ? 'high' : 'normal'
                }
            });
        }
    }
}
```

---

## 9. Edge Cases & Error Handling

### Data Quality Issues

| Issue | Detection | Handling |
|-------|-----------|----------|
| Negative stock | `quantity < 0` | Flag as data error, alert admin |
| Future sale date | `sale_date > CURDATE()` | Reject with validation error |
| Missing prices | `price IS NULL` | Use default values, note estimate |
| Duplicate sales | Same items, same time | Warn before saving |
| Orphaned batches | Product deleted but batches remain | Clean up in background job |

### Calculation Edge Cases

#### Division by Zero

```javascript
// ❌ WRONG
const estimatedDays = currentStock / avgDailySales;

// ✅ CORRECT
const avgDailySales = totalSold / days;
if (avgDailySales === 0) {
    return { message: "Not enough sales data", estimated_days: null };
}
const estimatedDays = currentStock / avgDailySales;
```

#### Null/Undefined Values

```javascript
// ❌ WRONG
const total = product.selling_price * product.quantity;

// ✅ CORRECT
const sellingPrice = product.selling_price || 0;
const quantity = product.quantity || 0;
const total = sellingPrice * quantity;
```

#### Very Small Numbers

```javascript
// Average daily sales = 0.03 units/day
// Don't say "May run out in 333 days"
// Instead: "Low sales velocity - monitoring not recommended"

if (avgDailySales < 0.1) {
    return { message: "Sales velocity too low for accurate prediction" };
}
```

### Missing Data Scenarios

| Scenario | Impact | Handling |
|----------|--------|----------|
| No sales history | Cannot predict stock-out | Show "Insufficient data" |
| No expiry dates | Cannot run expiry analysis | Skip product, don't show error |
| New shop (< 7 days) | Limited analysis | Show "Building insights..." |
| Deleted products | Orphaned sale records | Keep historical data |

### Concurrent Operations

**Example: Sale Recorded While Stock Analysis Running**

```javascript
// Use database transactions
const connection = await db.getConnection();
await connection.beginTransaction();

try {
    // 1. Check stock
    const stock = await connection.query(
        'SELECT quantity FROM product_batches WHERE id = ? FOR UPDATE',
        [batchId]
    );
    
    // 2. Validate
    if (stock[0].quantity < requestedQuantity) {
        throw new Error('Insufficient stock');
    }
    
    // 3. Update
    await connection.query(
        'UPDATE product_batches SET quantity = quantity - ? WHERE id = ?',
        [requestedQuantity, batchId]
    );
    
    await connection.commit();
} catch (error) {
    await connection.rollback();
    throw error;
}
```

---

## Summary

### Core Principles

1. **Never Automate Decisions**: Always recommend, never execute
2. **Handle Edge Cases**: Gracefully handle missing/invalid data
3. **Be Transparent**: Show calculation basis, not just results
4. **Use Clear Language**: Assistant tone, not authoritative
5. **Round Appropriately**: Don't show false precision
6. **Label Estimates**: Make it clear when values are approximate

### Calculation Checklist

- ✅ Check for division by zero
- ✅ Handle null/undefined values
- ✅ Validate date ranges
- ✅ Use database transactions for updates
- ✅ Round display values appropriately
- ✅ Apply configurable thresholds
- ✅ Document formula used
- ✅ Test with edge case data

### Language Checklist

- ✅ Use "may", "approximately", "consider"
- ✅ Avoid "will", "must", "guaranteed"
- ✅ Provide context and reasoning
- ✅ Support both English and Bangla
- ✅ Use culturally appropriate phrasing
- ✅ Respect shopkeeper as decision-maker

---

**This document serves as the authoritative reference for all ShopWise business logic implementation.**
