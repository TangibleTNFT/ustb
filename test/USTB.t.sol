// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@layerzerolabs/contracts/lzApp/mocks/LZEndpointMock.sol";

import "src/USTB.sol";

contract USTBTest is Test {
    USTB ustb;
    USTB ustbChild;

    IERC20 usdm;

    address deployer = makeAddr("deployer");
    address indexManager = makeAddr("rebase index manager");
    address alice = makeAddr("alice");

    address usdmHolder = 0xeF9A3cE48678D7e42296166865736899C3638B0E;
    address usdmController = 0xD20D492bC338ab234E6970C4B15178bcD429c01C;

    string ETHEREUM_RPC_URL = vm.envString("ETHEREUM_RPC_URL");

    function setUp() public {
        vm.createSelectFork(ETHEREUM_RPC_URL, 18348000);
        vm.label(usdmHolder, "USDM holder");

        deal(deployer, 100 ether);
        deal(alice, 100 ether);

        vm.startPrank(deployer);

        uint16 mainChainId = uint16(block.chainid);
        uint16 sideChainId = mainChainId + 1;

        USTB main = new USTB(mainChainId);

        vm.chainId(sideChainId);

        USTB child = new USTB(mainChainId);

        vm.chainId(mainChainId);

        usdm = IERC20(main.UNDERLYING());

        LZEndpointMock lzEndpoint = new LZEndpointMock(mainChainId);

        ERC1967Proxy mainProxy =
        new ERC1967Proxy(address(main), abi.encodeWithSelector(USTB.initialize.selector, address(lzEndpoint), indexManager));
        ustb = USTB(address(mainProxy));

        vm.chainId(sideChainId);

        ERC1967Proxy childProxy =
        new ERC1967Proxy(address(child), abi.encodeWithSelector(USTB.initialize.selector, address(lzEndpoint), indexManager));
        ustbChild = USTB(address(childProxy));

        vm.chainId(mainChainId);

        vm.label(address(ustbChild), "USTB (child chain)");

        lzEndpoint.setDestLzEndpoint(address(ustb), address(lzEndpoint));
        lzEndpoint.setDestLzEndpoint(address(ustbChild), address(lzEndpoint));

        bytes memory ustbAddress = abi.encodePacked(uint160(address(ustb)));
        bytes memory ustbChildAddress = abi.encodePacked(uint160(address(ustbChild)));

        ustb.setTrustedRemoteAddress(mainChainId, ustbChildAddress);
        ustbChild.setTrustedRemoteAddress(mainChainId, ustbAddress);
    }

    function test_initialize() public {
        uint256 mainChainId = block.chainid;
        uint256 sideChainId = mainChainId + 1;

        USTB instance1 = new USTB(mainChainId);

        vm.chainId(sideChainId);

        USTB instance2 = new USTB(mainChainId);

        bytes32 slot = keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1))
            & ~bytes32(uint256(0xff));
        vm.store(address(instance1), slot, 0);
        vm.store(address(instance2), slot, 0);

        instance1.initialize(address(1), address(2));
        assertEq(ustb.name(), "US T-Bill");
        assertEq(ustb.symbol(), "USTB");
        assertGt(ustb.rebaseIndex(), 1 ether);

        instance2.initialize(address(1), address(2));
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
        ustb.sendFrom{value: nativeFee * 105 / 100}(
            usdmHolder, uint16(block.chainid), abi.encodePacked(alice), 0.5e18, payable(usdmHolder), address(0), ""
        );
        assertApproxEqAbs(ustb.balanceOf(usdmHolder), 0.5e18, 2);
        assertApproxEqAbs(ustbChild.balanceOf(alice), 0.5e18, 2);

        vm.startPrank(alice);
        (nativeFee,) = ustb.estimateSendFee(
            uint16(block.chainid), abi.encodePacked(usdmHolder), ustbChild.balanceOf(alice), false, ""
        );
        ustbChild.sendFrom{value: nativeFee * 105 / 100}(
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
}
