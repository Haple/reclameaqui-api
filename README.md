# Reclame Aqui API

An unofficial, SerpApi-style API for [Reclame Aqui](https://www.reclameaqui.com.br), Brazil's largest consumer complaint site. It is a working prototype for SerpApi public roadmap issue [#4590](https://github.com/serpapi/public-roadmap/issues/4590), "Support ReclameAQUI API".

One GET request returns a company's reputation for every period, its complaints, the company's answers and the consumers' ratings, as JSON in the same layout SerpApi uses.

```
GET /search.json?engine=reclame_aqui_company&company_id=nubank&api_key=...
```

```json
{
  "search_metadata": {
    "id": "673a1f0c9b8e4d2a6c5f1e07",
    "status": "Success",
    "json_endpoint": ".../searches/673a1f0c9b8e4d2a6c5f1e07.json",
    "reclame_aqui_url": "https://www.reclameaqui.com.br/empresa/nubank/",
    "raw_html_file": ".../searches/673a1f0c9b8e4d2a6c5f1e07.html",
    "total_time_taken": 1.9
  },
  "search_parameters": { "engine": "reclame_aqui_company", "company_id": "nubank" },
  "company_info": { "id": "88850", "name": "Nubank", "cnpj": "18.236.120/0001-58", "verified": true, "...": "..." },
  "reputation": {
    "period": "six_months",
    "status": "RA1000",
    "score": 8.8,
    "complaints": 56849,
    "response_rate": 99.9,
    "solved_rate": 93.2,
    "deal_again_rate": 81.4,
    "average_response_time": { "seconds": 339922, "text": "3 dias e 22 horas" }
  },
  "reputation_by_period": ["... all five tabs ..."],
  "reputation_history": ["..."],
  "main_problems": { "categories": ["..."], "problems": ["..."], "products": ["..."] },
  "recent_complaints": ["..."],
  "related_companies": ["..."]
}
```

## Engines

| `engine` | Parameters | Returns |
| --- | --- | --- |
| `reclame_aqui` | `q` | Companies matching a name, with score and status |
| `reclame_aqui_company` | `company_id` | Profile, reputation for 6 and 12 months, the last two years and "Geral", monthly history, ranking, main problems, latest complaints, related companies, crisis alerts |
| `reclame_aqui_complaints` | `company_id`, `filter`, `q`, `category_id`, `product_id`, `problem_id`, `start`, `num` | Complaints with the site's tabs as filters, keyword search, facets and pagination |
| `reclame_aqui_complaint` | `company_id`, `complaint_id` | The full complaint, the company's answers, the consumer's final consideration and rating, similar complaints |

Every engine also takes `api_key`, `no_cache` and `async`. `GET /searches/:id.json` is the archive, and `GET /searches/:id.html` returns the stored page. The full reference is at `/docs`, and `/playground` runs searches next to the page they were parsed from. Hovering a JSON key there outlines its source element.

## Access

The home page, docs and blog post are public. The playground and the live API are for invited guests, because every uncached search spends browser time.

- **Sign-in** is passwordless: a guest enters their email and gets a link that works once, for 15 minutes. Opening the link shows a button and only the POST spends it, so mail scanners that prefetch links can't use it up. Only a SHA-256 digest of the token is stored. The session cookie is signed and lasts 30 days.
- **The guest list** holds addresses or whole domains. It is checked on every request, so removing an entry locks its guests out at once. Addresses that aren't on it get the same "check your inbox" page and no email.
- **API keys.** Each guest gets a 64-character `api_key`, shown in the playground, for curl or their own code. It never enters `search_parameters` or the cache key.
- **Admin.** `/admin` shows the guest list, who signed in, who asked for a link and was refused, and every search with who ran it.

```sh
bin/rails "guests:add[ana@example.com]"         # one address
bin/rails "guests:add[@example.com]"            # everyone at a domain
bin/rails "guests:add[you@example.com,admin]"   # can open /admin
bin/rails "guests:remove[ana@example.com]"
bin/rails guests:list
```

## How it works

1. **Fetching.** Reclame Aqui is behind Cloudflare's bot challenge: curl and a local headless Chromium both get a 403 "Um momento..." page. Pages are fetched through [Cloudflare Browser Rendering](https://developers.cloudflare.com/browser-rendering/), a headless Chrome whose requests identify themselves as automated and which the site lets through. Images, fonts and media are skipped (`app/scrapers/reclame_aqui/client.rb`).
2. **Parsing.** Company and complaint pages are Astro sites. Each React island carries its props as `[type, value]` tuples, which `AstroProps` decodes back into the data the page was rendered from. That includes the four reputation periods the HTML never renders. Complaint lists come from the JSON endpoint the site's own client uses. Parsers raise `ParseError` when the data they expect is missing, rather than returning nils.
3. **Serving.** Results and raw pages are stored in MongoDB. Identical searches within an hour are served from storage, as SerpApi does. Links back into the API (`api_link`, `pagination`) are added at serve time.

The blog post at `/blog/building-a-reclame-aqui-api` covers the details and the data quirks: mislabeled time zones, `"--"` placeholders, a leaked Java `toString()`, and more.

```
app/scrapers/reclame_aqui/
  client.rb          Browser Rendering fetcher with retries and challenge detection
  astro_props.rb     Astro island props decoder
  page.rb            Nokogiri document + islands + JSON-LD
  normalize.rb       numbers, Brasília timestamps, CNPJ, labels
  parsers/           one parser per page type, pure functions over fixtures
  engines/           parameters, URLs, api_links and X-Ray selectors per engine
app/services/        SearchRunner (cache, fetch, parse, store), ApiLinks, previews
app/controllers/concerns/authentication.rb   sign-in by emailed link, sessions, api_key
spec/fixtures/       18 real responses, captured 2026-11-16
```

## Running it

Requirements: Ruby 3.4, MongoDB, and a Cloudflare account with Browser Rendering.

```sh
bundle install
export CLOUDFLARE_ACCOUNT_ID=...
export CLOUDFLARE_API_TOKEN=...        # needs the Browser Rendering permission
export MONGODB_URI=mongodb://127.0.0.1:27017/reclameaqui_api_development   # optional, this is the default
bin/rails server
```

In development, sign-in emails aren't sent and the "check your inbox" page links to the sign-in link instead. Production also needs:

```sh
export APP_HOST=reclameaqui.example.com          # the only host served
export MAIL_FROM="Your Name <demo@example.com>"
export SMTP_PASSWORD=...                         # a Resend API key; SMTP_ADDRESS etc. override Resend
export CONTACT_EMAIL=hello@example.com           # optional: shown to people who aren't on the guest list
```

```sh
bundle exec rspec               # 84 specs on the captured pages, no network
bin/rails reclame_aqui:smoke    # one live search per engine
```

`DAILY_LIVE_SEARCH_LIMIT` (default 300) caps uncached searches per day, each guest gets 30 searches per 10 minutes, and each IP 10 sign-in requests per 10 minutes.

## Not affiliated

This is an independent prototype. It is not affiliated with Reclame Aqui or SerpApi. It reads public pages at low volume and caches every result. Complaint text is returned in the masked form the site displays.
