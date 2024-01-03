// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {USTB, IERC20} from "../../src/USTB.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {console2 as console} from "forge-std/Test.sol";
import {AddressSet, LibAddressSet} from "./LibAddressSet.sol";
import {RebaseTokenMath} from "tangible-foundation-contracts/libraries/RebaseTokenMath.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    using RebaseTokenMath for uint256;
    using LibAddressSet for AddressSet;

    AddressSet internal _actors;

    USTB public ustb;
    USTB public ustb2;
    IERC20 usdm;

    mapping(bytes32 => uint256) public calls;

    address currentActor;
    uint256 public ghost_burntSum;
    uint256 public ghost_zeroBurn;

    uint256 public ghost_zeroMint;
    uint256 public ghost_mintedSum;

    uint256 public ghost_actualBurn;
    uint256 public ghost_actualMint;

    uint256 public ghost_enableRebase;
    uint256 public ghost_zeroTransfer;

    uint256 public ghost_disableRebase;
    uint256 public ghost_actualSendFrom;

    uint256 public ghost_actualTransfer;
    uint256 public ghost_bridgedTokensTo;

    uint256 public ghost_zeroAddressBurn;
    uint256 public ghost_zeroTransferFrom;

    uint256 public ghost_bridgedTokensFrom;
    uint256 public ghost_actualTransferFrom;

    uint256 public ghost_zeroAddressTransfer;
    uint256 public ghost_zeroAddressSendFrom;

    uint256 public ghost_zeroAddressTransferFrom;
    uint256 public ghost_zeroAddressDisableRebase;

    constructor(USTB _ustb, USTB _ustb2, address _usdm) {
        ustb = _ustb;
        ustb2 = _ustb2;
        usdm = IERC20(_usdm);
    }

    modifier createActor() {
        currentActor = msg.sender;
        _actors.add(currentActor);
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = _actors.rand(actorIndexSeed);
        _;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    function mint(uint256 amount) public createActor countCall("mint") {
        amount = bound(amount, 0, type(uint96).max);
        ghost_mintedSum += amount;

        if (amount == 0) ghost_zeroMint++;
        if (amount > 0) ghost_actualMint++;

        address to = currentActor;

        __mint(currentActor, amount);
        vm.startPrank(currentActor);

        usdm.approve(address(ustb), amount);
        ustb.mint(to, amount);
    }

    function burn(
        uint seed,
        uint256 amount
    ) public useActor(seed) countCall("burn") {
        if (currentActor != address(0)) {
            amount = bound(amount, 0, ustb.balanceOf(currentActor));
            ghost_burntSum += amount;

            ghost_actualBurn++;
            if (amount == 0) ghost_zeroBurn++;

            address from = currentActor;

            vm.startPrank(currentActor);
            ustb.burn(from, amount);
        } else ghost_zeroAddressBurn++;
    }

    function approve(
        uint256 actorSeed,
        uint256 spenderSeed,
        uint256 amount
    ) public useActor(actorSeed) countCall("approve") {
        address spender = _actors.rand(spenderSeed);
        if (currentActor != address(0)) {
            vm.startPrank(currentActor);
            ustb.approve(spender, amount);
        }
    }

    function disable(
        uint256 seed,
        bool flag
    ) public useActor(seed) countCall("disableRebase") {
        if (
            currentActor != address(0) && flag != ustb.isNotRebase(currentActor)
        ) {
            vm.startPrank(currentActor);

            ustb.disableRebase(currentActor, flag);
        } else ghost_zeroAddressDisableRebase++;
    }

    function transfer(
        uint256 actorSeed,
        uint256 toSeed,
        uint256 amount
    ) public useActor(actorSeed) countCall("transfer") {
        address to = _actors.rand(toSeed);

        if (currentActor != address(0)) {
            vm.deal(currentActor, 1 ether);
            amount = bound(amount, 0, ustb.balanceOf(currentActor));

            ghost_actualTransfer++;
            if (amount == 0) ghost_zeroTransfer++;

            vm.startPrank(currentActor);
            ustb.transfer(to, amount);
        } else ghost_zeroAddressTransfer++;
    }

    function sendFrom(
        uint256 actorSeed,
        uint256 toSeed,
        uint256 amount
    ) public useActor(actorSeed) countCall("sendFrom") {
        if (!ustb.isNotRebase(currentActor)) {
            address to = _actors.rand(toSeed);
            if (currentActor != address(0)) {
                ghost_actualSendFrom++;
                vm.deal(to, 10 ether);

                vm.deal(currentActor, 10 ether);
                amount = bound(amount, 0, ustb.balanceOf(currentActor));

                if (amount == 0) ghost_zeroTransfer++;
                vm.startPrank(currentActor);

                usdm.approve(address(ustb), amount);
                uint256 nativeFee;

                (nativeFee, ) = ustb.estimateSendFee(
                    uint16(block.chainid),
                    abi.encodePacked(to),
                    amount,
                    false,
                    ""
                );

                uint256 contractBalBeforeBridge = ustb.balanceOf(address(this));

                ustb.sendFrom{value: (nativeFee * 105) / 100}(
                    currentActor,
                    uint16(block.chainid),
                    abi.encodePacked(to),
                    amount,
                    payable(currentActor),
                    address(0),
                    ""
                );

                uint256 contractBalAfterBridge = ustb.balanceOf(address(this));

                ghost_bridgedTokensTo +=
                    contractBalAfterBridge -
                    contractBalBeforeBridge;

                vm.startPrank(to);

                (nativeFee, ) = ustb.estimateSendFee(
                    uint16(block.chainid),
                    abi.encodePacked(currentActor),
                    ustb2.balanceOf(to),
                    false,
                    ""
                );

                uint256 contractBalBeforeBridge0 = ustb.balanceOf(
                    address(this)
                );

                ustb2.sendFrom{value: (nativeFee * 105) / 100}(
                    to,
                    uint16(block.chainid),
                    abi.encodePacked(currentActor),
                    ustb2.balanceOf(to),
                    payable(to),
                    address(0),
                    ""
                );

                uint256 contractBalAfterBridge0 = ustb2.balanceOf(
                    address(this)
                );

                ghost_bridgedTokensFrom +=
                    contractBalBeforeBridge0 -
                    contractBalAfterBridge0;
            } else ghost_zeroAddressSendFrom++;
        }
    }

    function transferFrom(
        uint256 actorSeed,
        uint256 fromSeed,
        uint256 toSeed,
        bool _approve,
        uint256 amount
    ) public useActor(actorSeed) countCall("transferFrom") {
        address from = _actors.rand(fromSeed);
        address to = _actors.rand(toSeed);
        amount = bound(amount, 0, ustb.balanceOf(from));

        if (currentActor != address(0)) {
            if (_approve) {
                vm.startPrank(from);
                ustb.approve(currentActor, amount);
                vm.stopPrank();
            } else {
                amount = bound(amount, 0, ustb.allowance(from, currentActor));
            }

            ghost_actualTransferFrom++;
            if (amount == 0) ghost_zeroTransferFrom++;

            vm.startPrank(currentActor);
            ustb.transferFrom(from, to, amount);

            vm.stopPrank();
        } else ghost_zeroAddressTransferFrom++;
    }

    function reduceActors(
        uint256 acc,
        function(uint256, address) external returns (uint256) func
    ) public returns (uint256) {
        return _actors.reduce(acc, func);
    }

    function forEachActor(function(address) external func) public {
        return _actors.forEach(func);
    }

    function callSummary() external view {
        console.log("-------------------");
        console.log("  ");
        console.log("Call summary:");
        console.log("  ");

        console.log("-------------------");
        console.log("Call Count:");
        console.log("-------------------");
        console.log("Mint(s)", calls["mint"]);
        console.log("Burn(s)", calls["burn"]);
        console.log("Approve(s)", calls["approve"]);
        console.log("Transfer(s):", calls["transfer"]);
        console.log("SendFrom(s):", calls["sendFrom"]);
        console.log("TransferFrom(s):", calls["transferFrom"]);
        console.log("DisableRebase(s):", calls["disableRebase"]);

        console.log("-------------------");
        console.log("Zero Calls:");
        console.log("-------------------");
        console.log("Mint(s):", ghost_zeroMint);
        console.log("Burn(s):", ghost_zeroBurn);
        console.log("Transfer(s):", ghost_zeroTransfer);
        console.log("TransferFrom(s):", ghost_zeroTransferFrom);

        console.log("-------------------");
        console.log("Zero Address Call:");
        console.log("-------------------");
        console.log("Burn(s):", ghost_zeroAddressBurn);
        console.log("Transfer(s):", ghost_zeroAddressTransfer);
        console.log("sendFrom(s):", ghost_zeroAddressSendFrom);
        console.log("TransferFrom(s):", ghost_zeroAddressTransferFrom);
        console.log("DisableRebase(s):", ghost_zeroAddressDisableRebase);

        console.log("-------------------");
        console.log("Actual Calls:");
        console.log("-------------------");
        console.log("Mint(s):", ghost_actualMint);
        console.log("Burn(s):", ghost_actualBurn);
        console.log("SendFrom(s):", ghost_actualSendFrom);
        console.log("Transfer(s):", ghost_actualTransfer);
        console.log("Enable Rebase:", ghost_enableRebase);
        console.log("Disable Rebase:", ghost_disableRebase);
        console.log("TransferFrom(s):", ghost_actualTransferFrom);
    }

    function __mint(address addr, uint256 amount) internal {
        (bool success, ) = address(usdm).call(
            abi.encodeWithSignature("mintTokens(address,uint256)", addr, amount)
        );
        assert(success);
    }
}
