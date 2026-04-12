# SwiftXMLSchema — Roadmap Completa

## Context

SwiftXMLSchema è il layer di parsing XSD nell'ecosistema XML Swift:

```
SwiftXMLCoder v2 (fondazione — codec, streaming, macro, XPath)
    ↑
    ├─ SwiftXMLSchema (parsing XSD, normalizzazione, component model)
    │   ↑
    │   └─ SwiftXMLCodeGen (schema → codice Swift, CLI + plugin)
    │
    └─ SwiftSOAP (client/server SOAP, parser WSDL)
```

**Stato attuale (2026-04-05):** Phase 0.1 completata. Parsing raw completo + normalizzazione semantica inclusa restriction, default/fixed values, isAbstract, annotation/documentation, substitutionGroup con lookup table. CI verde su tutte le lane (5.4→6.1, iOS, TSan, SwiftLint, DocC). Dipendenza su swift-xml-coder v2.0.0 remota.

**Posizionamento strategico:** Nessun linguaggio fuori da Java (Xerces/JAXB) e .NET (`System.Xml.Schema`) ha un component model XSD completo e navigabile. Go, Rust e JS/TS hanno solo tool parziali che gestiscono l'80% dei casi. Python (xmlschema) è completo per parsing/validazione ma non è un component model orientato al tooling. Swift ha l'opportunità di essere best-in-class per l'ecosistema Apple/server-side, colmando lo stesso gap che Rust non ha ancora riempito.

---

## Phase 0.1 — Completezza XSD Core ✅ COMPLETATA (2026-04-05)

Tutti e 5 gli item erano già implementati nel bootstrap. Archiviato in `.claude/plans/archive/`.

---

## Phase 0.2 — Diagnostiche, Error Model e Resource Resolution (Swift 5.4) ✅ COMPLETATA (2026-04-05)

**Obiettivo:** Rendere la libreria usabile in produzione con errori azionabili e resolver non-locali.

| Item | Dettaglio |
|------|-----------|
| **Source location tracking** | `XMLSchemaSourceLocation` (file URL, line, column). Verificare se `XMLNode` di SwiftXMLCoder espone line number via libxml2. Attaccare a ogni case di `XMLSchemaParsingError`. Ispirato a .NET `ValidationEventArgs` e Python xmlschema che forniscono path + line esatti. |
| **Richer error model** | `XMLSchemaParsingDiagnostic` con severity (error/warning/note), location, code, message. `XMLSchemaParsingResult<T>` che porta valore + warning raccolti (non-fatal issues come facet non riconosciuti o feature XSD deprecate). |
| **Remote resource resolver** | `RemoteXMLSchemaResourceResolver` per `http://`/`https://` con `URLSession`, timeout, caching. Il protocollo è già `Sendable`. |
| **Catalog-based resolver** | `CatalogXMLSchemaResourceResolver` che legge OASIS XML Catalog per remapping. Standard in toolchain enterprise (Xerces lo supporta nativamente). |
| **Composite resolver** | `CompositeXMLSchemaResourceResolver` che concatena local → catalog → remote. Default raccomandato per produzione. |

**Sblocca downstream:** CodeGen ha messaggi con file:line. SOAP può risolvere import WSDL remoti.

**File coinvolti:** `XMLSchemaParsingError.swift`, `XMLSchemaResourceResolver.swift`, `XMLSchemaDocumentParser+Logic.swift`

---

## Phase 0.3 — Component Model, Visitor e Traversal API (Swift 5.7) ✅ COMPLETATA (2026-04-05)

**Obiettivo:** Trasformare la normalizzazione in un vero **component model** navigabile (ispirato a Xerces XS API e .NET `XmlSchemaSet.Compile()`), con API protocol-oriented per traversal.

| Item | Dettaglio |
|------|-----------|
| **Indexed component model** | Le 7 lookup methods di `XMLNormalizedSchemaSet` (attualmente O(n) scan lineare) diventano dizionari pre-computed `[QName: Component]`. Come Xerces espone `XSModel.getTypeDefinition(name, namespace)` in O(1). Questo è il singolo cambiamento più importante per i consumer. |
| **`XMLSchemaVisitor` protocol** | Con **primary associated type** `Context` (Swift 5.7) → `any XMLSchemaVisitor<MyContext>` senza type erasure manuale. Metodi visit per element, complexType, simpleType, attribute, choice, wildcard. |
| **`XMLSchemaWalker`** | Struct concreta per depth-first traversal. Gestisce ricorsione su effectiveContent, choice, attributes. Elimina la duplicazione di logica tra normalizer e codegen. |
| **Type hierarchy navigator** | API per navigare la catena di derivazione: `baseType(of:)`, `derivedTypes(of:)`, `isSubstitutableFor(_:)`. Come `XSTypeDefinition.getBaseType()` di Xerces. Critico per codegen che emette gerarchie Swift. |
| **`some` parameter types** | `some XMLSchemaVisitor` nelle API del walker per performance migliore vs existential. |

