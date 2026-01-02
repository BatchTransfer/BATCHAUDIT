# ERC Standards Development Survey Questions

## Demographic & Experience

### Q1
How many years of experience do you have with smart contract development?

### Q2
Self-assessed skill level: On a scale of 1–5, how would you rate your proficiency with smart contract development?

### Q3
How frequently do you work with ERC standards in your projects?

### Q4
Standards implemented: Which ERC standards have you implemented or interacted with most frequently?

---

## ERC Specifications & Documentation

### Q5_1
I find ERC standard specifications clear and easy to implement.

### Q5_2
The current documentation for ERC standards is sufficient for implementation.

### Q5_3
I regularly verify my implementations against official standard specifications.

### Q5_4
I encounter compatibility issues due to different interpretations or misunderstandings of ERC standards.

---

## Security & Implementation Practices

### Q6
Security considerations highly influence my choice of which ERC standard to implement in a project.

### Q7
It is difficult to understand these security-related terms ("Signature (ECDSA)", "Nonce", "Deadline", "DOMAIN_SEPARATOR") from the specification documents and often need expert evaluation or automated auditing for correctness.

### Q8
I choose to follow an existing, deployed contract when it comes to implementation rather than reading all specifications manually from scratch to implement.

### Q9
Analysing specific targeted functions (e.g., batch transfers, approvals) for compliance and security is more valuable than running general vulnerability scans. Example being targeted research for vulnerabilities on `safeBatchTransferFrom`, `setApprovalForAll`, etc.

### Q10
I acknowledge and ensure that my smart contract implementations adhere to the mandatory dependencies among ERC standards. I understand that several ERC standards are interdependent, with some—such as ERC-721, ERC-1155—requiring the implementation of foundational standards like ERC-165 to enable compatibility, interface detection, and secure interoperability across contracts.

**Reference links:**
- https://eips.ethereum.org/EIPS/eip-1155
- https://eips.ethereum.org/EIPS/eip-721
- https://github.com/BatchTransfer/BATCHAUDIT/blob/main/reference.md

---

## Dependencies & Interoperability

### Q11
Correctly implementing ERC dependencies significantly improves my contracts’ interoperability with wallets, dApps, and marketplaces.

### Q12
How strongly do you agree or disagree: I often verify that all mandatory ERC dependencies are fully and correctly implemented before deployment.

### Q13
I intentionally implement only part of an ERC’s specification when I believe some features are unnecessary for my use case.

### Q14_1
I find it easy to discover dependencies between different ERC standards.

### Q14_2
I have encountered interoperability issues due to missing ERC dependencies.

### Q14_3
I have deployed ERC-based smart contracts across multiple EVM-compatible chains (e.g., Ethereum, BSC, Polygon, Avalanche).

### Q14_4
The current tooling (specification documents, tools) adequately supports developers in ERC dependency management where dependencies are clearly organised with mandatory specifications.

---

## Security Considerations in Practice

### Q15_1
I am aware of security pitfalls specific to each ERC standard I implement.

### Q15_2
I prioritise security compliance over gas optimisation in standard implementation.

### Q15_3
I use specific security tools for ERC standard compliance checking.

### Q15_4
I have encountered security vulnerabilities related to incorrect standard implementation.

---

## Specific ERC-1155 & ERC-721 Security Risks

### Q16
Please rate your level of agreement:  
ERC-1155: "Batch transfer" (`safeBatchTransferFrom`) of tokens have magnified risk due to large number of tokens involved if specifications implemented incorrectly in the smart contract.

**Reference links:**
- https://eips.ethereum.org/EIPS/eip-1155
- https://eips.ethereum.org/EIPS/eip-721
- https://github.com/BatchTransfer/BATCHAUDIT/blob/main/reference.md

### Q17
I agree that there are specific phishing risks associated with `setApprovalForAll`, where a malicious actor (unauthorised operator) can trick a user into signing an order that exploits their existing, broad approval.

### Q18_1
Gravity of Risk: I believe the security risks posed by `setApprovalForAll` are a critical and widespread issue for the average NFT holder, not just a theoretical or edge-case problem.

### Q18_2
Protocol-Level Problem: I consider the current `setApprovalForAll` implementation to be a fundamental flaw in the ERC-721/1155 standards that should be addressed at the protocol level, not just through user education.

### Q18_3
Mitigation - Time-Bound Approvals: Implementing an expiry mechanism for operator approvals (e.g., `approveForAll(operator, expiryTimestamp)`) would be a highly effective way to mitigate these risks.

### Q18_4
Developer Responsibility: Smart contract developers building marketplaces or wallets have a responsibility to implement safeguards (e.g., clear warnings, default expiries) to protect users from this vulnerability.

### Q19
If an "owner" provides approval to "operator" using `setApprovalForAll` function and this "operator" continues to provide further secondary, tertiary approvals to other operators with or without owner's knowledge, do you agree that these secondary, tertiary approvals are authentic and valid cases?

---

## Token Receiver Hooks

### Q20
ERC-721, ERC-1155, ERC-1363, ERC-777: I am aware and agree that for a smart contract to safely receive tokens, it MUST implement a `tokensReceived`, `onERC1155BatchReceived`, and `onTransferReceived` hook as a critical safeguard for the function.

**Reference links:**
- https://eips.ethereum.org/EIPS/eip-1155
- https://eips.ethereum.org/EIPS/eip-721
- https://github.com/BatchTransfer/BATCHAUDIT/blob/main/reference.md

### Q21_1
Risk - Re-entrancy: I agree that these receiver hooks introduce a major re-entrancy attack vector and must be designed with the checks-effects-interactions pattern in mind.

### Q21_2
Risk - Token Lock/Loss: I understand that failing to implement receiver hook functions will result in transferred tokens being permanently locked and unrecoverable in the recipient contract for these standards.

### Q21_3
Development Diligence: In my own development, I meticulously check the token standard I am integrating and always implement the required receiver interface before deployment.

### Q21_4
Testing: I rigorously test receiver hook implementations using fuzzers/invariants to simulate malicious token contracts and unexpected call paths.

---

## Tooling & Ecosystem Needs

### Q22_1
I would benefit from automated security auditing frameworks and targeted analysis tools.

### Q22_2
Standardised "reference implementations" would improve my development process.

### Q22_3
I need better tools for managing ERC standard dependencies.

### Q22_4
The current ERC standardization process meets developer needs.

### Q23
The growing number of ERC standards makes smart contract development more difficult due to fragmentation.

### Q24
Niche ERC standards (e.g., NFT rentals, royalty management) provide valuable functionality that justifies their complexity.

---

## Future Outlook & Adoption

### Q25_1
I am confident in adopting new ERC standards quickly.

### Q25_2
The current pace of ERC standard development is appropriate.

### Q25_3
I see value in more specialised ERC standards for specific use cases.

### Q25_4
The ERC ecosystem is evolving in a developer-friendly direction.

### Q25_5
I would support stricter security and compatibility reviews before finalising new ERC standards.
