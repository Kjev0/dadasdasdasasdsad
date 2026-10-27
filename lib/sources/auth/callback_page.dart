import 'dart:convert';

/// The small page shown in the browser after the loopback redirect.
///
/// Self-contained (inline CSS + SVG, no external assets or scripts), with
/// English and Danish text side by side because the browser's language is
/// unknown to us here.
abstract final class OAuthCallbackPage {
  static String success(String providerName) => _page(
    ok: true,
    titleEn: 'Connected to ${_esc(providerName)}',
    titleDa: 'Forbundet til ${_esc(providerName)}',
    bodyEn: 'You can close this tab and return to Fermata.',
    bodyDa: 'Du kan lukke denne fane og vende tilbage til Fermata.',
  );

  static String failure(String providerName, String detail) => _page(
    ok: false,
    titleEn: 'Could not connect to ${_esc(providerName)}',
    titleDa: 'Kunne ikke forbinde til ${_esc(providerName)}',
    bodyEn: 'Return to Fermata and try again. Details: ${_esc(detail)}',
    bodyDa: 'Gå tilbage til Fermata og prøv igen. Detaljer: ${_esc(detail)}',
  );

  static String _esc(String s) => const HtmlEscape().convert(s);

  static const _checkIcon =
      '<svg viewBox="0 0 48 48" width="56" height="56" aria-hidden="true"><circle cx="24" cy="24" r="22" '
      'fill="none" stroke="currentColor" stroke-width="3"/><path d="M14 25l7 7 13-15" fill="none" '
      'stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  static const _crossIcon =
      '<svg viewBox="0 0 48 48" width="56" height="56" aria-hidden="true"><circle cx="24" cy="24" r="22" '
      'fill="none" stroke="currentColor" stroke-width="3"/><path d="M17 17l14 14M31 17L17 31" fill="none" '
      'stroke="currentColor" stroke-width="3.5" stroke-linecap="round"/></svg>';

  static String _page({
    required bool ok,
    required String titleEn,
    required String titleDa,
    required String bodyEn,
    required String bodyDa,
  }) =>
      '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>Fermata</title>
<style>
  :root { color-scheme: dark light; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center;
         background: #111214; color: #ece8e1;
         font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  main { max-width: 26rem; padding: 2.5rem 2rem; text-align: center; }
  .icon { color: ${ok ? '#d9b46a' : '#e07a6a'}; }
  .brand { letter-spacing: .32em; text-transform: uppercase; font-size: .75rem; opacity: .6; margin-bottom: 1.5rem; }
  h1 { font-size: 1.25rem; font-weight: 600; margin: 1rem 0 .25rem; }
  p { margin: 0 0 1.25rem; opacity: .8; }
  .da h1 { font-size: 1.05rem; } .da p { font-size: .95rem; }
  hr { border: 0; border-top: 1px solid #2a2b2f; margin: 1.25rem 0; }
</style>
</head>
<body>
<main>
  <div class="brand">Fermata</div>
  <div class="icon">${ok ? _checkIcon : _crossIcon}</div>
  <section lang="en"><h1>$titleEn</h1><p>$bodyEn</p></section>
  <hr>
  <section class="da" lang="da"><h1>$titleDa</h1><p>$bodyDa</p></section>
</main>
</body>
</html>
''';
}
