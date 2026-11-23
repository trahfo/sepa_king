# XSD sources

| File | Source | Notes |
|---|---|---|
| `pain.001.001.03.xsd`, `pain.008.001.02.xsd` | ISO 20022 message archive (version 2009) | generic ISO schema |
| `pain.001.002.03.xsd`, `pain.001.003.03.xsd`, `pain.008.002.02.xsd`, `pain.008.003.02.xsd` | Deutsche Kreditwirtschaft, DFÜ-Abkommen Anlage 3 | German SEPA variants |
| `pain.001.001.03.ch.02.xsd` | SIX Interbank Clearing, Swiss Payment Standards | Swiss variant |
| `pain.001.001.09.xsd` | Deutsche Kreditwirtschaft, DFÜ-Abkommen Anlage 3 v3.7, Technical Validation Subset GBIC_4 (SCT / SCT Inst) | structured addresses only; contributed in salesking/sepa_king#117 by Tobias Schoknecht |
| `pain.008.001.08.xsd` | Deutsche Kreditwirtschaft, DFÜ-Abkommen Anlage 3 v3.7, Technical Validation Subset GBIC_4 (SDD CORE / B2B) | structured addresses only; contributed in salesking/sepa_king#117 by Tobias Schoknecht |

| `pain.008.001.08.iso.xsd` | ISO 20022 message archive, iso20022.org (generated 2019-02-14), SHA-256 `7edf4e4ce34c47a5567af6a327e22af4ed4007f715822af9f353c94ecc10f5ba` | generic schema, used by the `:epc` profile |
| `pain.001.001.09.iso.xsd` | ISO 20022 message archive, iso20022.org (generated 2019-02-14), SHA-256 `de038b373e47b0077b1832ddd81f4b2f1eb25d35721f62da1e38b7f5a09fda24` | generic schema, used by the `:epc` profile |

The schemas are published by their owners for implementers. Each file's header comment names its origin and version.
