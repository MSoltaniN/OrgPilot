
-- Reference views (SQLite). median(x) == percentile_cont(0.5) in PostgreSQL.
CREATE VIEW order_fact AS
SELECT o.*,
  MAX(CASE WHEN e.event='paid' THEN e.at END)            AS paid_at,
  MAX(CASE WHEN e.event='payment_failed' THEN e.at END)  AS failed_at,
  MAX(CASE WHEN e.event='cancelled' THEN e.at END)       AS cancelled_at,
  MAX(CASE WHEN e.event='picked' THEN e.at END)          AS picked_at,
  MAX(CASE WHEN e.event='handed_over' THEN e.at END)     AS handed_over_at,
  MAX(CASE WHEN e.event='delivered' THEN e.at END)       AS delivered_at
FROM orders o LEFT JOIN order_events e USING(order_id) GROUP BY o.order_id;

CREATE VIEW ticket_fact AS
SELECT t.*,
  MIN(CASE WHEN e.event='first_response' THEN e.at END) AS first_response_at,
  MAX(CASE WHEN e.event='inspected' THEN e.at END)      AS inspected_at,
  MAX(CASE WHEN e.event='resolved' THEN e.at END)       AS resolved_at,
  MAX(CASE WHEN e.event='reopened' THEN 1 ELSE 0 END)   AS reopened
FROM tickets t LEFT JOIN ticket_events e USING(ticket_id) GROUP BY t.ticket_id;

CREATE VIEW lead_fact AS
SELECT l.*,
  MAX(CASE WHEN e.event='first_contact' THEN e.at END) AS first_contact_at,
  MAX(CASE WHEN e.event='qualified' THEN e.at END)     AS qualified_at,
  MAX(CASE WHEN e.event='proposal_sent' THEN e.at END) AS proposal_at,
  MAX(CASE WHEN e.event='won' THEN e.at END)           AS won_at,
  MAX(CASE WHEN e.event='lost' THEN e.at END)          AS lost_at,
  COALESCE((SELECT x.contract_value_toman FROM crm_lead_events x WHERE x.lead_id=l.lead_id AND x.event='value_corrected'
            ORDER BY x.drop_day DESC LIMIT 1),
           MAX(CASE WHEN e.event='won' THEN e.contract_value_toman END)) AS contract_value
FROM crm_leads l LEFT JOIN crm_lead_events e USING(lead_id) GROUP BY l.lead_id;

CREATE VIEW task_fact AS
SELECT t.*, MAX(CASE WHEN e.event='done' THEN e.at END) AS done_at
FROM tasks t LEFT JOIN task_events e USING(task_id) GROUP BY t.task_id;

CREATE VIEW revenue_daily AS
WITH b2c AS (
  SELECT date(e.at) d,
         SUM(CASE WHEN e.event='paid' THEN o.order_value_toman ELSE -e.amount_toman END) v,
         SUM(CASE WHEN o.channel='marketplace' THEN (CASE WHEN e.event='paid' THEN o.order_value_toman ELSE -e.amount_toman END) ELSE 0 END) mp
  FROM order_events e JOIN orders o USING(order_id) WHERE e.event IN ('paid','refunded') GROUP BY 1),
b2b AS (SELECT date(won_at) d, SUM(contract_value) v FROM lead_fact WHERE won_at IS NOT NULL GROUP BY 1)
SELECT c.d, COALESCE(b2c.v,0) AS b2c, COALESCE(b2b.v,0) AS b2b, COALESCE(b2c.mp,0) AS marketplace
FROM cal c LEFT JOIN b2c USING(d) LEFT JOIN b2b USING(d);