**Sblocca downstream:** CodeGen sostituisce il walking manuale con visitor. SOAP type mapper adotta lo stesso visitor. Tool di terze parti (doc generators, linter) hanno API stabile.

**File coinvolti:** Nuovi file `XMLSchemaVisitor.swift`, `XMLSchemaWalker.swift`. Refactor `XMLSchemaNormalizer.swift`.

---

## Phase 0.4 — Redefine, Mixed Content, Identity Constraints (Swift 5.7–5.9) ✅ COMPLETATA

**Obiettivo:** Completezza XSD 1.0 al pari di Java e .NET.

| Item | Stato |
|------|-------|
| **`<xsd:redefine>`** | ✅ — `applyRedefine` in `XMLSchemaDocumentParser+Logic.swift` |
| **Mixed content** | ✅ — `isMixed: Bool` su `XMLComplexType` e `XMLNormalizedComplexType`, propagato dal normalizer |
| **Identity constraints** | ✅ — `XMLSchemaIdentityConstraint` (kind: key/keyref/unique), parsato e attaccato a elementi normalizzati |
| **`<xsd:notation>`** | ✅ — `XMLSchemaNotation` parsato e storato in `XMLSchema.notations` |

**Completata senza essere stata segnata — scoperto durante audit 2026-04-12.**

---

## Phase 0.5 — Concurrency e Typed Throws (Swift 6.0) ✅ COMPLETATA

| Item | Stato |
|------|-------|
| `throws(XMLSchemaParsingError)` su parser e normalizer | ✅ — `XMLSchemaDocumentParser.swift`, `XMLSchemaNormalizer.swift` |
| Varianti `async` su `XMLSchemaResourceResolver` | ✅ — protocol + `RemoteXMLSchemaResourceResolver` |
| `parse(url:) async throws` | ✅ — `XMLSchemaDocumentParser.swift` |
| Concurrent multi-schema parsing via `TaskGroup` | ✅ — `appendSchemaRecursivelyAsync` con `withThrowingTaskGroup` |
| Sendable audit + strict concurrency | ✅ — `swiftLanguageModes: [.v6]` in `Package@swift-6.0.swift` |

---

## Phase 0.6 — Build Tool Plugin e Schema Caching (Swift 5.6+) ✅ COMPLETATA

| Item | Stato |
|------|-------|
| SPM `BuildToolPlugin` (`.xsd` → JSON normalizzato a build-time) | ✅ — `Plugins/XMLSchemaPlugin/`, dichiarato in `Package@swift-5.6.swift`+ |
| `Codable` su `XMLNormalizedSchemaSet` | ✅ — `XMLNormalizedSchemaSet+Codable.swift` |
| SHA-256 fingerprinting (`fingerprint: String`) | ✅ — `XMLNormalizedSchemaSet+Codable.swift:107` |

---

## Phase 0.7 — Macro (Swift 5.9) — RIFIUTATA

Nessuna macro implementata. Motivazioni:

| Candidato | Motivo per esclusione |
|-----------|----------------------|
| `#xsdQName(...)` | `swift-xml-coder` espone già una macro equivalente per QName. Duplicare sarebbe overhead senza valore. |
| `@XMLSchemaVisitorDefaults` | Non necessario: `XMLSchemaVisitor` espone già implementazioni no-op di default come extension. I consumer overridano solo i metodi di interesse. |
| `@SchemaValidated` compile-time | XSD sono dati runtime — una macro non può leggerli. Il build-tool plugin (0.6) è il meccanismo corretto. |
| Schema-driven type synthesis | Code generation, non macro. CodeGen + SPM plugin è lo strumento giusto. |

---

## Phase 0.8 — Interoperabilità: JSON Schema e Schema Export (Swift 5.9+)

**Obiettivo:** Feature di interop che nessuna libreria Swift offre, ispirate al meglio dell'ecosistema Python e .NET.

