// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

contract USDM {
    // Token name
    string private _name;
    // Token Symbol
    string private _symbol;
    // Total token shares
    uint256 private _totalShares;
    // Base value for rewardMultiplier
    uint256 private constant _BASE = 1e18;
    /**
     * @dev rewardMultiplier represents a coefficient used in reward calculation logic.
     * The value is represented with 18 decimal places for precision.
     */
    uint256 public rewardMultiplier;

    // Mapping of shares per address
    mapping(address => uint256) private _shares;
    // Mapping of block status per address
    mapping(address => bool) private _blocklist;
    // Mapping of allowances per owner and spender
    mapping(address => mapping(address => uint256)) private _allowances;

    // Events
    event AccountBlocked(address indexed addr);
    event AccountUnblocked(address indexed addr);
    event RewardMultiplier(uint256 indexed value);

    /**
     * Standard ERC20 Errors
     * @dev See https://eips.ethereum.org/EIPS/eip-6093
     */
    error ERC20InsufficientBalance(
        address sender,
        uint256 shares,
        uint256 sharesNeeded
    );
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
    // ERC2612 Errors
    error ERC2612ExpiredDeadline(uint256 deadline, uint256 blockTimestamp);
    error ERC2612InvalidSignature(address owner, address spender);
    // USDM Errors
    error USDMInvalidMintReceiver(address receiver);
    error USDMInvalidBurnSender(address sender);
    error USDMInsufficientBurnBalance(
        address sender,
        uint256 shares,
        uint256 sharesNeeded
    );
    error USDMInvalidRewardMultiplier(uint256 rewardMultiplier);
    error USDMBlockedSender(address sender);
    error USDMInvalidBlockedAccount(address account);

    constructor() {
        _name = "USBM";
        _symbol = "US";
        _setRewardMultiplier(_BASE);
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function convertToShares(uint256 amount) public view returns (uint256) {
        return (amount * _BASE) / rewardMultiplier;
    }

    function convertToTokens(uint256 shares) public view returns (uint256) {
        return (shares * rewardMultiplier) / _BASE;
    }

    function totalShares() external view returns (uint256) {
        return _totalShares;
    }

    function totalSupply() external view returns (uint256) {
        return convertToTokens(_totalShares);
    }

    function sharesOf(address account) public view returns (uint256) {
        return _shares[account];
    }

    function balanceOf(address account) external view returns (uint256) {
        return convertToTokens(sharesOf(account));
    }

    function _mint(address to, uint256 amount) private {
        if (to == address(0)) {
            revert USDMInvalidMintReceiver(to);
        }

        _beforeTokenTransfer(address(0), to, amount);

        uint256 shares = convertToShares(amount);
        _totalShares += shares;

        unchecked {
            // Overflow not possible: shares + shares amount is at most totalShares + shares amount
            // which is checked above.
            _shares[to] += shares;
        }

        _afterTokenTransfer(address(0), to, amount);
    }

    function mintTokens(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _burn(address account, uint256 amount) private {
        if (account == address(0)) {
            revert USDMInvalidBurnSender(account);
        }

        _beforeTokenTransfer(account, address(0), amount);

        uint256 shares = convertToShares(amount);
        uint256 accountShares = sharesOf(account);

        if (accountShares < shares) {
            revert USDMInsufficientBurnBalance(account, accountShares, shares);
        }

        unchecked {
            _shares[account] = accountShares - shares;
            // Overflow not possible: amount <= accountShares <= totalShares.
            _totalShares -= shares;
        }

        _afterTokenTransfer(account, address(0), amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address /* to */,
        uint256 /* amount */
    ) private view {
        // Each blocklist check is an SLOAD, which is gas intensive.
        // We only block sender not receiver, so we don't tax every user
        if (isBlocked(from)) {
            revert USDMBlockedSender(from);
        }
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) private {}

    function _transfer(address from, address to, uint256 amount) private {
        if (from == address(0)) {
            revert ERC20InvalidSender(from);
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(to);
        }

        _beforeTokenTransfer(from, to, amount);

        uint256 shares = convertToShares(amount);
        uint256 fromShares = _shares[from];

        if (fromShares < shares) {
            revert ERC20InsufficientBalance(from, fromShares, shares);
        }

        unchecked {
            _shares[from] = fromShares - shares;
            // Overflow not possible: the sum of all shares is capped by totalShares, and the sum is preserved by
            // decrementing then incrementing.
            _shares[to] += shares;
        }

        _afterTokenTransfer(from, to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        address owner = msg.sender;

        _transfer(owner, to, amount);

        return true;
    }

    function _blockAccount(address account) private {
        if (isBlocked(account)) {
            revert USDMInvalidBlockedAccount(account);
        }

        _blocklist[account] = true;
        emit AccountBlocked(account);
    }

    function _unblockAccount(address account) private {
        if (!isBlocked(account)) {
            revert USDMInvalidBlockedAccount(account);
        }

        _blocklist[account] = false;
        emit AccountUnblocked(account);
    }

    function blockAccounts(address[] calldata addresses) external {
        for (uint256 i = 0; i < addresses.length; i++) {
            _blockAccount(addresses[i]);
        }
    }

    function unblockAccounts(address[] calldata addresses) external {
        for (uint256 i = 0; i < addresses.length; i++) {
            _unblockAccount(addresses[i]);
        }
    }

    function isBlocked(address account) public view returns (bool) {
        return _blocklist[account];
    }

    function _setRewardMultiplier(uint256 _rewardMultiplier) private {
        if (_rewardMultiplier < _BASE) {
            revert USDMInvalidRewardMultiplier(_rewardMultiplier);
        }

        rewardMultiplier = _rewardMultiplier;

        emit RewardMultiplier(rewardMultiplier);
    }

    function setRewardMultiplier(uint256 _rewardMultiplier) external {
        _setRewardMultiplier(_rewardMultiplier);
    }

    function addRewardMultiplier(uint256 _rewardMultiplierIncrement) external {
        if (_rewardMultiplierIncrement == 0) {
            revert USDMInvalidRewardMultiplier(_rewardMultiplierIncrement);
        }

        _setRewardMultiplier(rewardMultiplier + _rewardMultiplierIncrement);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(owner);
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(spender);
        }

        _allowances[owner][spender] = amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        address owner = msg.sender;

        _approve(owner, spender, amount);

        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) private {
        uint256 currentAllowance = allowance(owner, spender);

        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    amount
                );
            }

            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        address spender = msg.sender;

        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);

        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool) {
        address owner = msg.sender;

        _approve(owner, spender, allowance(owner, spender) + addedValue);

        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);

        if (currentAllowance < subtractedValue) {
            revert ERC20InsufficientAllowance(
                spender,
                currentAllowance,
                subtractedValue
            );
        }

        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }
}
