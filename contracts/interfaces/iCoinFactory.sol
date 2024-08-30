// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.07.30
pragma solidity 0.8.6;
interface iCoinFactory{
    function createDeAndLoCoin(address token) external returns (address[2] memory _pAndLCoin) ;
}
