// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {USDM} from "./USDM.sol";
import {USTB} from "../../src/USTB.sol";
import {Handler, RebaseTokenMath} from "./Handler.sol";
import {Test, console2 as console} from "forge-std/Test.sol";
import {LZEndpointMock} from "@layerzerolabs/contracts/lzApp/mocks/LZEndpointMock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract USTBInvariants is Test {
    using RebaseTokenMath for uint256;

    USTB public ustb;
    USTB ustbChild;
    USDM public usdm;
    Handler public handler;

    function setUp() public {
        uint16 mainChainId = uint16(block.chainid);
        uint16 sideChainId = mainChainId + 1;

        usdm = new USDM();

        LZEndpointMock lzEndpoint = new LZEndpointMock(mainChainId);
        ustb = new USTB(address(usdm), mainChainId, address(lzEndpoint));

        vm.chainId(sideChainId);

        USTB child = new USTB(address(usdm), mainChainId, address(lzEndpoint));

        vm.chainId(mainChainId);

        ERC1967Proxy mainProxy =
            new ERC1967Proxy(address(ustb), abi.encodeWithSelector(USTB.initialize.selector, address(2)));

        ustb = USTB(address(mainProxy));

        vm.chainId(sideChainId);

        ERC1967Proxy childProxy =
            new ERC1967Proxy(address(child), abi.encodeWithSelector(USTB.initialize.selector, address(2)));

        ustbChild = USTB(address(childProxy));

        vm.chainId(mainChainId);

        lzEndpoint.setDestLzEndpoint(address(ustb), address(lzEndpoint));
        lzEndpoint.setDestLzEndpoint(address(ustbChild), address(lzEndpoint));

        bytes memory ustbAddress = abi.encodePacked(uint160(address(ustb)));
        bytes memory ustbChildAddress = abi.encodePacked(uint160(address(ustbChild)));

        ustb.setTrustedRemoteAddress(mainChainId, ustbChildAddress);
        ustbChild.setTrustedRemoteAddress(mainChainId, ustbAddress);

        handler = new Handler(ustb, ustbChild, address(usdm));

        bytes4[] memory selectors = new bytes4[](7);

        selectors[0] = Handler.mint.selector;
        selectors[1] = Handler.burn.selector;
        selectors[2] = Handler.disable.selector;
        selectors[3] = Handler.transfer.selector;
        selectors[4] = Handler.sendFrom.selector;
        selectors[5] = Handler.transferFrom.selector;
        selectors[6] = Handler.approve.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));

        targetContract(address(handler));
    }

    // The USTB contract's token balance should always be
    // at least as much as the sum of individual mints.
    function invariant_mint() public {
        assertEq(handler.ghost_mintedSum() - handler.ghost_burntSum(), ustb.totalSupply());
    }

    // All to and fro bridging should be balanced out.
    function invariant_bridgedToken() public {
        assertEq(handler.ghost_bridgedTokensTo() - handler.ghost_bridgedTokensFrom(), 0);
    }

    // The USTB contract's token balance should always be
    // at least as much as the sum of individual balances
    function invariant_totalBalance() public {
        uint256 sumOfBalances = handler.reduceActors(0, this.accumulateBalance);
        assertEq(sumOfBalances, ustb.totalSupply());
    }

    // No individual account balance can exceed the USTB totalSupply().
    function invariant_userBalances() public {
        handler.forEachActor(this.assertAccountBalanceLteTotalSupply);
    }

    function assertAccountBalanceLteTotalSupply(address account) external {
        assertLe(ustb.balanceOf(account), ustb.totalSupply());
    }

    function accumulateBalance(uint256 balance, address caller) external view returns (uint256) {
        return balance + ustb.balanceOf(caller);
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
