// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeploymentScriptBase is Script {
    bytes32 internal constant _SALT = keccak256("tangible.deployer");

    address internal _deployer;
    address internal _proxyAdminAddress;

    uint256 private _pk;

    ProxyAdmin _proxyAdmin;

    modifier broadcast() {
        _loadPrivateKey();
        vm.startBroadcast(_pk);
        _setup();
        _;
        vm.stopBroadcast();
    }

    function _loadPrivateKey() internal {
        if (block.chainid == getChain("anvil").chainId) {
            _pk = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        } else {
            _pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        }
        _deployer = vm.addr(_pk);
    }

    function _setup() internal {
        bytes memory bytecode = abi.encodePacked(type(ProxyAdmin).creationCode, abi.encode(_deployer));

        _proxyAdminAddress = computeCreate2Address(_SALT, keccak256(bytecode));

        if (_isDeployed(_proxyAdminAddress)) {
            console.log("Proxy admin is already deployed to %s", _proxyAdminAddress);
            _proxyAdmin = ProxyAdmin(_proxyAdminAddress);
        } else {
            _proxyAdmin = new ProxyAdmin{salt: _SALT}(_deployer);
            assert(_proxyAdminAddress == address(_proxyAdmin));
            console.log("Proxy admin deployed to %s", _proxyAdminAddress);
        }
    }

    function _deployTransparentProxy(string memory forContract, address implementation, bytes memory data)
        public
        returns (address proxyAddress)
    {
        bytes memory bytecode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode, abi.encode(implementation, _proxyAdminAddress, data)
        );

        bytes32 salt = keccak256(abi.encodePacked(_SALT, forContract));

        proxyAddress = computeCreate2Address(salt, keccak256(bytecode));

        if (_isDeployed(proxyAddress)) {
            console.log("Proxy is already deployed to %s", proxyAddress);
        } else {
            TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{
                salt: salt
            }(implementation, _proxyAdminAddress, data);
            assert(proxyAddress == address(proxy));
            console.log("Proxy deployed to %s", proxyAddress);
        }
    }

    function _isDeployed(address contractAddress) internal view returns (bool isDeployed) {
        assembly {
            let cs := extcodesize(contractAddress)
            if iszero(iszero(cs)) { isDeployed := true }
        }
    }
}
