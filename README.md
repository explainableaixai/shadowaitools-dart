# shadowaitools

Most organisations already hold the evidence of which AI tools their people use. It sits in DNS query logs, proxy exports and firewall reports that nobody reads for that purpose. `shadowaitools` is a small Dart library that turns one of those files into a list of AI tools, with a category and data-use flags for each.

It is the Dart companion to the [Shadow AI Tools log audit](https://www.shadowaitools.com), and it runs anywhere Dart runs: a laptop, a CI job, a scheduled task on a server.

## The short version

```dart
import 'package:shadowaitools/shadowaitools.dart';

Future<void> main() async {
  final client = ShadowAIToolsClient(apiKey: 'YOUR_KEY');
  final findings = await client.scan('dns-export.csv');
  for (final f in findings.where((f) => f['blocked'] == true)) {
    print('${f['domain']}  ${f['primary_category']}');
  }
  client.close();
}
```

Add the package with `dart pub add shadowaitools`.

## How a scan works

`scan(path)` does four things, in this order:

1. Reads the file line by line.
2. Splits each line on spaces, tabs, commas and semicolons.
3. Keeps every token that parses as a hostname with at least one dot, lower-cased, with duplicates removed.
4. Looks up each unique hostname once and returns the results as a `List<ApiResult>`.

Because step 3 is deliberately loose, it copes with most export formats without configuration: CSV from a firewall, a space-separated resolver log, or a plain list of domains pasted into a text file. Full URLs work too; only the host part is kept.

The looseness has one cost. A column of IP addresses or version numbers also contains dots, and each unique value becomes a lookup. If your export has many such columns, cut it down to the host column first:

```bash
cut -d, -f4 proxy.csv > hosts.txt
```

Fewer tokens means fewer calls against your quota and a faster run.

## Checking one domain

When you already know the name, skip the file:

```dart
final r = await client.check('claude.ai');
```

`check` hits the same lookup as `scan`, so the result shape is identical.

## Reading the findings

Each `ApiResult` behaves like a read-only map. The useful keys are:

- `domain` and, when a parent domain matched, `matched_domain`
- `blocked`: `true` if the host belongs to a known AI tool
- `primary_category`, `ai_type` and a `categories` list
- `trains_on_data`, `opt_out_available`, `enterprise_no_training`, `api_no_training`: what the vendor terms say, each with the value `unstated` when the terms are silent
- `terms_checked`: when those terms were last reviewed

A host that is not an AI tool comes back with `blocked: false` and empty categories.

## Turning results into a summary

Raw findings are one row per host. People reading a report want one row per tool, grouped by risk. A few lines of Dart get you there:

```dart
Map<String, List<String>> byCategory(List<ApiResult> rows) {
  final out = <String, List<String>>{};
  for (final r in rows.where((r) => r['blocked'] == true)) {
    final name = (r['matched_domain'] ?? r['domain']) as String;
    final cat = (r['primary_category'] ?? 'Uncategorised') as String;
    out.putIfAbsent(cat, () => []).add(name);
  }
  return out;
}
```

From there it is simple to print a table, write JSON for a dashboard, or feed a spreadsheet.

A second pass worth doing flags tools whose terms allow training on inputs:

```dart
final exposed = findings.where((r) =>
    r['blocked'] == true &&
    (r['trains_on_data'] == 'yes' || r['trains_on_data'] == 'unstated'));
```

That short list is usually the one a compliance lead asks for first.

## A scheduled audit

Running the same scan every week turns a one-off snapshot into a trend. Save each run to a dated file and compare the sets:

```dart
final thisWeek = findings.map((r) => r['domain'] as String).toSet();
final newTools = thisWeek.difference(lastWeek);
```

New entries in `newTools` are tools that appeared since the last run, which is often where the interesting conversations start.

## Things to know before you run it on real logs

**Only hostnames leave your machine.** The library parses the file locally and sends one hostname per request. Usernames, IP addresses, timestamps and any other columns stay on the machine that runs the scan.

**Lookups run one after another.** This keeps the load predictable and stays well under rate limits. A file with a few thousand unique hosts finishes in minutes. For very large exports, deduplicate across files first and scan the combined list once.

**One failure stops the scan.** If a lookup throws, `scan` passes the exception up and you get no partial list. Wrap the call if you would rather log and continue, or use `check` in your own loop with a `try` around each call.

## Errors

The exceptions come from `package:shadowaitools`:

- `AuthenticationException` for HTTP 401 or 403, which means a bad key or an exhausted monthly quota
- `RateLimitException` for HTTP 429
- `ApiException`, the base type, for any other failure, with `statusCode` and `body`

An empty key or empty domain raises `ArgumentError` before any request is sent. File errors, such as a missing path, surface as the usual `FileSystemException` from `dart:io`.

## Configuration

| Parameter | Default | Purpose |
|---|---|---|
| `apiKey` | required | Your lookup key |
| `baseUrl` | the hosted lookup API | Point at your own proxy or a test server |
| `httpClient` | a new `http.Client` | Share a client, add logging, or inject `MockClient` in tests |
| `timeout` | 30 seconds | Per request |

## Who uses a scan like this

- **IT teams** who need an honest list of AI tools in use before they write a policy.
- **Compliance and audit staff** building an AI inventory, a common request in reviews that reference ISO/IEC 42001 or the EU AI Act.
- **Managed service providers** who run the same audit for many clients and want it scripted.

If you would rather upload a file and get a finished PDF, the hosted audit on the website does that without any code.

## The data behind the lookups

Every lookup is answered from the register of more than 20,000 domains that also feeds the team's [AI risk assessment tools](https://www.aitoolsblocklist.com/ai-risk-assessment.php). Traffic that turns out not to be AI can still be labelled: [URL categorization API](https://www.urlcategorizationdatabase.com/api-docs.php) lookups cover general browsing, and the [website categorization API for IAB labels](https://www.websitecategorizationapi.com) covers the rest live.

Other packages for the same audit:

- [Python package on PyPI](https://pypi.org/project/shadowaitools/)
- [Node.js package on npm](https://www.npmjs.com/package/shadowaitools)

## License

MIT.
