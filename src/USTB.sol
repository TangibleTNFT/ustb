// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IUSDM} from "./interfaces/IUSDM.sol";
import {IUSTB} from "./interfaces/IUSTB.sol";
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
contract USTB is IUSTB, LayerZeroRebaseTokenUpgradeable {
    using SafeERC20 for IERC20;

    address public constant UNDERLYING = 0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C;

    address public rebaseIndexManager;

    bool private _isMainChain;

    event RebaseIndexManagerUpdated(address manager);

    error InvalidZeroAddress();
    error NotAuthorized(address caller);
    error UnsupportedChain(uint256 chainId);
    error ValueUnchanged();

    modifier onlyIndexManager() {
        if (msg.sender != rebaseIndexManager && !_isInitializing()) {
            revert NotAuthorized(msg.sender);
        }
        _;
    }

    modifier mainChain(bool isMainChain_) {
        if (_isMainChain != isMainChain_) {
            revert UnsupportedChain(block.chainid);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the USTB contract with essential parameters.
     * @dev This function sets the initial LayerZero endpoint, the rebase index manager, and whether the contract is on
     * the main chain. It also calls `__LayerZeroRebaseToken_init` for further initialization.
     *
     * @param mainChainId The chain ID that represents the main chain.
     * @param endpoint The Layer Zero endpoint for cross-chain operations.
     * @param indexManager The address that will manage the rebase index.
     */
    function initialize(uint256 mainChainId, address endpoint, address indexManager) external initializer {
        __LayerZeroRebaseToken_init(msg.sender, endpoint, "US T-Bill", "USTB");
        _isMainChain = block.chainid == mainChainId;
        setRebaseIndex(1 ether, 1);
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
        if (msg.sender != account && msg.sender != rebaseIndexManager) {
            revert NotAuthorized(msg.sender);
        }
        if (_isRebaseDisabled(account) == disable) {
            revert ValueUnchanged();
        }
        _disableRebase(account, disable);
    }

    function isMainChain() public view override returns (bool isMainChain_) {
        isMainChain_ = _isMainChain;
    }

    /**
     * @notice Sets the rebase index and its corresponding nonce.
     * @dev This function allows the rebase index manager to update the rebase index. On the main chain, the index and
     * nonce are automatically set based on the underlying asset and the current block number. On other chains, the
     * index and nonce are explicitly set.
     *
     * @param index The new rebase index.
     * @param nonce The new nonce corresponding to the rebase index.
     * @return rebaseIndex The new rebase index.
     */
    function setRebaseIndex(uint256 index, uint256 nonce) public onlyIndexManager returns (uint256 rebaseIndex) {
        if (_isMainChain) {
            rebaseIndex = IUSDM(UNDERLYING).rewardMultiplier();
            nonce = block.number;
        } else {
            rebaseIndex = index;
        }
        _setRebaseIndex(rebaseIndex, nonce);
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
        rebaseIndexManager = manager;
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
        if (_isMainChain) {
            uint256 currentIndex = IUSDM(UNDERLYING).rewardMultiplier();
            if (currentIndex != rebaseIndex()) {
                _setRebaseIndex(currentIndex, block.number);
            }
        }
        super._update(from, to, amount);
    }
}
