// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC1967Utils, ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {EmptyUUPS} from "./EmptyUUPS.sol";

/**
 * @title DeploymentScriptBase
 * @author Caesar LaVey
 * @dev This base contract is designed to facilitate the deployment and upgrade of UUPS proxies using CREATE2 for
 * deterministic address generation. It is a foundational element in the deployment script system.
 *
 * The contract employs EmptyUUPS as the initial implementation behind each new proxy. This design choice yields several
 * advantages:
 *
 * Flexibility:
 * 1. Known Initial State: Utilizing EmptyUUPS ensures that each proxy starts from a minimal, known initial state. This
 *    simplifies the upgrade process by providing a clear, audited baseline.
 * 2. Decoupled Deployment: Since the proxy starts with EmptyUUPS, it can be immediately upgraded to any other contract
 *    prepared for proxy usage. This decouples the proxy's deployment from the deployment of the actual logic contract,
 *    offering more agile deployment strategies.
 * 3. Cross-Chain Consistency: Using EmptyUUPS as the initial implementation for all proxies allows for the same proxy
 *    address to be employed across multiple chains. This is particularly beneficial for user experience and any
 *    cross-chain functionality.
 *
 * Security:
 * 1. Easier Audits: Having a simple, audited EmptyUUPS contract as the initial implementation reduces the complexity of
 *    the auditing process. Future contract upgrades only need to be audited with the understanding that they are
 *    upgrading from this secure initial state.
 * 2. Built-In Access Control: EmptyUUPS is be designed with a minimalistic yet robust access control mechanism for
 *    upgrades. This minimizes the attack surface by ensuring only authorized addresses can initiate an upgrade.
 * 3. Predictable Upgrades: Starting each proxy with a known and audited EmptyUUPS implementation minimizes the risk of
 *    unexpected behavior or security vulnerabilities when the proxy is later upgraded to a new implementation.
 */
contract DeploymentScriptBase is Script {
    /// @notice Slot for the proxy's implementation address, based on EIP-1967.
    bytes32 internal constant PROXY_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @notice Salt used for generating CREATE2 addresses.
    bytes32 internal constant _SALT = keccak256("tangible.deployer");

    /// @notice Address of the deployer.
    address internal _deployer;

    /// @dev Private key used for broadcasting.
    uint256 private _pk;

    /// @dev Address for the initial EmptyUUPS implementation.
    address private _emptyUUPS;

    /// @dev Modifier to handle broadcasting and initial setup.
    modifier broadcast() {
        _loadPrivateKey();
        vm.startBroadcast(_pk);
        _setup();
        _;
        vm.stopBroadcast();
    }

    /// @dev Loads the private key from an environment variable.
    /// Sets the deployer address based on the loaded private key.
    function _loadPrivateKey() internal {
        _pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        _deployer = vm.addr(_pk);
    }

    /// @dev Initializes the contract by deploying the EmptyUUPS implementation if not already deployed.
    function _setup() internal {
        bytes32 initCodeHash = hashInitCode(type(EmptyUUPS).creationCode, abi.encode(_deployer));
        _emptyUUPS = computeCreate2Address(_SALT, initCodeHash);

        if (!_isDeployed(_emptyUUPS)) {
            EmptyUUPS emptyUUPS = new EmptyUUPS{salt: _SALT}(_deployer);
            assert(address(emptyUUPS) == _emptyUUPS);
            console.log("Empty UUPS implementation contract deployed to %s", _emptyUUPS);
        }
    }

    /// @dev Computes the proxy address and salt based on the contract name.
    function _computeProxyAddress(string memory forContract)
        internal
        view
        returns (address proxyAddress, bytes32 salt)
    {
        bytes32 initCodeHash = hashInitCode(type(ERC1967Proxy).creationCode, abi.encode(_emptyUUPS, ""));
        salt = keccak256(abi.encodePacked(_SALT, forContract));
        proxyAddress = computeCreate2Address(salt, initCodeHash);
    }

    /**
     * @dev Deploys or upgrades a proxy for a given contract.
     * @param forContract The name of the contract for which the proxy is being deployed.
     * @param implementation The address of the implementation to set or upgrade to.
     * @param data The data to be used in the upgradeToAndCall or in the initialization.
     * @return proxyAddress The address of the deployed or upgraded proxy.
     */
    function _deployProxy(string memory forContract, address implementation, bytes memory data)
        public
        returns (address proxyAddress)
    {
        bytes32 salt;
        (proxyAddress, salt) = _computeProxyAddress(forContract);

        if (_isDeployed(proxyAddress)) {
            ERC1967Proxy proxy = ERC1967Proxy(payable(proxyAddress));
            address _implementation = address(uint160(uint256(vm.load(address(proxy), PROXY_IMPLEMENTATION_SLOT))));
            if (_implementation != implementation) {
                UUPSUpgradeable(address(proxy)).upgradeToAndCall(implementation, data);
                console.log("%s proxy at %s has been upgraded", forContract, proxyAddress);
            }
        } else {
            ERC1967Proxy proxy = new ERC1967Proxy{
                salt: salt
            }(_emptyUUPS, "");
            assert(proxyAddress == address(proxy));
            UUPSUpgradeable(address(proxy)).upgradeToAndCall(implementation, data);
            console.log("%s proxy deployed to %s", forContract, proxyAddress);
        }
    }

    /// @dev Checks if a contract is deployed at a given address.
    function _isDeployed(address contractAddress) internal view returns (bool isDeployed) {
        assembly {
            let cs := extcodesize(contractAddress)
            if iszero(iszero(cs)) { isDeployed := true }
        }
    }
}
