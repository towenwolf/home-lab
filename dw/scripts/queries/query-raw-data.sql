SELECT *
FROM raw.state_spending
WHERE expend_class_name LIKE '%DISTRIBUTION%'
LIMIT 1000;