// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IStakingManager {
    event AltWithdraw(address indexed _caller, address indexed _receiver, address indexed _owner, uint256 _assets);
    event CleanOrdersQueue(uint256 _nextCleanTimestamp);
    event MaxDepositorsUpdate(uint256 _maxDepositors, address _sender);
    event MaxWithdrawOrdersUpdate(uint256 _maxWithdrawOrders, address _sender);
    event NewDepositorAdded(address _depositor, address _sender);
    event UpdateProcessWithdrawOrders(bool _isProcessStopped, address _sender);

    function alternativeWithdraw(uint256 _assets, address _receiver) external;
    function auroraStaking() external view returns (address);
    function auroraToken() external view returns (address);
    function changeMaxDepositors(uint256 _maxDepositors) external;
    function changeMaxWithdrawOrders(uint256 _maxWithdrawOrders) external;
    function cleanOrdersQueue() external;
    function createWithdrawOrder(uint256 _assets, address _receiver) external;
    function depositorExists(address _depositor) external view returns (bool);
    function depositorsLength() external view returns (uint256);
    function getAvailableAssets(address _account) external view returns (uint256);
    function getDepositorShares(address _depositor) external view returns (uint256);
    function getPendingOrderAssets(address _account) external view returns (uint256);
    function getTotalAssetsFromDepositor(address _depositor) external view returns (uint256);
    function getTotalAssetsFromDepositors() external view returns (uint256);
    function getTotalPendingOrders() external view returns (uint256);
    function getTotalWithdrawOrders() external view returns (uint256);
    function getWithdrawOrderAssets(address _account) external view returns (uint256);
    function insertDepositor(address _depositor) external;
    function nextDepositor() external view returns (address);
    function setNextDepositor() external;
    function stAurVault() external view returns (address);
    function totalAssets() external view returns (uint256);
    function transferAurora(address _receiver, address _owner, uint256 _assets) external;
}