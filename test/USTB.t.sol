// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RebaseTokenMath} from "lib/tangible-foundation-contracts/src/libraries/RebaseTokenMath.sol";

import "@layerzerolabs/contracts/lzApp/mocks/LZEndpointMock.sol";

import "src/USTB.sol";

contract USTBTest is Test {
    event RebaseEnabled(address indexed account);
    event RebaseDisabled(address indexed account);
    event RebaseIndexManagerUpdated(address manager);
    event RebaseIndexUpdated(address updatedBy, uint256 index, uint256 totalSupplyBefore, uint256 totalSupplyAfter);
    event Transfer(address indexed from, address indexed to, uint256 value);

    error CannotBridgeWhenOptedOut(address account);
    error NotAuthorized(address caller);
    error InvalidZeroAddress();
    error ValueUnchanged();
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    USTB ustb;
    USTB ustbChild;

    IERC20 usdm;

    address deployer = makeAddr("deployer");
    address indexManager = makeAddr("rebase index manager");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    address usdmHolder = 0xeF9A3cE48678D7e42296166865736899C3638B0E;
    address usdmController = 0xD20D492bC338ab234E6970C4B15178bcD429c01C;
    address usdmAddress = 0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C;

    string ETHEREUM_RPC_URL = vm.envString("ETHEREUM_RPC_URL");

    function setUp() public {
        vm.createSelectFork(ETHEREUM_RPC_URL, 18348000);
        vm.label(usdmHolder, "USDM holder");

        deal(deployer, 100 ether);
        deal(alice, 100 ether);
        deal(bob, 100 ether);

        vm.startPrank(deployer);

        uint16 mainChainId = uint16(block.chainid);

        LZEndpointMock lzEndpoint = new LZEndpointMock(mainChainId);
        USTB main = new USTB(usdmAddress, mainChainId, address(lzEndpoint));
        USTB child = new USTB(usdmAddress, mainChainId + 1, address(lzEndpoint));

        usdm = IERC20(main.UNDERLYING());

        ERC1967Proxy mainProxy =
            new ERC1967Proxy(address(main), abi.encodeWithSelector(USTB.initialize.selector, indexManager));
        ustb = USTB(address(mainProxy));

        ERC1967Proxy childProxy =
            new ERC1967Proxy(address(child), abi.encodeWithSelector(USTB.initialize.selector, indexManager));
        ustbChild = USTB(address(childProxy));

        vm.label(address(ustbChild), "USTB (child chain)");

        lzEndpoint.setDestLzEndpoint(address(ustb), address(lzEndpoint));
        lzEndpoint.setDestLzEndpoint(address(ustbChild), address(lzEndpoint));

        bytes memory ustbAddress = abi.encodePacked(address(ustb));
        bytes memory ustbChildAddress = abi.encodePacked(address(ustbChild));

        ustb.setTrustedRemoteAddress(mainChainId, ustbChildAddress);
        ustbChild.setTrustedRemoteAddress(mainChainId, ustbAddress);
    }

    function test_initialize() public {
        uint256 mainChainId = block.chainid;
        uint256 sideChainId = mainChainId + 1;

        USTB instance1 = new USTB(usdmAddress, mainChainId, address(1));

        vm.chainId(sideChainId);

        USTB instance2 = new USTB(usdmAddress, mainChainId, address(1));

        bytes32 slot = keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1))
            & ~bytes32(uint256(0xff));
        vm.store(address(instance1), slot, 0);
        vm.store(address(instance2), slot, 0);

        instance1.initialize(address(2));
        assertEq(ustb.name(), "US T-Bill");
        assertEq(ustb.symbol(), "USTB");
        assertGt(ustb.rebaseIndex(), 1 ether);

        instance2.initialize(address(2));
        assertEq(ustb.name(), "US T-Bill");
        assertEq(ustb.symbol(), "USTB");
        assertGe(ustb.rebaseIndex(), 1 ether);
    }

    function test_setRebaseIndex() public {
        vm.startPrank(indexManager);
        ustbChild.setRebaseIndex(1e18, 1);
        assertEq(ustbChild.rebaseIndex(), 1e18);
    }

    function test_setRebaseIndexManager() public {
        ustb.setRebaseIndexManager(alice);
        assertEq(ustb.rebaseIndexManager(), alice);
    }

    function test_mint() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);
        ustb.mint(usdmHolder, 1e18);
        assertApproxEqAbs(ustb.balanceOf(usdmHolder), 1e18, 1);
        assertEq(ustb.rebaseIndex(), IUSDM(address(usdm)).rewardMultiplier());
        assertEq(ustb.totalSupply(), ustb.balanceOf(usdmHolder));
    }

    function test_burn() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);
        ustb.mint(usdmHolder, 1e18);
        ustb.burn(usdmHolder, ustb.balanceOf(usdmHolder));
        assertEq(ustb.balanceOf(usdmHolder), 0);
        assertEq(ustb.totalSupply(), 0);
    }

    function test_transfer() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);
        ustb.mint(usdmHolder, 1e18);
        ustb.transfer(alice, 0.5e18);
    }

    function test_underlyingRebase() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);
        ustb.mint(usdmHolder, 1e18);

        uint256 indexBefore = ustb.rebaseIndex();
        uint256 balanceBefore = ustb.balanceOf(usdmHolder);

        vm.roll(18349000);
        vm.startPrank(usdmController);
        (bool success,) = address(usdm).call(abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12));
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        uint256 indexAfter = ustb.rebaseIndex();
        uint256 balanceAfter = ustb.balanceOf(usdmHolder);

        assertGt(indexAfter, indexBefore);
        assertGt(balanceAfter, balanceBefore);
    }

    function test_disableRebase() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);
        ustb.mint(usdmHolder, 1e18);
        ustb.disableRebase(usdmHolder, true);

        uint256 indexBefore = ustb.rebaseIndex();
        uint256 balanceBefore = ustb.balanceOf(usdmHolder);

        vm.roll(18349000);
        vm.startPrank(usdmController);
        (bool success,) = address(usdm).call(abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12));
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        uint256 indexAfter = ustb.rebaseIndex();
        uint256 balanceAfter = ustb.balanceOf(usdmHolder);

        assertGt(indexAfter, indexBefore);
        assertEq(balanceAfter, balanceBefore);

        (indexBefore, balanceBefore) = (indexAfter, balanceAfter);

        vm.startPrank(usdmHolder);
        ustb.disableRebase(usdmHolder, false);

        vm.roll(18350000);
        vm.startPrank(usdmController);
        (success,) = address(usdm).call(abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12));
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        indexAfter = ustb.rebaseIndex();
        balanceAfter = ustb.balanceOf(usdmHolder);

        assertGt(indexAfter, indexBefore);
        assertGt(balanceAfter, balanceBefore);
    }

    function test_sendFrom() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);
        ustb.mint(usdmHolder, 1e18);

        uint256 nativeFee;
        (nativeFee,) = ustb.estimateSendFee(uint16(block.chainid), abi.encodePacked(alice), 0.5e18, false, "");
        ustb.sendFrom{value: (nativeFee * 105) / 100}(
            usdmHolder, uint16(block.chainid), abi.encodePacked(alice), 0.5e18, payable(usdmHolder), address(0), ""
        );
        assertApproxEqAbs(ustb.balanceOf(usdmHolder), 0.5e18, 2);
        assertApproxEqAbs(ustbChild.balanceOf(alice), 0.5e18, 2);

        vm.startPrank(alice);
        (nativeFee,) = ustb.estimateSendFee(
            uint16(block.chainid), abi.encodePacked(usdmHolder), ustbChild.balanceOf(alice), false, ""
        );
        ustbChild.sendFrom{value: (nativeFee * 105) / 100}(
            alice,
            uint16(block.chainid),
            abi.encodePacked(usdmHolder),
            ustbChild.balanceOf(alice),
            payable(alice),
            address(0),
            ""
        );
        assertApproxEqAbs(ustb.balanceOf(usdmHolder), 1e18, 5);
        //assertEq(ustbChild.balanceOf(alice), 0);
    }

    function test_transfer_rebaseToRebase() public {
        vm.startPrank(usdmHolder);
        usdm.transfer(alice, 100e18);
        usdm.transfer(bob, 100e18);

        vm.startPrank(alice);
        usdm.approve(address(ustb), 100e18);
        ustb.mint(alice, 100e18);

        vm.startPrank(bob);
        usdm.approve(address(ustb), 100e18);
        ustb.mint(bob, 100e18);

        vm.roll(18349000);
        vm.startPrank(usdmController);
        (bool success,) = address(usdm).call(abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12));
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        vm.startPrank(alice);
        uint256 balance = ustb.balanceOf(alice);
        ustb.transfer(bob, balance);

        assertEq(ustb.balanceOf(alice), 0);
        assertApproxEqAbs(ustb.balanceOf(bob), balance + balance, 1);
    }

    function test_transfer_rebaseToNonRebase() public {
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
        (bool success,) = address(usdm).call(abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12));
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        vm.startPrank(alice);
        uint256 balance1 = ustb.balanceOf(alice);
        uint256 balance2 = ustb.balanceOf(bob);
        ustb.transfer(bob, balance1);

        assertEq(ustb.balanceOf(alice), 0);
        assertApproxEqAbs(ustb.balanceOf(bob), balance1 + balance2, 1);
    }

    function test_transfer_nonRebaseToRebase() public {
        vm.startPrank(usdmHolder);
        usdm.transfer(alice, 100e18);
        usdm.transfer(bob, 100e18);

        vm.startPrank(alice);
        usdm.approve(address(ustb), 100e18);
        ustb.disableRebase(alice, true);
        ustb.mint(alice, 100e18);

        vm.startPrank(bob);
        usdm.approve(address(ustb), 100e18);
        ustb.mint(bob, 100e18);

        vm.roll(18349000);
        vm.startPrank(usdmController);
        (bool success,) = address(usdm).call(abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12));
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        vm.startPrank(alice);
        uint256 balance1 = ustb.balanceOf(alice);
        uint256 balance2 = ustb.balanceOf(bob);
        ustb.transfer(bob, balance1);

        assertApproxEqAbs(ustb.balanceOf(alice), 0, 1);
        assertApproxEqAbs(ustb.balanceOf(bob), balance1 + balance2, 1);
    }

    function test_transfer_nonRebaseToNonRebase() public {
        vm.startPrank(usdmHolder);
        usdm.transfer(alice, 100e18);
        usdm.transfer(bob, 100e18);

        vm.startPrank(alice);
        usdm.approve(address(ustb), 100e18);
        ustb.disableRebase(alice, true);
        ustb.mint(alice, 100e18);

        vm.startPrank(bob);
        usdm.approve(address(ustb), 100e18);
        ustb.disableRebase(bob, true);
        ustb.mint(bob, 100e18);

        vm.roll(18349000);
        vm.startPrank(usdmController);
        (bool success,) = address(usdm).call(abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12));
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        vm.startPrank(alice);
        uint256 balance = ustb.balanceOf(alice);
        ustb.transfer(bob, balance);

        assertEq(ustb.balanceOf(alice), 0);
        assertApproxEqAbs(ustb.balanceOf(bob), balance + balance, 1);
    }

    /////////////////////////////// NEW TEST ///////////////////////////////////

    function test_shouldFailTodisableRebaseIfCallerIsNotAuthorized() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);

        ustb.mint(usdmHolder, 1e18);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector, address(this)));

        ustb.disableRebase(usdmHolder, true);
    }

    function test_shouldFailToDisableRebaseIfValueIsUnchanged() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);

        ustb.mint(usdmHolder, 1e18);
        vm.expectRevert(abi.encodeWithSelector(ValueUnchanged.selector));

        ustb.disableRebase(usdmHolder, false);
    }

    function test_burnViaApprovedAddress() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);

        ustb.mint(usdmHolder, 1e18);
        ustb.approve(address(this), 1e18);

        vm.stopPrank();
        ustb.burn(usdmHolder, ustb.balanceOf(usdmHolder));

        assertEq(ustb.balanceOf(usdmHolder), 0);
        assertEq(ustb.totalSupply(), 0);
    }

    function test_failToBurnTokenFromNotApprovedOrOwner() public {
        vm.startPrank(usdmHolder);

        usdm.approve(address(ustb), 1e18);
        ustb.mint(usdmHolder, 1e18);

        ustb.approve(address(this), 1e18);
        vm.stopPrank();

        ustb.burn(usdmHolder, ustb.balanceOf(usdmHolder));

        assertEq(ustb.balanceOf(usdmHolder), 0);
        assertEq(ustb.totalSupply(), 0);
    }

    function test_shouldFailToSetRebaseIndex() public {
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector, deployer));
        ustbChild.setRebaseIndex(1e18, 1);
        assertEq(ustbChild.rebaseIndex(), 1e18);
    }

    function test_shouldFailTosetRebaseIndexManager() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidZeroAddress.selector));
        ustb.setRebaseIndexManager(address(0));
    }

    function test_returnWrongTotalSupplyAfterTokenTransferFromRebaseToNonRebase() public {
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

        (bool success,) = address(usdm).call(abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12));
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        vm.startPrank(alice);
        uint256 balance1 = ustb.balanceOf(alice);

        console.log("Total supply before transferring tokens to bob", ustb.totalSupply());

        uint256 totalSupplyBeforeTransfer = ustb.totalSupply();
        ustb.transfer(bob, balance1);
        uint256 totalSupplyAfterTransfer = ustb.totalSupply();

        console.log("Total supply after transferring tokens to bob", ustb.totalSupply());

        // totalSupplyBeforeTransfer is meant to be equal to totalSupplyAfterTransfer
        // because tokens are only transferred between users not burnt/minted.
        assertEq(totalSupplyBeforeTransfer, totalSupplyAfterTransfer);
    }

    function test_returnWrongTotalSupplyAfterTokenTransferFromNonRebaseToRebase() public {
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

        (bool success,) = address(usdm).call(abi.encodeWithSignature("addRewardMultiplier(uint256)", 134e12));
        assert(success);

        vm.startPrank(indexManager);
        ustb.refreshRebaseIndex(); // force update

        vm.startPrank(bob);
        uint256 balance1 = ustb.balanceOf(bob);

        console.log("Total supply before transferring tokens to bob", ustb.totalSupply());

        uint256 totalSupplyBeforeTransfer = ustb.totalSupply();
        ustb.transfer(alice, balance1);
        uint256 totalSupplyAfterTransfer = ustb.totalSupply();

        console.log("Total supply after transferring tokens to bob", ustb.totalSupply());

        // totalSupplyBeforeTransfer is meant to be equal to totalSupplyAfterTransfer
        // because tokens are only transferred between users not burnt/minted.
        assertEq(totalSupplyAfterTransfer, totalSupplyBeforeTransfer);
    }

    function test_shouldFailWhenSenderIsNonRebaseUser() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 1e18);

        // user becomes non-rebase
        ustb.disableRebase(usdmHolder, true);
        ustb.mint(usdmHolder, 1e18);

        uint256 nativeFee;
        (nativeFee,) = ustb.estimateSendFee(uint16(block.chainid), abi.encodePacked(alice), 0.5e18, false, "");

        vm.expectRevert(abi.encodeWithSelector(CannotBridgeWhenOptedOut.selector, usdmHolder));
        ustb.sendFrom{value: (nativeFee * 105) / 100}(
            usdmHolder, uint16(block.chainid), abi.encodePacked(alice), 0.5e18, payable(usdmHolder), address(0), ""
        );
    }

    //////////////////////////// Event Test ////////////////////////////

    function test_setRebaseIndexManagerEvent() public {
        vm.expectEmit();
        emit RebaseIndexManagerUpdated(alice);

        ustb.setRebaseIndexManager(alice);
    }

    function test_shouldEmitRebaseDisabled() public {
        vm.startPrank(usdmHolder);
        vm.expectEmit();

        emit RebaseDisabled(usdmHolder);
        ustb.disableRebase(usdmHolder, true);
    }

    function test_shouldEmitRebaseEnabled() public {
        vm.startPrank(usdmHolder);
        ustb.disableRebase(usdmHolder, true);

        vm.expectEmit();

        emit RebaseEnabled(usdmHolder);
        ustb.disableRebase(usdmHolder, false);
    }

    function test_setRebaseIndexEvent() public {
        vm.startPrank(indexManager);
        vm.expectEmit();

        emit RebaseIndexUpdated(indexManager, 2e18, 0, 0);
        ustbChild.setRebaseIndex(2e18, 1);
    }

    function test_eventTransferFromRebaseToRebase() public {
        vm.startPrank(usdmHolder);
        usdm.transfer(alice, 100e18);

        vm.startPrank(alice);
        usdm.approve(address(ustb), 100e18);

        ustb.mint(alice, 100e18);
        uint256 balance = ustb.balanceOf(alice);
        vm.expectEmit();

        emit Transfer(alice, bob, balance);
        ustb.transfer(bob, balance);
    }

    function test_eventTransferFromNonRebaseToNonRebase() public {
        vm.startPrank(usdmHolder);
        usdm.transfer(alice, 100e18);

        vm.startPrank(bob);
        ustb.disableRebase(bob, true);

        vm.startPrank(alice);
        usdm.approve(address(ustb), 100e18);

        ustb.disableRebase(alice, true);
        ustb.mint(alice, 100e18);

        uint256 balance = ustb.balanceOf(alice);
        vm.expectEmit();

        emit Transfer(alice, bob, balance);
        ustb.transfer(bob, balance);
    }

    function test_eventTransferFromRebaseToNonRebase() public {
        vm.startPrank(usdmHolder);
        usdm.transfer(alice, 100e18);

        vm.startPrank(bob);
        ustb.disableRebase(bob, true);

        vm.startPrank(alice);
        usdm.approve(address(ustb), 100e18);

        ustb.mint(alice, 100e18);
        uint256 balance = ustb.balanceOf(alice);
        vm.expectEmit();

        emit Transfer(alice, address(0), balance);
        emit Transfer(address(0), bob, balance);
        ustb.transfer(bob, balance);
    }

    function test_eventTransferFromNonRebaseToRebase() public {
        vm.startPrank(usdmHolder);
        usdm.transfer(alice, 100e18);

        vm.startPrank(alice);
        ustb.disableRebase(alice, true);

        usdm.approve(address(ustb), 100e18);
        ustb.mint(alice, 100e18);

        uint256 balance = ustb.balanceOf(alice);
        uint256 rebaseIndex = ustb.rebaseIndex();
        uint256 transferBalance = RebaseTokenMath.toTokens(RebaseTokenMath.toShares(balance, rebaseIndex), rebaseIndex);

        vm.expectEmit();

        emit Transfer(alice, address(0), transferBalance);
        emit Transfer(address(0), bob, transferBalance);
        ustb.transfer(bob, balance);
    }

    function test_eventTransferOnMint() public {
        vm.startPrank(usdmHolder);
        usdm.transfer(alice, 100e18);
        usdm.transfer(bob, 100e18);

        vm.startPrank(alice);
        ustb.disableRebase(alice, true);
        usdm.approve(address(ustb), 100e18);

        vm.expectEmit();
        emit Transfer(address(0), alice, 100e18);
        ustb.mint(alice, 100e18);

        vm.startPrank(bob);
        usdm.approve(address(ustb), 100e18);

        vm.expectEmit();
        emit Transfer(address(0), bob, 100e18 - 1);
        ustb.mint(bob, 100e18);
    }

    function test_eventTransferOnBurn() public {
        vm.startPrank(usdmHolder);
        usdm.approve(address(ustb), 200e18);
        ustb.mint(alice, 100e18);
        ustb.mint(bob, 100e18);

        vm.startPrank(alice);
        ustb.disableRebase(alice, true);

        vm.expectEmit();
        emit Transfer(alice, address(0), 100e18 - 1);
        ustb.burn(alice, 100e18);

        vm.startPrank(bob);

        vm.expectEmit();
        emit Transfer(bob, address(0), 100e18 - 1);
        ustb.burn(bob, 100e18 - 1);
    }
}
