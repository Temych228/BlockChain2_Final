// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SimpleERC20.sol";

/**
 * @title LendingPool
 * @notice A simplified lending/borrowing protocol
 * @dev Supports deposit, borrow, repay, withdraw, and liquidate
 */
contract LendingPool {
    address public immutable collateralToken;
    address public immutable borrowToken;

    uint256 public constant MAX_LTV_BPS = 7500; // 75%
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant LIQUIDATION_THRESHOLD_BPS = 8000; // 80% of max LTV
    uint256 public constant LIQUIDATION_BONUS_BPS = 500; // 5% bonus for liquidator
    uint256 public constant ANNUAL_INTEREST_RATE_BPS = 500; // 5% annual interest
    uint256 public constant SECONDS_PER_YEAR = 31536000;

    struct UserPosition {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastInterestUpdate;
    }

    mapping(address => UserPosition) public positions;

    uint256 public totalDeposited;
    uint256 public totalBorrowed;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(
        address indexed liquidator, address indexed borrower, uint256 repayAmount, uint256 collateralSeized
    );

    error ZeroAmount();
    error InsufficientCollateral();
    error ExceedsLTV();
    error InsufficientDeposited();
    error HealthFactorBelowOne();
    error HealthFactorAboveOne();
    error TransferFailed();

    constructor(address _collateralToken, address _borrowToken) {
        require(_collateralToken != address(0) && _borrowToken != address(0), "Invalid addresses");
        collateralToken = SimpleERC20(_collateralToken);
        borrowToken = SimpleERC20(_borrowToken);
    }

    /**
     * @notice Deposit collateral tokens
     */
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        collateralToken.transferFrom(msg.sender, address(this), amount);

        UserPosition storage pos = positions[msg.sender];
        pos.deposited += amount;
        totalDeposited += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw collateral (only if health factor > 1)
     */
    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        if (pos.deposited < amount) revert InsufficientDeposited();

        // Check health factor after withdrawal
        uint256 newDeposited = pos.deposited - amount;
        if (pos.borrowed > 0) {
            uint256 accruedDebt = _calculateAccruedDebt(pos);
            uint256 healthFactor = _calculateHealthFactor(newDeposited, accruedDebt);
            if (healthFactor <= 1e18) revert HealthFactorBelowOne();
        }

        pos.deposited = newDeposited;
        totalDeposited -= amount;

        require(collateralToken.transfer(msg.sender, amount), "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice Borrow tokens against collateral
     */
    function borrow(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        if (pos.deposited == 0) revert InsufficientCollateral();

        uint256 accruedDebt = _calculateAccruedDebt(pos);
        uint256 newBorrowed = accruedDebt + amount;

        // Check LTV: borrowed value must be <= deposited * maxLTV
        uint256 maxBorrow = (pos.deposited * MAX_LTV_BPS) / BASIS_POINTS;
        if (newBorrowed > maxBorrow) revert ExceedsLTV();

        pos.borrowed = newBorrowed;
        pos.lastInterestUpdate = block.timestamp;
        totalBorrowed += amount;

        require(borrowToken.transfer(msg.sender, amount), "Transfer failed");

        emit Borrow(msg.sender, amount);
    }

    /**
     * @notice Repay borrowed amount (partial or full)
     */
    function repay(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        uint256 accruedDebt = _calculateAccruedDebt(pos);
        uint256 repayAmount = amount > accruedDebt ? accruedDebt : amount;
        uint256 principalRepaid = repayAmount > pos.borrowed ? pos.borrowed : repayAmount;

        borrowToken.transferFrom(msg.sender, address(this), repayAmount);

        pos.borrowed -= principalRepaid;
        pos.lastInterestUpdate = block.timestamp;
        totalBorrowed -= principalRepaid;

        emit Repay(msg.sender, repayAmount);
    }

    /**
     * @notice Liquidate an undercollateralized position
     */
    function liquidate(address borrower) external {
        UserPosition storage pos = positions[borrower];
        if (pos.borrowed == 0) revert InsufficientCollateral();

        uint256 accruedDebt = _calculateAccruedDebt(pos);
        uint256 healthFactor = _calculateHealthFactor(pos.deposited, accruedDebt);

        if (healthFactor > 1e18) revert HealthFactorAboveOne();

        // Liquidator repays the debt and receives collateral with bonus
        uint256 collateralSeized = (accruedDebt * (BASIS_POINTS + LIQUIDATION_BONUS_BPS)) / BASIS_POINTS;
        if (collateralSeized > pos.deposited) {
            collateralSeized = pos.deposited;
        }

        // Transfer borrowed tokens from liquidator to pool
        borrowToken.transferFrom(msg.sender, address(this), accruedDebt);

        // Update position
        pos.borrowed = 0;
        pos.deposited -= collateralSeized;
        pos.lastInterestUpdate = block.timestamp;
        totalBorrowed -= pos.borrowed;
        totalDeposited -= collateralSeized;

        // Send collateral to liquidator
        require(collateralToken.transfer(msg.sender, collateralSeized), "Transfer failed");

        emit Liquidate(msg.sender, borrower, accruedDebt, collateralSeized);
    }

    /**
     * @notice Get user position details
     */
    function getPosition(address user)
        external
        view
        returns (uint256 deposited, uint256 borrowed, uint256 healthFactor)
    {
        UserPosition storage pos = positions[user];
        uint256 accruedDebt = _calculateAccruedDebt(pos);

        deposited = pos.deposited;
        borrowed = accruedDebt;
        healthFactor = _calculateHealthFactor(deposited, accruedDebt);
    }

    /**
     * @notice Calculate health factor: (deposited * LTV_threshold) / borrowed
     */
    function _calculateHealthFactor(uint256 deposited, uint256 borrowed) internal pure returns (uint256) {
        if (borrowed == 0) return type(uint256).max; // No debt = infinite health
        return (deposited * LIQUIDATION_THRESHOLD_BPS * 1e18) / (borrowed * BASIS_POINTS);
    }

    /**
     * @notice Calculate accrued debt with interest
     */
    function _calculateAccruedDebt(UserPosition storage pos) internal view returns (uint256) {
        if (pos.borrowed == 0) return 0;

        uint256 timeElapsed = block.timestamp - pos.lastInterestUpdate;
        if (timeElapsed == 0) return pos.borrowed;

        uint256 interest = (pos.borrowed * ANNUAL_INTEREST_RATE_BPS * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
        return pos.borrowed + interest;
    }
}
