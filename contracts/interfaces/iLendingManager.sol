// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;

interface iLendingManager{

    function getCoinValues(address token) external view returns (uint[2] memory price);
    function viewUsersHealthFactor(address user) external view returns(uint userHealthFactor);
    function viewUserLendableLimit(address user) external view returns(uint userLendableLimit);
    function assetsLiqPenaltyInfo(address token) external view returns(uint liqPenalty);
    function assetsSerialNumber(uint) external view returns(address);

    function assetsDepositAndLendAddrs(address token) external view returns (address[2] memory depositAndLend);

    // function assetsBaseInfo(address token) external view returns(uint maximumLTV,uint bestLendingRatio,uint lendingModeNum,uint bestDepositInterestRate);
    function assetsBaseInfo(address token) external view returns(uint maximumLTV,
                                                               uint liquidationPenalty,
                                                               uint maxLendingAmountInRIM,
                                                               uint bestLendingRatio,
                                                               uint lendingModeNum,
                                                               uint homogeneousModeLTV,
                                                               uint bestDepositInterestRate);
    function assetsTimeDependentParameter(address token) external view returns(uint latestDepositCoinValue,
                                                                   uint latestLendingCoinValue,
                                                                   uint latestDepositInterest,
                                                                   uint latestLendingInterest);
    
    function licensedAssetPrice() external view returns(uint[] memory assetPrice);
    function licensedAssetOverview() external view returns(uint totalValueOfMortgagedAssets, uint totalValueOfLendedAssets);
    function userDepositAndLendingValue(address user) external view returns(uint _amountDeposit,uint _amountLending);
    function userAssetOverview(address user) external view returns(address[] memory tokens,uint[] memory _amountDeposit, uint[] memory _amountLending);
    // function userAssetOverview(address user) external view returns(address[] memory tokens, uint[] memory amounts, uint SLCborrowed);
    function usersHealthFactorEstimate(address user,address token,uint amount,uint operator) external view returns(uint userHealthFactor);


    //Operation
    function userModeSetting(uint8 _mode,address _userRIMAssetsAddress, address user) external;
    //  Assets Deposit
    function assetsDeposit(address tokenAddr, uint amount, address user) external;
    // Withdrawal of deposits
    function withdrawDeposit(address tokenAddr, uint amount, address user) external ;
    // lend Asset
    function lendAsset(address tokenAddr, uint amount, address user) external;
    // repay Loan
    function repayLoan(address tokenAddr,uint amount, address user) external ;

    // token Liquidate
    function tokenLiquidate(address user,
                            address liquidateToken,
                            uint    liquidateAmount, 
                            address depositToken) external returns(uint usedAmount) ;
    function tokenLiquidateEstimate(address user,
                            address liquidateToken,
                            address depositToken) external view returns(uint[2] memory maxAmounts);



}