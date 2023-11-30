# USTB Token Project

## Overview

The USTB Token project is a Solidity-based smart contract system designed to provide a rebase token with cross-chain and Layer Zero functionalities. It's built with upgradeability in mind, ensuring that the token logic can evolve over time.

## Key Components

### Contracts

- `CrossChainToken.sol`: Defines basic cross-chain functionalities.
- `CrossChainRebaseTokenUpgradeable.sol`: Manages cross-chain functionalities for a rebase token.
- `LayerZeroRebaseTokenUpgradeable.sol`: Adds LayerZero functionalities to a rebase token.
- `RebaseTokenUpgradeable.sol`: Base contract for a rebase token with upgradeability features.
- `USTB.sol`: The main contract for the USTB token, inheriting features from the above contracts.
- `LzAppUpgradeable.sol` and `NonblockingLzAppUpgradeable.sol`: Manage LayerZero applications with upgradeability.
- `OFTCoreUpgradeable.sol` and `OFTUpgradeable.sol`: Define OFT functionalities with upgradeability.

### Interfaces

- `IUSDM.sol`: Defines functionalities related to USDM.
- `IUSTB.sol`: Defines functionalities related to USTB.

### Libraries

- `RebaseTokenMath.sol`: Provides mathematical operations for rebase tokens.

## Installation and Setup

1. Clone the repository
2. Create an `.env` file based on `.env.example`
3. Compile the contracts using Foundry (`forge build`)

## Tests

Run the tests using the following command:

```bash
forge test
```

## Deployment

```bash
# deploy on testnets
FOUNDRY_PROFILE=optimized forge script ./script/DeployAllTestnet.s.sol --legacy --broadcast

# deploy on mainnets
FOUNDRY_PROFILE=optimized forge script ./script/DeployAll.s.sol --legacy --broadcast
```

## License

This project is licensed under the terms specified in the `LICENSE` file.
