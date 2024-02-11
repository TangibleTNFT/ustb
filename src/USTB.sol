// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {CrossChainToken} from "@tangible/tokens/CrossChainToken.sol";
import {LayerZeroRebaseTokenUpgradeable} from "@tangible/tokens/LayerZeroRebaseTokenUpgradeable.sol";
import {RebaseTokenUpgradeable} from "@tangible/tokens/RebaseTokenUpgradeable.sol";

import {IUSDM} from "./interfaces/IUSDM.sol";
import {IUSTB} from "./interfaces/IUSTB.sol";

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

    address public immutable UNDERLYING;

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

    modifier onlyIndexManager() {
        USTBStorage storage $ = _getUSTBStorage();
        if (msg.sender != $.rebaseIndexManager && !_isInitializing()) {
            revert NotAuthorized(msg.sender);
        }
        _;
    }

    modifier mainChain(bool _isMainChain) {
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
    constructor(address underlying, uint256 mainChainId, address endpoint)
        CrossChainToken(mainChainId)
        LayerZeroRebaseTokenUpgradeable(endpoint)
    {
        UNDERLYING = underlying;
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @inheritdoc IUSTB
    function initialize(address indexManager) external initializer {
        __LayerZeroRebaseToken_init(msg.sender, "US T-Bill", "USTB");
        if (isMainChain) {
            refreshRebaseIndex();
        } else {
            setRebaseIndex(1 ether, 1);
        }
        setRebaseIndexManager(indexManager);
    }

    /// @inheritdoc IUSTB
    function mint(address to, uint256 amount) external mainChain(true) {
        _mint(to, amount);
        IERC20(UNDERLYING).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IUSTB
    function burn(address from, uint256 amount) external mainChain(true) {
        if (from != msg.sender) {
            _spendAllowance(from, msg.sender, amount);
        }
        _burn(from, amount);
        IERC20(UNDERLYING).safeTransfer(msg.sender, amount);
    }

    /// @inheritdoc IUSTB
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

    /// @inheritdoc IUSTB
    function rebaseIndexManager() external view override returns (address _rebaseIndexManager) {
        USTBStorage storage $ = _getUSTBStorage();
        _rebaseIndexManager = $.rebaseIndexManager;
    }

    /// @inheritdoc IUSTB
    function setRebaseIndex(uint256 index, uint256 nonce) public onlyIndexManager mainChain(false) {
        _setRebaseIndex(index, nonce);
    }

    /// @inheritdoc IUSTB
    function refreshRebaseIndex() public {
        if (isMainChain) {
            uint256 currentIndex = IUSDM(UNDERLYING).rewardMultiplier();
            if (currentIndex != rebaseIndex()) {
                _setRebaseIndex(currentIndex, block.number);
            }
        }
    }

    /// @inheritdoc IUSTB
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