| Item | Dettaglio |
|------|-----------|
| **XSD → JSON Schema conversion** | Convertire `XMLNormalizedSchemaSet` in JSON Schema (draft 2020-12). Python xmlschema lo fa con `to_dict()`/`to_json()` ed è una delle sue feature più usate. Permette interop con tool REST/OpenAPI che consumano JSON Schema. Nuovo target `SwiftXMLSchemaJSONInterop` per non inquinare il core. |
| **Schema export (XSD round-trip)** | Serializzare `XMLSchemaSet` o `XMLNormalizedSchemaSet` back in XSD valido. Python xmlschema lo supporta. Utile per manipolazione programmatica di schemi (es. rimuovere tipi non usati, merge di schemi, generazione XSD da codice Swift). |
| **Schema flattening** | Produrre un singolo XSD senza import/include, con tutti i tipi inlined. Comune esigenza in pipeline enterprise dove gli schemi vengono distribuiti come singolo file. |

**Sblocca downstream:** Tool REST/OpenAPI possono consumare schemi XSD via JSON Schema. Pipeline CI/CD possono manipolare schemi. CodeGen può lavorare su schemi flattened.

---

## Phase 1.0 — Stabilità API, Schema Diff e Documentazione (Swift 6.0+)

**Obiettivo:** Dichiarare stabilità API, tag 1.0, semver da qui in poi.

| Item | Dettaglio |
|------|-----------|
| **API stability review** | Audit tipi/metodi pubblici. Marcare dettagli implementativi come `package` access (5.9). Versionare formato JSON normalizzato. |
| **Schema diff/comparison** | `XMLSchemaDiff` che calcola differenze tra due `XMLNormalizedSchemaSet`: tipi/elementi aggiunti/rimossi/modificati. Output strutturato per codegen incrementale. Come `xmlschema` di Python che supporta comparazione. |
| **Schema statistics** | Conteggi tipi, profondità ereditarietà max, breakdown namespace, unreferenced types. Utile per tooling e diagnostiche. |
| **DocC documentation** | Catalog con tutorial: parsing, normalizzazione, visitor, plugin, JSON Schema export. |

**Sblocca downstream:** CodeGen ha rigenerazione incrementale. SOAP ha confronto schema per versioning WSDL.

---

## Phase 1.1 — Feature Avanzate (Swift 6.1+) ✅ COMPLETATA (2026-04-12)

| Item | Stato |
|------|-------|
| **XML instance validation** | ✅ — `XMLSchemaValidator` (commit 7fe5746) |
| **Schema inference da XML** | ✅ — `XMLSchemaInferrer` (commit 41990bb) |
| **Schema flattening** | ✅ — `XMLSchemaFlattener` (commit 970c2ce) |
| **XSD 1.1 assertions** (`<xsd:assert>`) | ✅ — `XMLSchemaAssertion`, 21 test (commit 4461614) |
| **XSD 1.1 type alternatives** | ✅ — `XMLSchemaTypeAlternative` (commit 4461614) |
| **XSD 1.1 open content** | ✅ — `XMLSchemaOpenContent` + `defaultOpenContent` + validator awareness (commit 4461614) |
| **Streaming/incremental parsing** | Rimandato — ottimizzazione non urgente |

`~Copyable` e `InlineArray` (6.0/6.1) non sono applicabili: i tipi schema sono naturalmente copyable e di lunghezza variabile.

---

## Riepilogo

| Phase | Swift Min | Tema | Unlock | Benchmark di riferimento |
|-------|-----------|------|--------|--------------------------|
| **0.1** | 5.4 | Completezza XSD core | CodeGen gestisce WSDL reali | Go/Rust falliscono qui |
| **0.2** | 5.4 | Diagnostiche + resolver | Errori azionabili, schema remoti | Python xmlschema, .NET |
| **0.3** | 5.7 | Component model + visitor | API stabile per consumer | Xerces XS API |
| **0.4** | 5.7–5.9 | XSD 1.0 completo | Mixed content, redefine | Parità con Python xmlschema |
| **0.5** | 6.0 | Concurrency + typed throws | Parsing parallelo | Nessun equivalente (vantaggio Swift) |
| **0.6** | 5.6+ | Plugin + caching | Build incrementali | .NET XmlSchemaSet.Compile() |
| **0.7** | 5.9 | Macro selettive | Ergonomia QName, visitor defaults | — |
| **0.8** | 5.9+ | JSON Schema + export | Interop REST/OpenAPI | Python xmlschema to_dict/to_json |
| **1.0** | 6.0+ | Stabilità + diff + docs | Codegen incrementale, semver | — |
| **1.1+** | 6.1+ | Validazione, inference, XSD 1.1 | .NET PSVI, XmlSchemaInference | Speculativo |
