// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./interfaces/IDepositor.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IStakedAuroraVaultEvents.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

// NOTE: SafeMath is no longer needed starting with Solidity 0.8. The compiler now has built in overflow checking.

contract StakedAuroraVault is ERC4626, AccessControl, IStakedAuroraVaultEvents {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address public stakingManager;
    address public liquidityPool;
    uint256 public minDepositAmount;

    /// @notice When is NOT fully operational, users cannot:
    /// 1) mint, 2) deposit nor 3) create withdraw orders.
    bool public fullyOperational;
    bool public enforceWhitelist;

    mapping(address => bool) public accountWhitelist;

    modifier onlyManager() {
        require(msg.sender == stakingManager, "ONLY_STAKING_MANAGER");
        _;
    }

    modifier onlyFullyOperational() {
        require(fullyOperational, "CONTRACT_IS_NOT_FULLY_OPERATIONAL");
        _;
    }

    modifier checkWhitelist() {
        if (enforceWhitelist) {
            require(isWhitelisted(msg.sender), "ACCOUNT_IS_NOT_WHITELISTED");
        }
        _;
    }

    constructor(
        address _asset,
        address _contractOperatorRole,
        string memory _stAurName,
        string memory _stAurSymbol,
        uint256 _minDepositAmount
    )
        ERC4626(IERC20(_asset))
        ERC20(_stAurName, _stAurSymbol)
    {
        require(
            _asset != address(0)
                && _contractOperatorRole != address(0),
            "INVALID_ZERO_ADDRESS"
        );
        minDepositAmount = _minDepositAmount;
        enforceWhitelist = true;

        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, _contractOperatorRole);
    }

    receive() external payable {}

    function initializeLiquidStaking(
        address _stakingManager,
        address _liquidityPool
    ) external onlyRole(ADMIN_ROLE) {
        require(liquidityPool == address(0) || stakingManager == address(0), "ALREADY_INITIALIZED");
        require(_liquidityPool != address(0) || _stakingManager != address(0), "INVALID_ZERO_ADDRESS");
        stakingManager = _stakingManager;
        liquidityPool = _liquidityPool;

        // Get fully operational for the first time.
        updateContractOperation(true);

        emit ContractInitialized(_stakingManager, _liquidityPool, msg.sender);
    }

    function updateStakingManager(address _stakingManager) external onlyRole(ADMIN_ROLE) {
        require(_stakingManager != address(0), "INVALID_ZERO_ADDRESS");
        require(stakingManager != address(0), "NOT_INITIALIZED");
        stakingManager = _stakingManager;

        emit NewManagerUpdate(_stakingManager, msg.sender);
    }

    function updateLiquidityPool(address _liquidityPool) external onlyRole(ADMIN_ROLE) {
        require(_liquidityPool != address(0), "INVALID_ZERO_ADDRESS");
        require(liquidityPool != address(0), "NOT_INITIALIZED");
        liquidityPool = _liquidityPool;

        emit NewLiquidityPoolUpdate(_liquidityPool, msg.sender);
    }

    function updateMinDepositAmount(uint256 _amount) external onlyRole(OPERATOR_ROLE) {
        minDepositAmount = _amount;

        emit UpdateMinDepositAmount(_amount, msg.sender);
    }

    /// @notice Use in case of emergency 🦺.
    /// @dev Check if the contract is initialized when the change is to true.
    function updateContractOperation(bool _isFullyOperational) public onlyRole(ADMIN_ROLE) {
        if (_isFullyOperational) {
            require(
                liquidityPool != address(0) && stakingManager != address(0),
                "CONTRACT_NOT_INITIALIZED"
            );
        }
        fullyOperational = _isFullyOperational;

        emit ContractUpdateOperation(_isFullyOperational, msg.sender);
    }

    function updateEnforceWhitelist(
        bool _isWhitelistRequired
    ) external onlyRole(OPERATOR_ROLE) {
        enforceWhitelist = _isWhitelistRequired;

        emit ContractUpdateWhitelist(_isWhitelistRequired, msg.sender);
    }

    function whitelistAccount(address _account) external onlyRole(OPERATOR_ROLE) {
        accountWhitelist[_account] = true;

        emit AccountWhitelisted(_account, msg.sender);
    }

    function blacklistAccount(address _account) external onlyRole(OPERATOR_ROLE) {
        accountWhitelist[_account] = false;

        emit AccountBlacklisted(_account, msg.sender);
    }

    function isWhitelisted(address _account) public view returns (bool) {
        return accountWhitelist[_account];
    }

    function getStAurPrice() public view returns (uint256) {
        uint256 ONE_AURORA = 1 ether;
        return convertToAssets(ONE_AURORA);
    }

    function totalAssets() public view override returns (uint256) {
        return IStakingManager(stakingManager).totalAssets();
    }

    /// @dev Same as ERC-4626, but adding evaluation of min deposit amount.
    function deposit(
        uint256 _assets,
        address _receiver
    ) public override onlyFullyOperational checkWhitelist returns (uint256) {
        require(_assets <= maxDeposit(_receiver), "ERC4626: deposit more than max");
        require(_assets >= minDepositAmount, "LESS_THAN_MIN_DEPOSIT_AMOUNT");

        uint256 shares = previewDeposit(_assets);
        _deposit(msg.sender, _receiver, _assets, shares);

        return shares;
    }

    function mint(
        uint256 _shares,
        address _receiver
    ) public override onlyFullyOperational checkWhitelist returns (uint256) {
        require(_shares <= maxMint(_receiver), "ERC4626: mint more than max");

        uint256 assets = previewMint(_shares);
        require(assets >= minDepositAmount, "LESS_THAN_MIN_DEPOSIT_AMOUNT");
        _deposit(msg.sender, _receiver, assets, _shares);

        return assets;
    }

    /// @notice It can only be called after the redeem of the stAUR and the waiting period.
    /// @dev The withdraw can only be run by the owner, that's why the 3rd param is not required.
    /// @return Zero shares were burned during the withdraw.
    function withdraw(
        uint256 _assets,
        address _receiver,
        address
    ) public override returns (uint256) {
        IStakingManager(stakingManager).transferAurora(_receiver, msg.sender, _assets);

        emit Withdraw(msg.sender, _receiver, msg.sender, _assets, 0);

        return 0;
    }

    /// @notice The redeem fn starts the release of tokens from the Aurora staking contract.
    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    ) public override onlyFullyOperational returns (uint256) {
        require(_shares > 0, "CANNOT_REDEEM_ZERO_SHARES");
        if (msg.sender != _owner) {
            _spendAllowance(_owner, msg.sender, _shares);
        }

        // IMPORTANT NOTE: run the burn 🔥 AFTER the calculations.
        uint256 assets = previewRedeem(_shares);
        _burn(_owner, _shares);

        IStakingManager(stakingManager).createWithdrawOrder(assets, _receiver);

        emit WithdrawOrderCreated(msg.sender, _receiver, _owner, _shares, assets);

        return assets;
    }

    function _deposit(
        address _caller,
        address _receiver,
        uint256 _assets,
        uint256 _shares
    ) internal override {
        IERC20 auroraToken = IERC20(asset());
        IStakingManager manager = IStakingManager(stakingManager);
        auroraToken.safeTransferFrom(_caller, address(this), _assets);
        ILiquidityPool pool = ILiquidityPool(liquidityPool);

        // FLOW 1: Use the stAUR in the Liquidity Pool.
        if (pool.isStAurBalanceAvailable(_shares)) {
            auroraToken.safeIncreaseAllowance(liquidityPool, _assets);
            pool.transferStAur(_receiver, _shares, _assets);

        // FLOW 2: Stake with the depositor to mint more stAUR.
        } else {
            address depositor = manager.nextDepositor();
            auroraToken.safeIncreaseAllowance(depositor, _assets);
            IDepositor(depositor).stake(_assets);
            manager.setNextDepositor();
            _mint(_receiver, _shares);
        }

        emit Deposit(_caller, _receiver, _assets, _shares);
    }
}