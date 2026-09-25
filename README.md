# Shadow AI Tools for Dart and Flutter

`shadowaitools` is the Dart and Flutter local log-to-AI-inventory client for [Shadow AI Tools](https://www.shadowaitools.com). It gives applications a small, typed interface for a production data service while keeping authentication, URL construction, response decoding, retries, and error handling out of business logic.

An organization often has the evidence of unsanctioned AI use in existing DNS, proxy, and firewall exports but lacks a repeatable way to turn noisy hostnames into an actionable inventory. The client parses common network-log shapes locally, extracts and normalizes hosts, checks unique domains against the AI Tools Blocklist, and can emit machine-readable JSON or CSV for review.

This package is designed as a real client library rather than a collection of copied HTTP examples. It supports the normal lifecycle of a lookup: validate input, send the API key in the expected header, apply a bounded timeout, decode a successful response, distinguish authentication and quota failures, and expose response fields without discarding information that may be needed later. It fits shadow AI discovery, network-log triage, vendor review preparation, recurring governance reports and other applications where the decision must be repeatable and auditable.

## Installation

Install the published package from pub.dev:

```text
dart pub add shadowaitools
```

Store the API key outside source control. Examples use `AQ_API_KEY`, but production applications can obtain the value from their established secret manager. Never place a working key in a README, test fixture, command history, mobile bundle, browser-delivered JavaScript, or committed configuration file.

## Quick start

```dart
import 'package:shadowaitools/shadowaitools.dart';

Future<void> main() async {
  final client = ShadowAIToolsClient(apiKey: const String.fromEnvironment('AQ_API_KEY'));
  final result = await client.scan('dns-export.csv');
  print(result.toJson());
}
```

The client returns a structured result containing deduplicated AI-service inventory with category, vendor, and data-use findings. It does not turn a nuanced response into an unexplained boolean unless a convenience method explicitly promises that behavior. Keeping the full result makes logs useful, allows a policy to evolve without repeating a lookup, and gives an operator enough context to understand why an action was taken.

## What the client handles

The package owns transport concerns that should behave consistently across a codebase. It normalizes inputs only where the service contract allows normalization, attaches the API key without putting it in a query string, sends a descriptive user agent, negotiates JSON, checks status codes before decoding success models, and retains the response body on service errors. A caller should be able to catch an authentication problem separately from a quota limit, a malformed request, a temporary server failure, or a local network timeout.

Retries are intentionally conservative. Network interruptions, `429` responses with a usable delay, and selected `5xx` responses may be retried with bounded backoff. Invalid input and authentication failures are not retried because another identical request cannot repair them. Applications performing large batches should add their own pacing, concurrency limit, cancellation, and checkpointing around the client instead of starting an unbounded number of requests.

The default endpoint is suitable for normal hosted use, while a configurable base URL makes integration tests and licensed on-premises deployments possible. Timeout and retry values are configurable at client construction. Configuration is immutable after construction so the same instance can be shared safely according to normal Dart and Flutter conventions.

## Response model

The public model mirrors useful service data and leaves room for additive fields. Unknown JSON properties should not make an otherwise valid response fail. New package versions may add typed accessors when the service adds fields, but callers that retain the raw response can adopt new data without waiting for a library release.

| Field | Purpose |
|---|---|
| `domain` | Preserved from the service response for typed access, logging, or policy decisions. |
| `vendor` | Preserved from the service response for typed access, logging, or policy decisions. |
| `category` | Preserved from the service response for typed access, logging, or policy decisions. |
| `ai_type` | Preserved from the service response for typed access, logging, or policy decisions. |
| `trains_on_data` | Preserved from the service response for typed access, logging, or policy decisions. |
| `terms_checked` | Preserved from the service response for typed access, logging, or policy decisions. |
| `source_count` | Preserved from the service response for typed access, logging, or policy decisions. |
| `first_seen` | Preserved from the service response for typed access, logging, or policy decisions. |

Applications should record the query, result, decision, and request time in their own audit log. They should not record the API key. If results contain URLs or domains derived from user activity, apply the same retention and access controls used for the originating DNS, proxy, firewall, browser, or analytics data.

## Integration pattern: request-time decision

For interactive use, create one client during application startup and reuse it. Read the key and configuration once, validate that required values exist, then inject the client into the service that needs classifications. Reuse allows the underlying HTTP implementation to pool connections and makes global timeout and retry behavior predictable.

Keep the policy separate from the lookup. The package reports service facts; the application decides what those facts mean for a user, tenant, network segment, or agent. That separation makes it possible to run in observation mode, compare proposed decisions with existing controls, and change a policy without replacing the transport layer.

When a lookup is on a critical request path, define failure behavior before deployment. Security controls commonly fail closed or send an indeterminate result to review. Analytics enrichment commonly fails open and records a missing classification for later repair. There is no universal answer, but silently treating a timeout as a positive result is rarely defensible.

## Integration pattern: batch processing

Batch jobs should remove duplicate inputs before making requests, preserve the original-to-normalized mapping, and save progress in restartable chunks. Use a small concurrency limit rather than one worker per row. Read quota information from every successful response and stop cleanly before exhaustion so a scheduled job can report what remains instead of producing a half-explained failure.

A useful output record contains the original value, normalized value, lookup timestamp, package version, primary result, full category or policy data, and any error code. That record is adequate for later reconciliation and lets analysts distinguish “not found” from “not checked.” If the service data changes over time, the timestamp also makes clear which decision basis was available at the time.

Cache only for a period appropriate to the product. A short process-local cache eliminates repeated calls during one job. A longer shared cache can reduce cost, but it must include enough context in the key and must not outlive the organization’s tolerance for stale classifications. Do not cache authentication, malformed-request, or transient server errors as if they were valid negative answers.

## Operational guidance

Use explicit timeouts at every layer. The HTTP timeout protects a single attempt, while an application deadline protects the complete operation including retries. Propagate cancellation from incoming requests and job supervisors. Emit metrics for total lookups, latency, success, status-code family, retries, cache hits, and remaining quota. Alert on sustained authentication errors, an unexpected increase in indeterminate results, or a quota trajectory that will reach zero before renewal.

Pin a compatible major version in application dependencies and test upgrades in staging. Package releases use semantic versioning: patch releases repair behavior without changing the public contract, minor releases add compatible capabilities, and major releases may require source changes. Service responses can gain fields independently, so decoders are forward-compatible and callers should avoid exhaustive assumptions about future enum values.

For regulated or security-sensitive deployments, retain the package version and policy version with every decision. A later review should be able to answer which code interpreted the response, which rule consumed it, and what the service returned. This is more valuable than a log line containing only “allowed” or “blocked.”

## Errors

The client distinguishes configuration errors raised before a request, invalid-input responses, authentication failures, exhausted quota or authorization failures, rate limits, transport timeouts, server failures, and response-decoding problems. Error values include an HTTP status when one exists and a safely bounded response body for diagnostics. Secrets are never included in an error message.

Callers should handle known service errors explicitly and place a final handler around unexpected transport failures. Batch workflows can attach an error to an individual row and continue when appropriate. Authentication failures should normally stop the batch because every remaining request would fail. Rate limits should pause according to server guidance. Invalid rows can be quarantined for correction.

## Security and privacy

Use TLS verification and do not add a “disable certificate checks” option to production configuration. Restrict API keys by environment and product where the account system permits it. Rotate a key immediately if it appears in a package, repository, build log, support ticket, or client-side application. A deleted Git commit does not make an exposed key secret again.

Minimize data sent to the service. Submit only the domain, URL, method, or file-derived hostname required by the documented operation. For log-analysis workflows, normalize and deduplicate locally before lookup. Do not attach cookies, page contents, user identifiers, authorization headers from the originating request, or unrelated log columns.

## Why a maintained SDK helps

Direct HTTP calls are easy for the first successful example and expensive at the edges. Six teams can otherwise invent six interpretations of timeouts, retries, missing fields, normalization, user agents, and quota failures. A maintained package gives those decisions one reviewed implementation and gives downstream applications a stable model even as internal transport details improve.

An ecosystem-native package also makes discovery and evaluation easier. Users can inspect its license, release history, documentation, dependencies, source, and examples using familiar tools. They can pin a version, run dependency auditing, generate API documentation, and compare changes before upgrading. The README is part of that interface: it explains not just which method to call, but how the result belongs in an operational system.

## Related implementations for the same product

Use the implementation that matches the deployment environment. These repositories and registry pages all focus on Shadow AI Tools rather than unrelated products:

- [Primary multi-language repository](https://github.com/explainableaixai/shadowaitools)
- [Composer repository](https://github.com/optimiser4/shadowaitools)
- [GitLab mirror](https://gitlab.com/url-classifications/shadowaitools)
- [npm client and CLI](https://www.npmjs.com/package/shadowaitools)
- [Python client and CLI](https://pypi.org/project/shadowaitools/)
- [Rust client](https://crates.io/crates/shadowaitools)
- [PHP client](https://packagist.org/packages/shadowaitools/shadowaitools)

The implementations share service concepts but follow the conventions of their languages. Method names, async models, error hierarchies, and packaging layouts are intentionally native rather than forced into a byte-for-byte common shape.

## Companion data services

The following links connect this package to complementary layers used in broader governance and classification systems. Each description identifies a distinct job rather than repeating a product name:

- [Shadow AI Tools in Dart and Flutter draws its AI-domain data from AI Tools Blocklist](https://www.aitoolsblocklist.com)
- [Dart and Flutter workflow for exposing unapproved AI adoption alongside Shadow AI Tools](https://www.shadowaitools.com)
- [Dart and Flutter companion data for portfolio analysis within Shadow AI Tools deployments](https://www.urlcategorizationdatabase.com)
- [Dart and Flutter enrichment layer connecting Shadow AI Tools with pre-run URL audits](https://www.aiagentallowlist.com)

These services solve different questions. AI-service recognition identifies tools in network traffic. Shadow-AI analysis turns existing logs into an inventory. Agent URL policy evaluates the page an autonomous browser wants to reach. Content classification describes what a site is about, and filtering classification maps a site to network-policy categories. Combining them should be an explicit architecture decision, not an assumption that one verdict substitutes for another.

## Standards and further reading

- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)
- [ENISA cybersecurity guidance](https://www.enisa.europa.eu/)
- [MITRE ATLAS](https://atlas.mitre.org/)

These references provide vocabulary and control objectives; they do not endorse this package. Map the client’s output to the organization’s own risk assessment, legal duties, acceptable-use rules, and incident process.

## Frequently asked questions

### Does the package include the underlying database?

No. The normal package is a client and contains no bulk commercial dataset. It sends documented lookup inputs to the hosted service and returns structured results. Where an offline database licence is available, the same client interface can be adapted to an internal endpoint so application policy does not have to change.

### Should I create a new client for every lookup?

No. Construct one client for an application or worker and reuse it. This keeps configuration consistent and allows connection pooling. Create separate clients only when endpoints, credentials, tenants, or materially different timeout policies require isolation.

### Can I use the result as a permanent fact?

Treat classifications and policy findings as dated intelligence. Websites change purpose, vendors revise terms, new page types appear, and threat or governance policy evolves. Store the lookup time and refresh data according to the consequence of staleness.

### What should happen when the service is unavailable?

Choose behavior based on the calling system’s risk. A security gate can deny or require review. An enrichment pipeline can retain the row as pending. Whatever the choice, make it explicit, observable, and tested. Do not convert an infrastructure failure into a confident classification.

### Is batch processing one API call?

The convenience batch method coordinates individual lookups unless the product documentation explicitly describes a bulk endpoint. Each item can consume quota. Deduplicate inputs, pace work, monitor the returned balance, and checkpoint output.

### How should I contribute?

Open an issue in the source repository with the package version, runtime version, a minimal reproduction, expected behavior, and sanitized response details. Never include a working API key or private network log. Changes should include tests and update public documentation when behavior changes.

## License

MIT. The package licence covers the client source. Access to hosted APIs, downloadable datasets, and commercial data remains governed by the applicable service plan and terms.
