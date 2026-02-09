# Licenses in Silo Repository

## License Files in the Repository

| File            | Description |
|-----------------|-------------|
| `LICENSE`       | Business Source License 1.1 – Silo V2 (Silo Labs, 2024). |
| `LICENSE_SILOV3`| Business Source License 1.1 – Silo V3 (Distributed Coders Inc., 2026). Full text with parameters (Licensor, Change Date, Additional Use Grant). |

### License File Naming Convention

- **Convention:** file names in **uppercase**, e.g., `LICENSE`, `LICENSE_SILOV3`.
- If adding a new license version (e.g., "Silo V3" as a separate version), a consistent name would be `LICENSE_SILOV3` (not `License_SiloB3`).
- License files are kept in the **repository root**, alongside the main `LICENSE` file.

## Marking Licenses in Solidity Files (SPDX)

### SPDX Standard

In Solidity, the license is specified in the **first line** of the file in the format:

```solidity
// SPDX-License-Identifier: <identifier>
pragma solidity ...
```

**Official Documentation:**
- [Solidity: Layout of Source Files - SPDX License Identifier](https://docs.soliditylang.org/en/latest/layout-of-source-files.html#spdx-license-identifier)
- [SPDX Specification 3.0.1](https://spdx.github.io/spdx-spec/v3.0.1/)
- [SPDX License Expressions (Normative Annex)](https://spdx.github.io/spdx-spec/v3.0.1/annexes/spdx-license-expressions/)

### Two Options for Silo V3 License

1. **`BUSL-1.1`**  
   Generic identifier for Business Source License 1.1 from the [official SPDX list](https://spdx.org/licenses/BUSL-1.1.html). Does not point to a specific file with parameters (Licensor, Change Date, Additional Use Grant).  
   Still valid if the repository has only one BSL and its full text is in `LICENSE_SILOV3`.

2. **`LicenseRef-LICENSE_SILOV3`** (recommended for Silo V3)  
   According to the [official SPDX 3.0.1 specification - License Expressions](https://spdx.github.io/spdx-spec/v3.0.1/annexes/spdx-license-expressions/), the **`LicenseRef-`** prefix denotes a **user defined license reference** – a license outside the official SPDX list that refers to a specific document in the repository.  
   
   **Syntax:** `LicenseRef-<idstring>`, where `<idstring>` can contain letters, digits, periods (`.`), and hyphens (`-`).  
   
   **Examples from SPDX documentation:**
   ```
   LicenseRef-23
   LicenseRef-MIT-Style-1
   DocumentRef-spdx-tool-1.2:LicenseRef-MIT-Style-2
   ```
   
   Using `LicenseRef-LICENSE_SILOV3` makes it clear that a file is subject to the **exact** terms from the `LICENSE_SILOV3` file (Silo V3), not the generic BSL 1.1.
   
   **Official Sources:**
   - [SPDX License Expressions - Simple license expressions](https://spdx.github.io/spdx-spec/v3.0.1/annexes/spdx-license-expressions/#simple-license-expressions) – definition of `LicenseRef-` syntax
   - [SPDX customIdToUri Property](https://spdx.github.io/spdx-spec/v3.0.1/model/SimpleLicensing/Properties/customIdToUri/) – description of LicenseRef to URI mapping

### Example in Contract

For files covered by the Silo V3 license (file `LICENSE_SILOV3`):

```solidity
// SPDX-License-Identifier: LicenseRef-LICENSE_SILOV3
pragma solidity 0.8.28;
```

For files from external libraries (e.g., MIT, GPL-2.0-or-later), keep their original identifiers (MIT, GPL-2.0-or-later, etc.).

## Which Silo Core Files Should Use Silo V3 License

Files in `silo-core/contracts/` that are **Silo V3's own code** (not forks from another license) should have in the first line:

```solidity
// SPDX-License-Identifier: LicenseRef-LICENSE_SILOV3
```

Files with other licenses (e.g., GPL-2.0-or-later, MIT) in their header remain unchanged unless you intentionally migrate them to the Silo V3 license.

## Summary

- **License file:** in repo root, e.g., `LICENSE_SILOV3` (uppercase).
- **In Solidity:** first line: `// SPDX-License-Identifier: LicenseRef-LICENSE_SILOV3` for code covered by Silo V3 license.
- Full license text (parameters, Change Date, Additional Use Grant) is in the `LICENSE_SILOV3` file.

## Sources and Documentation

### Official Standards and Documentation

1. **SPDX Specification 3.0.1** (ISO/IEC 5962:2021)
   - [Main SPDX Specification](https://spdx.github.io/spdx-spec/v3.0.1/)
   - [SPDX License Expressions (Normative Annex)](https://spdx.github.io/spdx-spec/v3.0.1/annexes/spdx-license-expressions/) – definition of `LicenseRef-` syntax
   - [customIdToUri Property](https://spdx.github.io/spdx-spec/v3.0.1/model/SimpleLicensing/Properties/customIdToUri/) – LicenseRef to URI mapping

2. **Solidity Documentation**
   - [Layout of Source Files - SPDX License Identifier](https://docs.soliditylang.org/en/latest/layout-of-source-files.html#spdx-license-identifier)

3. **SPDX License List**
   - [BUSL-1.1 on SPDX list](https://spdx.org/licenses/BUSL-1.1.html)
   - [Full SPDX license list](https://spdx.org/licenses/)

### Why `LicenseRef-`?

According to the [official SPDX specification](https://spdx.github.io/spdx-spec/v3.0.1/annexes/spdx-license-expressions/#simple-license-expressions):

> "An SPDX user defined license reference: `["DocumentRef-"1*(idstring)":"]"LicenseRef-"1*(idstring)`

`LicenseRef-` is an **official SPDX mechanism** for marking custom licenses that are not on the official SPDX list. In the case of Silo V3, the BSL 1.1 license has **parameterized values** (Licensor, Change Date, Additional Use Grant) that differ between versions (V2 vs V3), so using `LicenseRef-LICENSE_SILOV3` unambiguously points to a specific license document in the repository.
