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

**Stato attuale:** parsing raw completo (elements, types, groups, wildcards, choice/sequence/all, include/import, QName), normalizzazione semantica (espansione gruppi, tipi anonimi, ereditarietà per extension, cicli), 12 test. Build + test + lint OK, dipendenza su swift-xml-coder v2.0.0 remota.

**Posizionamento strategico:** Nessun linguaggio fuori da Java (Xerces/JAXB) e .NET (`System.Xml.Schema`) ha un component model XSD completo e navigabile. Go, Rust e JS/TS hanno solo tool parziali che gestiscono l'80% dei casi. Python (xmlschema) è completo per parsing/validazione ma non è un component model orientato al tooling. Swift ha l'opportunità di essere best-in-class per l'ecosistema Apple/server-side, colmando lo stesso gap che Rust non ha ancora riempito.

---

## Phase 0.1 — Completezza XSD Core (Swift 5.4)

**Obiettivo:** Colmare i gap critici nel modello che bloccano schemi reali (specialmente WSDL-derived). La **type hierarchy resolution completa** (extension + restriction) è ciò che separa le librerie serie dai toy project — Go e Rust falliscono esattamente qui.

| Item | Dettaglio |
|------|-----------|
| **Complex type restriction** | Il normalizer lancia a `XMLSchemaNormalizer.swift:1154`. Implementare calcolo effective content/attributes per restriction (intersezione base content con restriction declared content, override prohibited/required attributes). Bloccante per schemi WSDL. Ispirarsi al modello Xerces: `XSComplexTypeDefinition.getContentType()` risolve sia extension che restriction. |
| **Default/fixed values** | Aggiungere `defaultValue: String?` e `fixedValue: String?` a `XMLSchemaElement`, `XMLSchemaAttribute` e normalizzati. Il parser già legge gli attributi dei nodi ma scarta `default`/`fixed`. Python xmlschema e .NET risolvono i default; la maggior parte delle librerie Go/Rust no. |
| **Abstract types/elements** | `isAbstract: Bool` su `XMLSchemaComplexType`, `XMLSchemaElement` e normalizzati. Codegen ne ha bisogno per emettere gerarchie protocol-based. |
| **Annotation/documentation** | Struct `XMLSchemaAnnotation` con `documentation: [String]`, `appinfo: [String]`. Attaccare a schema, elements, types, attributes. Alimenta doc comments in codegen. |
| **substitutionGroup** | `substitutionGroup: XMLSchemaQName?` su `XMLSchemaElement`. Lookup table su `XMLNormalizedSchemaSet` per decoder polimorfi. |

**Sblocca downstream:** CodeGen gestisce restriction (critico per WSDL), emette doc comments, marca tipi abstract. SOAP può iniziare a dipendere.

**File coinvolti:** `XMLSchema.swift`, `XMLSchemaDocumentParser+Logic.swift`, `XMLSchemaNormalizer.swift`
**Target test:** 25+

---

## Phase 0.2 — Diagnostiche, Error Model e Resource Resolution (Swift 5.4)

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

## Phase 0.3 — Component Model, Visitor e Traversal API (Swift 5.7)

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

## Phase 0.4 — Redefine, Mixed Content, Identity Constraints (Swift 5.7–5.9)

**Obiettivo:** Completezza XSD 1.0 al pari di Java e .NET.

| Item | Dettaglio |
|------|-----------|
| **`<xsd:redefine>`** | Parsing come variante di include con modifiche tipo/gruppo. Il normalizer applica le ridefinizioni prima della normalizzazione. |
| **Mixed content** | `isMixed: Bool` su complexType e normalizzati. Codegen emette tipi che alternano text node e child element. Comune in document-oriented XML (XHTML in SOAP). |
| **Identity constraints** | Parse `<xsd:key>`, `<xsd:keyref>`, `<xsd:unique>` in `XMLSchemaIdentityConstraint`. Attach a elements. Necessario per validazione runtime (Phase 1.1+), utile già ora come metadati. |
| **`<xsd:notation>`** | Minimale: parse e store per completezza. |

**Sblocca downstream:** Compliance XSD 1.0 completa. A questo punto SwiftXMLSchema è al pari di Python xmlschema per parsing/modello.

---

## Phase 0.5 — Concurrency e Typed Throws (Swift 6.0)

**Obiettivo:** Adozione di strict concurrency e typed throws. Il codebase è ben posizionato (tipi già Sendable).

