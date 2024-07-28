// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.07.30

pragma solidity ^0.8.0;

interface iLendingCoreAlgorithm  {
    
    function assetsValueUpdate(address token) external view returns(uint[2] memory latestInterest);

    function depositInterestRate(address token,uint bestLendingRatio,uint lendingRatio) external view returns(uint _rate);
    function lendingInterestRate(address token,uint bestLendingRatio,uint lendingRatio) external view returns(uint _rate);

}