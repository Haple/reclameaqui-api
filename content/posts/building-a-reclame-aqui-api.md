# Building an unofficial Reclame Aqui API

<p class="byline">November 16, 2026 · A prototype for SerpApi public roadmap issue #4590</p>

On November 11, SerpApi opened [issue #4590](https://github.com/serpapi/public-roadmap/issues/4590): after Web Summit Rio, a lot of users asked for a Reclame Aqui API. Reclame Aqui is where Brazilians check a company before they buy from it. A company's page shows its reputation score, how many complaints it answers and solves, and every complaint with the company's reply.

I'm Brazilian and I use the site, so I built the API the issue asks for, in SerpApi's shape: four engines, the same `search_metadata` layout, a one-hour cache, an archive, and `raw_html_file`. This post covers the parts that took actual work.

## Getting past the front door

The first request failed:

```
$ curl -s -o /dev/null -w "%{http_code}" https://www.reclameaqui.com.br/empresa/nubank/
403
```

The body was Cloudflare's "Just a moment..." challenge. The site's internal JSON endpoints (`iosite.reclameaqui.com.br`, `iosearch.reclameaqui.com.br`) returned the same 403. A headless Chromium on the same server did no better: after 25 seconds it was still showing "Um momento… Executando verificação de segurança".

Then I tried Cloudflare's [Browser Rendering](https://developers.cloudflare.com/browser-rendering/), a headless Chrome that runs on Cloudflare's own network. The first request came back with the real page, 1 MB of HTML, in 3.1 seconds of browser time.

The reason matters more than the result. Browser Rendering does not pretend to be a person: its requests are signed and identified as automated, and Reclame Aqui's rules let them through. So the client has no fingerprint spoofing or CAPTCHA solving in it. It also treats a challenge page as a failure, so if the site's policy ever changes, searches come back with `status: "Error"` instead of being parsed as empty. At SerpApi's volume this would be one strategy among several, backed by the proxy and CAPTCHA infrastructure it already runs.

Every request blocks images, fonts and media, and waits only for `DOMContentLoaded`, because the data is server rendered. Company pages usually cost 1 to 3 seconds of browser time, and JSON endpoints under one second.

## The page is an Astro site, and the props are the data

I expected Next.js and a `__NEXT_DATA__` blob. Instead, the company page is built with Astro: server-rendered HTML with React "islands" that hydrate in the browser. Each island carries its props in an attribute:

```html
<astro-island component-url="/_ra-brandpage/PeopleAlsoVisitedIsland.CsWTvuZ0.js"
  props="{&quot;relatedCompanies&quot;:[1,[[0,{&quot;shortname&quot;:[0,&quot;mondial-assistance-seguro-viagem&quot;],...
```

Astro serializes every value as a `[type, value]` tuple: `[0, x]` for plain values and objects, `[1, [...]]` for arrays, and a bare `[0]` for `undefined`. Decoding the tuples takes about 30 lines of Ruby (`ReclameAqui::AstroProps`), and it returns exactly what the page was rendered from.

That paid off right away. The "Desempenho" box has five tabs: 6 meses, 12 meses, 2025, 2024 and Geral. Only the first is rendered into the HTML. The others load when you click them. But the island behind the contact section holds the full company object, including all five periods. So one fetch returns all five, and `reputation_by_period` costs nothing extra.

Two rules kept this robust:

- **Match islands by name or by the keys their props hold, never by file name.** `ContactChannelsSectionIsland.DTITmigQ.js` gets a new hash on every deploy. Several islands are just named `index.*.js`, so the reputation history is found as "the island with `data` and `dictionary` props".
- **Fail loudly.** If the company island disappears, the parser raises `ParseError` instead of returning a half-empty result. A spec deletes the island from a real page to check this.

## The complaint list, read from the site's own client

The full complaint list loads from a JSON endpoint. Rather than guess its parameters, I read the site's own bundle, `ComplaintListIsland.js`, which is served without the bot check. The URL is `/query/companyComplains/{num}/{offset}?company={id}`, or `/query/{q}/...` for keyword search. The bundle also has the mapping from each tab to its filters:

```js
nao_respondidas: { status: "PENDING", evaluated: "bool:false" },
resolvidas:      { solved: "bool:true", evaluated: "bool:true" },
```

The API exposes those tabs as `filter=not_answered|answered|evaluated|solved|not_solved`. The endpoint wants the internal company id (`29260`, or newer ones like `fQcd3AN0mGTu3Yi1`) rather than the slug. A small MongoDB collection maps slugs to ids and is filled from every result that shows both, so the extra lookup happens at most once per company. The endpoint returns an empty body for any page size above 10 (11, 20 and 50 all failed), so `num` is capped there.

## Data quirks, each with a test

- **Timestamps that lie about their time zone.** List payloads send bare local time (`2026-11-16T06:54:04`). Complaint pages send the same values with a `Z` appended, which would make them UTC. They aren't: at 11:18 UTC the site labeled a complaint created at "11:42:35Z" the day before as "Há 20h", which only works if the timestamp is -03:00. The company page, rendered by another service, labeled the same complaint "Há 23h", so the site disagrees with itself by three hours. The API returns every timestamp as ISO 8601 with `-03:00`.
- **Placeholders.** Unrated companies show `"--"` for their score and rates. The API leaves those keys out instead of sending strings where numbers belong.
- **Response times.** Only the 6 month period is rendered as text ("6 dias e 21 horas"), so the API formats the other periods itself. A spec runs over every fixture and checks the formatted text against what the site displays, including singular forms ("6 dias e 1 hora").
- **Truncated text.** Keyword searches cut `description` at 130 characters. The full text is only in `descriptionMasked`, which is also the version with CPF and card numbers starred out, as the site shows it. The API uses the masked text.
- **A leaked `toString()`.** On complaint pages, the company's reputation ships as a Java `Map#toString()`: `"{averageAnswerTime=592736.0, finalScore=8.4, ..., status=RA1000}"`. It is parsed rather than ignored.
- **Badges.** The list payload says `ANSWERED` for complaints the complaint page calls `SOLVED`. The badge is derived from the `evaluated` and `solved` flags, which agree.
- **Structured data I chose not to trust.** The page's JSON-LD gives ASSIST CARD an `aggregateRating` of 10.0, while the page shows 8.4. "Geral" also turned out to mean the last three years, not all time.

## SerpApi's conventions

The API follows SerpApi's conventions so a SerpApi user would already know it:

- `search_metadata` with an ObjectId `id`, `json_endpoint`, `raw_html_file` and `total_time_taken`, then `search_parameters`, then the results.
- An identical search within the hour is served from storage. `no_cache=true` skips it.
- `async=true` returns `Processing` right away, and `/searches/:id.json` serves the result later.
- A missing company is `status: "Success"` with an `error` message, the way SerpApi reports an empty result. Bad parameters return HTTP 400.
- Every company and complaint has an `api_link` for the next request, like `serpapi_link`, and complaint lists get `pagination` like `serpapi_pagination`.

The [playground](/playground) shows the stored page next to the JSON. Hovering a key outlines the element it came from, a small version of SerpApi's X-Ray. List items are matched by the link they carry, and other keys by a selector map that lives next to each engine.

## Tests

The fixtures are 18 real responses, saved exactly as Browser Rendering returned them: all six reputation levels from RA1000 to Não recomendada, an unrated company, a 404 page, five complaint lists and complaints both pending and solved. Parser specs run on those files. Request specs stub Browser Rendering with WebMock and cover caching, async, pagination, errors and the archive.

The mocks hid one bug. WebMock loads `net/http`, so every spec passed while the real server crashed on `Net::OpenTimeout`. One live request through the actual stack found it in seconds. `bin/rails reclame_aqui:smoke` now runs every engine live before each deploy.

## What I'd do next

- Use SerpApi's proxy pool as a fallback fetcher, so the API doesn't depend on one site policy.
- A scheduled job that fetches a page per engine and diffs it against the fixtures, to catch layout changes before customers report them.
- Company lookup by CNPJ, the segment ranking pages, and the company FAQ tab.
- A Portuguese version of the docs, for the users who asked at Web Summit Rio.

The code is on GitHub, and the [docs](/docs) are generated by running the same parsers over the same fixtures, so they can't drift from what the API returns.
