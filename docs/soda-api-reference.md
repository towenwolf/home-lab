# Oregon State Spending SODA API Reference

## Endpoint

```
https://data.oregon.gov/resource/y9g9-xsxs.json
```

## Rate Limits

### Without App Token
- Shared throttling pool based on IP address
- Significantly restricted (exact limit not published)
- Risk of `429 Too Many Requests` responses

### With App Token
- **1,000 requests per rolling hour**
- Practically unthrottled unless detected as abusive

### Per-Request Row Limits
| Scenario | Limit |
|----------|-------|
| Default (no `$limit` param) | 1,000 rows |
| SODA 2.0 max | 50,000 rows |
| SODA 2.1 max | Unlimited |

## Obtaining an App Token

### 1. Create Account
1. Go to [data.oregon.gov](https://data.oregon.gov)
2. Click **Sign Up** (top right)
3. Register with your email

### 2. Generate Token
1. Log in and go to **Profile** settings
2. Navigate to **Developer Settings**
3. Click **Create New App Token**
4. Fill in:
   - **Name**: Must be unique across all Socrata domains
   - **Description**: Brief explanation of usage
   - **Callback Prefix**: Not required for API access

Tokens are generated immediately - no approval wait.

## Using the App Token

### Preferred: HTTP Header
```bash
curl -s -H "X-App-Token: YOUR_TOKEN" \
  "https://data.oregon.gov/resource/y9g9-xsxs.json?\$limit=50000"
```

### Alternative: URL Parameter
```bash
curl -s "https://data.oregon.gov/resource/y9g9-xsxs.json?\$\$app_token=YOUR_TOKEN&\$limit=50000"
```

## Pulling All Rows (Pagination)

1. Get total record count:
   ```bash
   curl -s -H "X-App-Token: YOUR_TOKEN" \
     "https://data.oregon.gov/resource/y9g9-xsxs.json?\$select=count(*)"
   ```

2. Paginate with `$limit` and `$offset`:
   ```bash
   # First batch
   curl -s -H "X-App-Token: YOUR_TOKEN" \
     "https://data.oregon.gov/resource/y9g9-xsxs.json?\$limit=50000&\$offset=0&\$order=:id"

   # Second batch
   curl -s -H "X-App-Token: YOUR_TOKEN" \
     "https://data.oregon.gov/resource/y9g9-xsxs.json?\$limit=50000&\$offset=50000&\$order=:id"
   ```

3. Continue incrementing `$offset` by 50,000 until `offset >= total_count`

## Security Notes

- Always use HTTPS
- Keep tokens private - duplicated tokens share your quota
- Store tokens in environment variables, not in code

## References

- [Socrata App Tokens Documentation](https://dev.socrata.com/docs/app-tokens.html)
- [Throttling Limits](https://dev.socrata.com/changelog/2016/06/04/clarification-of-throttling-limits.html)
- [Querying More Than 1000 Rows](https://support.socrata.com/hc/en-us/articles/202949268-How-to-query-more-than-1000-rows-of-a-dataset)
- [data.oregon.gov Developer Portal](https://data.oregon.gov/developers)
