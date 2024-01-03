---
title: USTB Audit Report
author: c-n-o-t-e
date: January 3, 2024
---

# USTB Audit Report

Prepared by: C-N-O-T-E

# Table of contents

<details>

<summary>See table</summary>

- [USTB Audit Report](#ustb-audit-report)
- [Table of contents](#table-of-contents)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
- [Protocol Summary](#protocol-summary)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)

</details>
</br>

# Disclaimer

I make all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the the findings provided in this document. A security audit by me is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

# Audit Details

## Scope

```
src/
--- USTB.sol

lib/tangible-foundation-contracts/src/tokens
--- RebaseTokenUpgradeable.sol
--- LayerZeroRebaseTokenUpgradeable.sol
```

# Protocol Summary

USTB extends the functionality of `LayerZeroRebaseTokenUpgradeable` to provide additional features specific to USTB. It adds capabilities for minting and burning tokens backed by an underlying asset, and dynamically updates the rebase index.

# Executive Summary

## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| High     | 1                      |
| Medium   | 1                      |
| Low      | 1                      |

# Findings

## High

### [H-1] `totalShares` not updated when tokens are transferred from a rebase user to a non-rebase user and vice-versa

**Description:** In `RebaseTokenUpgradeable.sol`, when token transfer is done from a rebase user to a non-rebase user the shares to be transferred out isn't substracted from `totalShares` and when token transfer is done from a non-rebase user to a rebase user the shares to be transferred in isn't added to `totalShares` in the `_update()`.

**Impact:** USTB `totalSupply()` is inaccurate.

**Proof of Concept:**
The code below contains two tests:

`test_ReturnWrongTotalSupplyAfterTokenTransferFromRebaseToNonRebase()` shows how alice a rebase user transfers tokens to bob a non-rebase user and the `totalShares` of rebase tokens isn't reduced by the transferred amount.

`test_ReturnWrongTotalSupplyAfterTokenTransferFromNonRebaseToRebase()` shows how bob a non-rebase user transfers tokens to alice a rebase user and the transferred amount isn't added to the `totalShares` of non-rebase tokens.

```javascript

    function test_ReturnWrongTotalSupplyAfterTokenTransferFromRebaseToNonRebase()
        public
    {
        vm.startPrank(usdmHolder);
        usdm.transfer(alice, 100e18);
        usdm.transfer(bob, 100e18);

        vm.startPrank(alice);
        usdm.approve(address(ustb), 100e18);
        ustb.mint(alice, 100e18);

        vm.startPrank(bob);
        usdm.approve(address(ustb), 100e18);

        ustb.disableRebase(bob, true);
        ustb.mint(bob, 100e18);

        vm.roll(18349000);
        vm.startPrank(usdmController);

        (bool success, ) = address(usdm).call(
            abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12)
        );
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        vm.startPrank(alice);
        uint256 balance1 = ustb.balanceOf(alice);

        //////////////////////////// Shows Bug ////////////////////////////

        console.log(
            "Total supply before transferring tokens to bob",
            ustb.totalSupply()
        );

        uint256 totalSupplyBeforeTransfer = ustb.totalSupply();
        ustb.transfer(bob, balance1);
        uint256 totalSupplyAfterTransfer = ustb.totalSupply();

        console.log(
            "Total supply after transferring tokens to bob",
            ustb.totalSupply()
        );

        // totalSupplyBeforeTransfer is meant to be equal to totalSupplyAfterTransfer
        // because tokens are only transferred between users not burnt/minted.
        assertLt(totalSupplyBeforeTransfer, totalSupplyAfterTransfer);
    }

    function test_ReturnWrongTotalSupplyAfterTokenTransferFromNonRebaseToRebase()
        public
    {
        vm.startPrank(usdmHolder);
        usdm.transfer(bob, 100e18);
        usdm.transfer(alice, 100e18);

        vm.startPrank(bob);
        usdm.approve(address(ustb), 100e18);

        ustb.disableRebase(bob, true);
        ustb.mint(bob, 100e18);

        vm.startPrank(alice);
        usdm.approve(address(ustb), 100e18);
        ustb.mint(alice, 100e18);

        vm.roll(18349000);
        vm.startPrank(usdmController);

        (bool success, ) = address(usdm).call(
            abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12)
        );
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        vm.startPrank(bob);
        uint256 balance1 = ustb.balanceOf(bob);

        //////////////////////////// Shows Bug ////////////////////////////

        console.log(
            "Total supply before transferring tokens to bob",
            ustb.totalSupply()
        );

        uint256 totalSupplyBeforeTransfer = ustb.totalSupply();
        ustb.transfer(alice, balance1);
        uint256 totalSupplyAfterTransfer = ustb.totalSupply();

        console.log(
            "Total supply after transferring tokens to bob",
            ustb.totalSupply()
        );

        // totalSupplyBeforeTransfer is meant to be equal to totalSupplyAfterTransfer
        // because tokens are only transferred between users not burnt/minted.
        assertLt(totalSupplyAfterTransfer, totalSupplyBeforeTransfer);
    }
```

To `run` add to `USTB.t.sol`.

**Recommended Mitigation:**

After line 231 in [RebaseTokenUpgradeable.sol](https://github.com/TangibleTNFT/tangible-foundation-contracts/blob/c98ea3cb772c8c3939527be5fd1ebe21ce7e9cc3/src/tokens/RebaseTokenUpgradeable.sol#L231)

```diff
+     if (optOutTo && to != address(0)) $.totalShares -= shares;
```

After line 252 in [RebaseTokenUpgradeable.sol](https://github.com/TangibleTNFT/tangible-foundation-contracts/blob/c98ea3cb772c8c3939527be5fd1ebe21ce7e9cc3/src/tokens/RebaseTokenUpgradeable.sol#L252)

```diff
+     if (optOutFrom) $.totalShares += shares;
```

## Medium

### [M-1] Amount newly minted to non-rebase users are not checked for `totalSupply` overflow

**Description:** In `RebaseTokenUpgradeable.sol`, when a non-rebase user mints tokens the `_update()` does not check if the addition of minted `amount` plus `totalShares` plus `ERC20Upgradeable.totalSupply()` overflows.

**Impact:** When this happens calls to `RebaseTokenUpgradeable.totalSupply()` overflows thereby making `totalSupply() unreachable`.

**Proof of Concept:**
The code below contains one test:

`test_TotalSupplyUnreachableWhenNonRebaseMintsTokenAboveSupply()` shows how `totalSupply()` overflows.

```Javascript
    // To detail this error I exposed the `_mint()`

    // Add to USTB.sol
    function exposedMintForTesting(address to, uint256 amount) external mainChain(true) {
        _mint(to, amount);
    }

    // Test
    function test_TotalSupplyUnreachableWhenNonRebaseMintsTokenAboveSupply()
        public
    {
        address usdmMinter = 0x48AEB395FB0E4ff8433e9f2fa6E0579838d33B62;
        vm.startPrank(usdmMinter);

        (bool success, ) = address(usdm).call(
            abi.encodeWithSignature("mint(address,uint256)", address(3), 1e18)
        );

        assert(success);

        // Mints 1e18 rebase tokens to address(3)
        vm.startPrank(address(3));
        usdm.approve(address(ustb), type(uint256).max);
        ustb.mint(address(3), 1e18);

        // Mints max of uint256 rebase tokens to address(7)
        vm.startPrank(address(7));
        usdm.approve(address(ustb), type(uint256).max);
        ustb.disableRebase(address(7), true);
        ustb.exposedMintForTesting(address(7), type(uint256).max);

        //////////////////////////// Fails with overflow  ////////////////////////////

        // 1e18 + type(uint256).max which overflows
        vm.expectRevert();
        ustb.totalSupply();
    }
```

To `run` add to `USTB.t.sol`.

**Recommended Mitigation:**

After line 245 in [RebaseTokenUpgradeable.sol](https://github.com/TangibleTNFT/tangible-foundation-contracts/blob/c98ea3cb772c8c3939527be5fd1ebe21ce7e9cc3/src/tokens/RebaseTokenUpgradeable.sol#L245)

```diff
+   _checkTotalSupplyOverFlow(amount);

    .......................

+   error SupplyOverflow();

    .......................

+   function _checkTotalSupplyOverFlow(uint256 amount) private view {
+        unchecked {
+            if (amount + totalSupply() < totalSupply()) {
+                revert SupplyOverflow();
+            }
+        }
+    }
```

## Low

### [L-1] Fails to bridge tokens for non-rebase users

**Description:** In `LayerZeroRebaseTokenUpgradeable.sol`, when a non-rebase user tries to bridge tokens it fails because when `_debitFrom()` is called `_transferableShares()` gets called as well which is solely used to check rebase user balance before tranferring tokens, given the user trying to bridge token is a non-rebase it fails stating `AmountExceedsBalance()`

**Impact:** Fails everytime a non-rebase users tries to bridge tokens.

**Proof of Concept:**
The code below contains one test:

`test_shouldFailWhenSenderIsNonRebaseUser()` shows how a non-rebase user fails to bridge tokens.

```Javascript
    error AmountExceedsBalance(
        address account,
        uint256 balance,
        uint256 amount
    );

    function test_shouldFailWhenSenderIsNonRebaseUser() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);

        // user becomes non-rebase
        ustb.disableRebase(usdmHolder, true);
        ustb.mint(usdmHolder, 1e18);

        uint256 nativeFee;
        (nativeFee, ) = ustb.estimateSendFee(
            uint16(block.chainid),
            abi.encodePacked(alice),
            0.5e18,
            false,
            ""
        );

        // Catch AmountExceedsBalance error.
        vm.expectRevert(
            abi.encodeWithSelector(
                AmountExceedsBalance.selector,
                usdmHolder,
                0,
                0.5e18
            )
        );

        ustb.sendFrom{value: (nativeFee * 105) / 100}(
            usdmHolder,
            uint16(block.chainid),
            abi.encodePacked(alice),
            0.5e18,
            payable(usdmHolder),
            address(0),
            ""
        );
    }
```

To `run` add to `USTB.t.sol`.

**Recommended Mitigation:**

If only rebase user are allowed to bridge tokens, then after line 154 in [LayerZeroRebaseTokenUpgradeable.sol](https://github.com/TangibleTNFT/tangible-foundation-contracts/blob/c98ea3cb772c8c3939527be5fd1ebe21ce7e9cc3/src/tokens/LayerZeroRebaseTokenUpgradeable.sol#L154)

```diff
+   error OnlyRebaseTokensCanBeBridged();
    ................................

+   if (_isRebaseDisabled(from)) {
+            revert OnlyRebaseTokensCanBeBridged();
+    }
```

If both rebase and non-rebase user are allowed to bridge tokens then the logic in `_debitFrom()` needs to be rewritten.
