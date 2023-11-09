# USTB (US T-Bill) Smart Contract

## Introduction
The USTB token contract simulates US Treasury Bills within the blockchain environment. It utilizes the Tangible Framework to implement rebase and cross-chain interoperability features, providing an elastic supply token that mirrors the financial characteristics of Treasury Bills.

## Features
- **Rebase Functionality**: Adapts rebase mechanisms to represent the economic indicators of Treasury Bills.
- **Cross-Chain Capabilities**: Facilitates interoperability across multiple blockchain networks.
- **Minting & Burning**: Reflects the issuance and redemption processes inherent to Treasury Bills.
- **Dynamic Rebase Index**: Adjusts the token supply in response to the performance of the underlying assets.
- **Upgradeable**: Incorporates the UUPS upgradeable proxy pattern to facilitate future improvements.

## Getting Started
### Prerequisites
- Solidity ^0.8.20
- Foundry for smart contract development and testing

### Installation
To set up the USTB project using Foundry, run the following commands:

```bash
git clone https://github.com/TangibleTNFT/ustb
cd ustb
forge install
```

This will initialize the Foundry project and install the `tangible-foundation-contracts` along with other dependencies.

## Contract Architecture
- `USTB.sol`: The core contract for the USTB token, integrating Treasury Bill-specific logic with the broader capabilities of the Tangible Framework.
- `IUSDM.sol`: Interface for interaction with the USDM stablecoin.
- `IUSTB.sol`: Interface for USTB-specific functionalities.

## Development and Testing
Adhere to Foundry's standard practices for development and testing. Utilize the tools provided by Foundry to compile, test, and deploy the contracts. The `script` directory includes scripts for deployment and interaction.

## License
The USTB project is open-source and licensed under the MIT License. For more information, see the [LICENSE](LICENSE) file.

## Support
For any technical issues or support, please file an issue in the GitHub repository or contact the development team directly.

## Acknowledgments
- Tangible Team for the foundational smart contract architecture.
- OpenZeppelin for secure, standardized smart contract development tools.
- Omniscia for their diligent audit of the smart contract codebase.
