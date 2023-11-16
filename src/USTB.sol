// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IUSDM} from "./interfaces/IUSDM.sol";
import {IUSTB} from "./interfaces/IUSTB.sol";
import {CrossChainToken} from "./CrossChainToken.sol";
import {LayerZeroRebaseTokenUpgradeable} from "./LayerZeroRebaseTokenUpgradeable.sol";
import {RebaseTokenUpgradeable} from "./RebaseTokenUpgradeable.sol";

/**
 * @title USTB (US T-Bill)
 * @author Caesar LaVey
 * @notice This contract extends the functionality of `LayerZeroRebaseTokenUpgradeable` to provide additional features
 * specific to USTB. It adds capabilities for minting and burning tokens backed by an underlying asset, and dynamically
 * updates the rebase index.
 *
 * @dev The contract uses SafeERC20 for secure ERC20 operations and introduces modifiers like `onlyIndexManager`,
 * `mainChain`, and `updateRebaseIndex` to conditionally execute functions. It also allows setting a rebase index
 * manager who has the permission to update the rebase index.
 */
contract USTB is IUSTB, LayerZeroRebaseTokenUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    address public constant UNDERLYING = 0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C;

    /// @custom:storage-location erc7201:tangible.storage.USTB
    struct USTBStorage {
        address rebaseIndexManager;
    }

    // keccak256(abi.encode(uint256(keccak256("tangible.storage.USTB")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant USTBStorageLocation = 0x56cb630b12f1f031f72de1d734e98085323517cc6515c1c85452dc02f218dd00;

    function _getUSTBStorage() private pure returns (USTBStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := USTBStorageLocation
        }
    }

    event RebaseIndexManagerUpdated(address manager);

    error InvalidZeroAddress();
    error NotAuthorized(address caller);
    error UnsupportedChain(uint256 chainId);
    error ValueUnchanged();

    modifier onlyIndexManager() {
        USTBStorage storage $ = _getUSTBStorage();
        if (msg.sender != $.rebaseIndexManager && !_isInitializing()) {
            revert NotAuthorized(msg.sender);
        }
        _;
    }

    modifier mainChain(bool _isMainChain) {
        USTBStorage storage $ = _getUSTBStorage();
        if (isMainChain != _isMainChain) {
            revert UnsupportedChain(block.chainid);
        }
        _;
    }

    /**
     * @param mainChainId The chain ID that represents the main chain.
     * @param endpoint The Layer Zero endpoint for cross-chain operations.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(uint256 mainChainId, address endpoint)
        CrossChainToken(mainChainId)
        LayerZeroRebaseTokenUpgradeable(endpoint)
    {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Initializes the USTB contract with essential parameters.
     * @dev This function sets the initial LayerZero endpoint and the rebase index manager. It also calls
     * `__LayerZeroRebaseToken_init` for further initialization.
     *
     * @param indexManager The address that will manage the rebase index.
     */
    function initialize(address indexManager) external initializer {
        __LayerZeroRebaseToken_init(msg.sender, "US T-Bill", "USTB");
        if (isMainChain) {
            refreshRebaseIndex();
        } else {
            setRebaseIndex(1 ether, 1);
        }
        setRebaseIndexManager(indexManager);
    }

    /**
     * @notice Mints a specified amount of USTB tokens to a given address.
     * @dev This function first transfers the underlying asset from the caller to the contract. Then, it mints the
     * equivalent amount of USTB tokens to the target address. The function can only be called if the contract is on the
     * main chain. It also updates the rebase index before minting.
     *
     * @param to The address to which the tokens will be minted.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external mainChain(true) {
        _mint(to, amount);
        IERC20(UNDERLYING).safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Burns a specified amount of USTB tokens from a given address.
     * @dev This function first burns the specified amount of USTB tokens from the target address. Then, it transfers
     * the equivalent amount of the underlying asset back to the caller. The function can only be called if the contract
     * is on the main chain. It also updates the rebase index before burning.
     *
     * @param from The address from which the tokens will be burned.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) external mainChain(true) {
        if (from != msg.sender) {
            _spendAllowance(from, msg.sender, amount);
        }
        _burn(from, amount);
        IERC20(UNDERLYING).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Enables or disables rebasing for a specific account.
     * @dev This function can be called by either the account itself or the rebase index manager.
     *
     * @param account The address of the account for which rebasing is to be enabled or disabled.
     * @param disable A boolean flag indicating whether to disable (true) or enable (false) rebasing for the account.
     */
    function disableRebase(address account, bool disable) external {
        USTBStorage storage $ = _getUSTBStorage();
        if (msg.sender != account && msg.sender != $.rebaseIndexManager) {
            revert NotAuthorized(msg.sender);
        }
        if (_isRebaseDisabled(account) == disable) {
            revert ValueUnchanged();
        }
        _disableRebase(account, disable);
    }

    function rebaseIndexManager() external view override returns (address _rebaseIndexManager) {
        USTBStorage storage $ = _getUSTBStorage();
        _rebaseIndexManager = $.rebaseIndexManager;
    }

    /**
     * @notice Sets the rebase index and its corresponding nonce on non-main chains.
     * @dev This function allows the rebase index manager to manually update the rebase index and nonce when not on the
     * main chain. The main chain manages the rebase index automatically within `refreshRebaseIndex`. It should only be
     * used on non-main chains to align them with the main chain's state.
     *
     * Reverts if called on the main chain due to the `mainChain(false)` modifier.
     *
     * @param index The new rebase index to set.
     * @param nonce The new nonce corresponding to the rebase index.
     */
    function setRebaseIndex(uint256 index, uint256 nonce) public onlyIndexManager mainChain(false) {
        _setRebaseIndex(index, nonce);
    }

    /**
     * @notice Updates the rebase index to the current index from the underlying asset on the main chain.
     * @dev Automatically refreshes the rebase index by querying the current reward multiplier from the underlying asset
     * contract. This can only affect the rebase index on the main chain. If the current index from the underlying
     * differs from the stored rebase index, it updates the rebase index and sets the current block number as the nonce.
     *
     * This function does not have effect on non-main chains as their rebase index and nonce are managed through
     * `setRebaseIndex`.
     */
    function refreshRebaseIndex() public {
        if (isMainChain) {
            uint256 currentIndex = IUSDM(UNDERLYING).rewardMultiplier();
            if (currentIndex != rebaseIndex()) {
                _setRebaseIndex(currentIndex, block.number);
            }
        }
    }

    /**
     * @notice Sets the address of the rebase index manager.
     * @dev This function allows the contract owner to change the rebase index manager, who has the permission to update
     * the rebase index.
     *
     * @param manager The new rebase index manager address.
     */
    function setRebaseIndexManager(address manager) public onlyOwner {
        if (manager == address(0)) {
            revert InvalidZeroAddress();
        }
        USTBStorage storage $ = _getUSTBStorage();
        $.rebaseIndexManager = manager;
        emit RebaseIndexManagerUpdated(manager);
    }

    /**
     * @notice Updates the state of the contract during token transfers, mints, or burns.
     * @dev This override function performs an additional check to update the rebase index if the contract is on the
     * main chain. It fetches the current rebase index from the underlying asset and updates it if necessary. The
     * function then calls the original `_update` method to proceed with the state update.
     *
     * @param from The address from which tokens are being transferred or burned.
     * @param to The address to which tokens are being transferred or minted.
     * @param amount The amount of tokens being transferred, minted, or burned.
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        refreshRebaseIndex();
        super._update(from, to, amount);
    }
}
