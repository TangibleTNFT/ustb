Findings
High

### [H-1] `totalShares` not updated when tokens are transferred from a rebase user to a non-rebase user and vice-versa

**Description:** In the `RebaseTokenUpgradeable.sol`, when token transfer is done from a rebase user to a non-rebase user the shares to be transferred out isn't substracted from `totalShares` and when token transfer is done from a non-rebase user to a rebase user the shares to be transferred in isn't added to `totalShares` in the `_update()`.

**Impact:** USTB `totalSupply()` is inaccurate.

**Proof of Concept:**
The code below contains two tests:

`test_ReturnWrongTotalSupplyAfterTokenTransferFromRebaseToNonRebase()` shows how alice a rebase user transfers tokens to bob a non-rebase user and the `totalShares` of rebase tokens isn't reduced by the transferred amount.

`test_ReturnWrongTotalSupplyAfterTokenTransferFromNonRebaseToRebase()` show how bob a non-rebase user transfers tokens to alice a rebase user and the transferred amount isn't added to the `totalShares` of non-rebase tokens.

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
            ustb.totalSupply(),
            "Total supply before transferring tokens to bob"
        );

        uint256 totalSupplyBeforeTransfer = ustb.totalSupply();
        ustb.transfer(bob, balance1);
        uint256 totalSupplyAfterTransfer = ustb.totalSupply();

        console.log(
            ustb.totalSupply(),
            "Total supply after transferring tokens to bob"
        );

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
            ustb.totalSupply(),
            "Total supply before transferring tokens to alice"
        );

        uint256 totalSupplyBeforeTransfer = ustb.totalSupply();
        ustb.transfer(alice, balance1);
        uint256 totalSupplyAfterTransfer = ustb.totalSupply();

        console.log(
            ustb.totalSupply(),
            "Total supply after transferring tokens to alice"
        );

        assertLt(totalSupplyAfterTransfer, totalSupplyBeforeTransfer);
    }
```

**Recommended Mitigation:**

```diff
After line 231 in RebaseTokenUpgradeable.sol
+     if (optOutTo && to != address(0)) $.totalShares -= shares;

After line 252 in RebaseTokenUpgradeable.sol
+     if (optOutFrom) $.totalShares += shares;
```
