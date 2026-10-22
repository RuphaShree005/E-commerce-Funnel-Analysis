E-commerce Funnel Analysis

An end-to-end portfolio project that analyzes where customers drop off in an e-commerce purchase journey.

Business question

At which stage do shopping sessions drop out, and how does funnel performance vary by device, acquisition channel, and week?

Tools

- MySQL 8+ and MySQL Workbench
- Microsoft Excel
- Tableau

MySQL Workbench is used to write and run the SQL. The database runs locally in MySQL Server; this project does not require a cloud data warehouse.

Project overview

The project uses synthetic e-commerce event data to measure progression through four steps:

1. Product view
2. Add to cart
3. Begin checkout
4. Purchase

The SQL creates an analysis table with overall, device, acquisition-channel, and weekly funnel results. Excel and Tableau use the SQL output to present the findings.

Repository contents

- `data/sample_events.csv` — synthetic event-level data
- `data/tableau_funnel_output.csv` — sample analysis output for Tableau practice
- `sql/01_setup.sql` — creates the database and source events table
- `sql/02_funnel_analysis.sql` — builds the funnel analysis table
- `sql/03_check_results.sql` — displays and checks the results
- `sql/ecommerce_funnel_analysis.sql` — combined SQL reference script
- `excel/ecommerce_funnel_dashboard.xlsx` — Excel dashboard
- `tableau/TABLEAU_BUILD_GUIDE.md` — steps to build the Tableau dashboard
- `START_HERE.md` — detailed project setup instructions
- `RESUME.md` — resume wording and interview notes

How to run the project

### 1. Set up MySQL

Install and start MySQL Server 8 or newer, then connect to it using MySQL Workbench.

### 2. Create the database and table

Open and run `sql/01_setup.sql` in Workbench.

### 3. Import the sample data

Use Workbench’s **Table Data Import Wizard** to import `data/sample_events.csv` into the existing table:

`ecommerce_demo.events`

Keep the CSV column names and order.

### 4. Run the funnel analysis

Open `sql/02_funnel_analysis.sql` and run the entire file. The query uses CTEs, so run it as one complete script.

### 5. Check the results

Run `sql/03_check_results.sql`.

The expected sample funnel counts are:

| Funnel step | Sessions |
|---|---:|
| Product view | 1,000 |
| Add to cart | 443 |
| Begin checkout | 263 |
| Purchase | 183 |

### 6. Review the Excel dashboard

Open `excel/ecommerce_funnel_dashboard.xlsx` to review the funnel, weekly trend, and segment summaries.

### 7. Build the Tableau dashboard

Export the `funnel_analysis` table to CSV from Workbench, connect Tableau to that CSV, and follow `tableau/TABLEAU_BUILD_GUIDE.md`.

## Metrics

- **Funnel entry:** a session with a product-view event.
- **Step conversion:** sessions reaching a step divided by sessions reaching the previous step.
- **Step drop-off:** one minus the step conversion rate.
- **Overall conversion:** sessions reaching a step divided by product-view sessions.
- **Ordered funnel:** a session reaches a step only when the event occurs after the previous step in the same session.
- **Purchase revenue:** purchase value deduplicated by transaction within a session.

## Sample finding

In this synthetic dataset, 557 of 1,000 product-view sessions do not reach the add-to-cart step. This is a demonstration finding, not a measured result from a real business.

## Data note

All data is synthetic and created for portfolio practice. Do not present the sample results as real customer behavior or claim business impact from them.

## Resume summary

Built an e-commerce funnel analysis using MySQL, Excel, and Tableau to measure ordered customer progression from product view through purchase. Created SQL logic for session-level funnel steps, conversion and drop-off metrics, transaction deduplication, and device, channel, and weekly comparisons.