| Item | Dettaglio |
|------|-----------|
| **Typed throws** | `throws(XMLSchemaParsingError)` su API pubbliche parser e normalizer. Il manifest 6.0 già dichiara `.v6`. Manifest ≤5.9 mantengono `throws` untyped via `#if swift(>=6.0)`. |
| **Async resource resolution** | Varianti `async` su `XMLSchemaResourceResolver`. `parse(url:) async throws`. Remote resolver usa `URLSession.data(from:)`. |
| **Concurrent multi-schema parsing** | Import indipendenti parsati in parallelo con `TaskGroup` (attualmente sequenziale in `appendSchemaRecursively`). Python xmlschema fa lazy loading per schemi grandi; noi facciamo concurrent loading. |
| **Sendable audit** | Verifica con strict concurrency checking. Documentare. |

**Sblocca downstream:** CodeGen CLI parsa in parallelo. SOAP risolve WSDL import concorrentemente. Typed throws → switch esaustivo per i caller.

---

## Phase 0.6 — Build Tool Plugin e Schema Caching (Swift 5.6+)

**Obiettivo:** Integrazione SPM per parsing a build-time. Ispirato al modello .NET `XmlSchemaSet.Compile()` che produce un artefatto compilato riusabile.

| Item | Dettaglio |
|------|-----------|
| **SPM BuildToolPlugin** | Scansiona `.xsd` nelle risorse target → produce `XMLNormalizedSchemaSet` serializzato come JSON. Consumato dal plugin di CodeGen. Il plugin vive in questo repo perché il parsing è responsabilità di questa libreria. |
| **Schema caching** | Cache content-hash-based di `XMLSchemaSet` e `XMLNormalizedSchemaSet`. Aggiungere `Codable` ai tipi normalizzati che ne mancano. Come .NET compila il schema set una volta e lo riusa. |
| **Schema fingerprinting** | Hash stabile di `XMLNormalizedSchemaSet` per invalidazione cache e per codegen (rigenerare solo se cambiato). |

**Sblocca downstream:** Build incrementali veloci. CodeGen evita re-parsing ad ogni build.

---

## Phase 0.7 — Macro (Swift 5.9)

**Obiettivo:** Adottare macro dove hanno valore genuino. Non tutto merita una macro.

### Non raccomandato (e perché)

| Candidato | Motivo per esclusione |
|-----------|----------------------|
| `@SchemaValidated` compile-time | Gli XSD sono dati runtime (file su disco). Una macro non può leggere/parsare un XSD a compilazione. Il build-tool plugin (0.6) è il meccanismo corretto. |
| Schema-driven type synthesis macro | Generare tipi da XSD è code generation, non macro. Le macro operano su nodi AST, non importano un modello schema. CodeGen + SPM plugin è lo strumento giusto. JAXB usa annotation processing, non macro — il concetto è lo stesso. |
| Parameter packs per composizione variadic | La composizione schema è data-driven, non variadic nel senso generico. `XMLSchemaSet.merging(_:)` è l'API giusta. |

### Raccomandato

| Macro | Valore |
|-------|--------|
| **`#xsdQName("tns:Order", namespace: "urn:types")`** | Expression macro: valida formato QName a compile-time (prefix:localName, componenti non vuoti). Quality-of-life. |
| **`@XMLSchemaVisitorDefaults`** | Extension macro che sintetizza implementazioni no-op di default per tutti i metodi di `XMLSchemaVisitor`, così i consumer overridano solo quello che serve. |

**Nota chiave:** Le macro non sono lo strumento giusto per code generation XSD-driven. Il plugin SPM lo è. Questo è coerente con come Java (JAXB = annotation processor + tool), .NET (XmlSchemaClassGenerator = tool esterno), e Python (xmlschema = runtime library) gestiscono la questione.

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

## Phase 1.1+ — Feature Avanzate (Swift 6.1+, speculativo)

| Item | Note |
|------|------|
| **XML instance validation** | Validare documenti XML a runtime contro lo schema parsato. Ispirato a .NET PSVI (Post-Schema-Validation Infoset): dopo validazione, ogni nodo è annotato con il tipo schema risolto. Potrebbe essere target separato `SwiftXMLSchemaValidation`. |
| **Schema inference da XML** | Come .NET `XmlSchemaInference`: genera XSD da istanze XML. Utile per reverse-engineering quando lo schema non è disponibile. |
| **XSD 1.1 assertions** (`<xsd:assert>`) | Richiede valutazione XPath, disponibile in SwiftXMLCoder v2 via `XMLDocument.xpathNodes`. |
| **XSD 1.1 type alternatives** | `<xsd:alternative>` per type assignment condizionale. |
| **XSD 1.1 open content** | `<xsd:openContent>`, `<xsd:defaultOpenContent>`. |
| **Streaming/incremental parsing** | Per schemi molto grandi, usare `XMLStreamParser` di SwiftXMLCoder invece di DOM. Ottimizzazione, non correttezza. |

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
