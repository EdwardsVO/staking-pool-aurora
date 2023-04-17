// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IStakedAuroraVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @notice Liquidity Pool that allows the fast convertion of stAUR to AURORA tokens.

contract LiquidityPool is ERC4626, Ownable, ILiquidityPool {
    using SafeERC20 for IERC20;
    using SafeERC20 for IStakedAuroraVault;

    address public stAurVault;
    address public auroraToken;

    /// @dev Internal accounting for the two vault assets.
    uint256 public stAurBalance;
    uint256 public auroraBalance;

    uint256 public minDepositAmount;

    /// @dev Fee is represented as Basis Point (100 points == 0.01%).
    uint256 public swapFeeBasisPoints;
    uint256 public collectedStAurFees;

    bool public fullyOperational;

    modifier onlyStAurVault() {
        require(_msgSender() == stAurVault, "ONLY_FOR_STAUR_VAULT");
        _;
    }

    modifier onlyFullyOperational() {
        require(fullyOperational, "CONTRACT_IS_NOT_FULLY_OPERATIONAL");
        _;
    }

    constructor(
        address _stAurVault,
        address _auroraToken,
        string memory _lpTokenName,
        string memory _lpTokenSymbol,
        uint256 _minDepositAmount,
        uint256 _swapFeeBasisPoints
    )
        ERC4626(IERC20(_auroraToken))
        ERC20(_lpTokenName, _lpTokenSymbol)
    {
        require(_stAurVault != address(0), "INVALID_ZERO_ADDRESS");
        require(_auroraToken != address(0), "INVALID_ZERO_ADDRESS");
        stAurVault = _stAurVault;
        auroraToken = _auroraToken;
        minDepositAmount = _minDepositAmount;
        swapFeeBasisPoints = _swapFeeBasisPoints;
        fullyOperational = true;
    }

    receive() external payable {}

    /// @notice Use in case of emergency 🦺.
    function toggleFullyOperational() external onlyOwner {
        fullyOperational = !fullyOperational;
    }

    function isStAurBalanceAvailable(uint _amount) external view returns(bool) {
        if (stAurBalance >= _amount) return true;
        return false;
    }

    /// @dev This function will ONLY be called by the stAUR vault
    /// to cover Aurora deposits (FLOW 1).
    function transferStAur(
        address _receiver,
        uint256 _amount,
        uint _assets
    ) external onlyStAurVault {
        stAurBalance -= _amount;
        IStakedAuroraVault(stAurVault).safeTransfer(_receiver, _amount);
        auroraBalance += _assets;
        IERC20(auroraToken).safeTransferFrom(stAurVault, address(this), _assets);
    }
    
    /// @notice The returned amount is denominated in Aurora Tokens.
    /// @dev Return the balance of Aurora and the current value in Aurora for the stAUR balance.
    function totalAssets() public view override returns (uint256) {
        return (
            auroraBalance
                + IStakedAuroraVault(stAurVault).convertToAssets(stAurBalance)
        );
    }

    /// @notice The deposit flow is used to **Add** liquidity to the Liquidity Pool.
    function deposit(
        uint256 _assets,
        address _receiver
    ) public override onlyFullyOperational returns (uint256) {
        require(_assets <= maxDeposit(_receiver), "ERC4626: deposit more than max");
        require(_assets >= minDepositAmount, "LESS_THAN_MIN_DEPOSIT_AMOUNT");

        uint256 _shares = previewDeposit(_assets);
        _deposit(_msgSender(), _receiver, _assets, _shares);

        return _shares;
    }

    /// @notice The redeem flow is used to **Remove** liquidity from the Liquidity Pool.
    /// @return The pool percentage of shares that were burned.
    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    ) public override returns (uint256) {
        if (_msgSender() != _owner) {
            _spendAllowance(_owner, _msgSender(), _shares);
        }

        // IMPORTANT NOTE: run the burn 🔥 BEFORE the calculations.
        _burn(_msgSender(), _shares);

        // Core Calculations.
        uint256 ONE_AURORA = 1 ether;
        uint256 poolPercentage = (_shares * ONE_AURORA) / totalSupply();
        uint256 auroraToSend = (poolPercentage * auroraBalance) / ONE_AURORA;
        uint256 stAurToSend = (poolPercentage * stAurBalance) / ONE_AURORA;

        auroraBalance -= auroraToSend;
        stAurBalance -= stAurToSend;

        // Send Aurora tokens.
        IERC20(asset()).safeTransfer(_receiver, auroraToSend);

        // Then, send stAUR tokens.
        IStakedAuroraVault(stAurVault).safeTransfer(_receiver, stAurToSend);

        emit RemoveLiquidity(
            _msgSender(),
            _receiver,
            _owner,
            _shares,
            auroraToSend,
            stAurToSend
        );
        return poolPercentage;
    }

    /// @dev Use deposit fn instead.
    function mint(uint256, address) public override pure returns (uint256) {
        revert("UNAVAILABLE_FUNCTION");
    }

    /// @dev Use redeem fn instead.
    function withdraw(uint256, address, address) public override pure returns (uint256) {
        revert("UNAVAILABLE_FUNCTION");
    }

    function previewSwapStAurForAurora(uint256 _amount) external view returns (uint256) {
        (uint256 discountedAmount,) = _calculatePoolFees(_amount);
        return IStakedAuroraVault(stAurVault).convertToAssets(discountedAmount);
    }

    /// @notice Used for fast swaps to get AURORA tokens back without the unstake delay.
    function swapStAurForAurora(
        uint256 _stAurAmount,
        uint256 _minAuroraToReceive
    ) external {
        IStakedAuroraVault vault = IStakedAuroraVault(stAurVault);
        (uint256 discountedAmount, uint256 fee) = _calculatePoolFees(_stAurAmount);
        uint256 auroraToSend = vault.convertToAssets(discountedAmount);

        require(auroraToSend <= auroraBalance, "NOT_ENOUGH_AURORA");
        require(auroraToSend >= _minAuroraToReceive, "UNREACHED_MIN_SWAP_AMOUNT");

        stAurBalance += discountedAmount;
        collectedStAurFees += fee;
        auroraBalance -= auroraToSend;

        // Step 1. Get the caller stAur tokens.
        vault.safeTransferFrom(_msgSender(), address(this), _stAurAmount);

        // Step 2. Transfer the Aurora tokens to the caller.
        IERC20(auroraToken).safeTransfer(_msgSender(), auroraToSend);

        emit SwapStAur(_msgSender(), auroraToSend, _stAurAmount, fee);
    }

    // TODO: Fees are selfish 🐡
    function withdrawCollectedStAurFees(address _receiver) onlyOwner external {
        require(_receiver != address(0), "INVALID_ZERO_ADDRESS");
        uint256 _toTransfer = collectedStAurFees;
        collectedStAurFees = 0;
        IStakedAuroraVault(stAurVault).safeTransfer(_receiver, _toTransfer);
    }

    function _calculatePoolFees(uint256 _amount)
        private
        view
        returns (uint256 _discountedAmount, uint256 _fee) {
        uint256 fee = (_amount * swapFeeBasisPoints) / 10_000;
        return (_amount - fee, fee);
    }

    /// @dev The Deposit event is used to indicate more liquidity.
    function _deposit(
        address _caller,
        address _receiver,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override {
        auroraBalance += _assets;
        IERC20(asset()).safeTransferFrom(_caller, address(this), _assets);
        _mint(_receiver, _shares);

        emit AddLiquidity(_caller, _receiver, _assets, _shares);
    }
}