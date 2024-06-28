// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;

interface iLendingManager{

    function getCoinValues(address token) external view returns (uint[2] memory price);
    function viewUsersHealthFactor(address user) external view returns(uint userHealthFactor);
    function assetsLiqPenaltyInfo(address token) external view returns(uint liqPenalty);

    function assetsDepositAndLendAddrs(address token) external view returns (address[2] memory depositAndLend);

    function assetsBaseInfo(address token) external view returns(uint maximumLTV,uint bestLendingRatio,uint lendingModeNum,uint bestDepositInterestRate);
    function assetsTimeDependentParameter(address token) external view returns(uint latestDepositCoinValue,
                                                                   uint latestLendingCoinValue,
                                                                   uint latestDepositInterest,
                                                                   uint latestLendingInterest);
}