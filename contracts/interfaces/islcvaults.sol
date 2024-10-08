// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.09.30

pragma solidity 0.8.6;
interface iSlcVaults{
    struct licensedAsset{
        address  assetAddr;
        // loan-to-value (LTV) ratio is a measurement lenders use to compare your loan amount for a home against the value of that property
        uint     maximumLTV;           // MAX = 10000
        uint     liquidationPenalty;   // MAX = 10000 ,default is 500(5%)
        // default is 0, means no limits; if > 0, have limits : 1 ether = 1 slc
        uint     maxLendingAmountInRIM;
        uint     mortgagedAmountNow;
        uint     mortgagedAmountUsed;
    }

    //----------------------------- View Function------------------------------------
    function viewUsersHealthFactor(address user) external view returns(uint userHealthFactor, uint userAssetsValue, uint userBorrowedSLCAmount, uint userAvailbleBorrowedSLCAmount);
    function licensedAssetOverview() external view returns(uint totalValueOfMortgagedAssets, uint _slcSupply, uint _slcValue);
    function userAssetOverview(address user) external view returns(uint[] memory _amount, uint SLCborrowed);
    
    //---------------------------- User Used Function--------------------------------
    function slcTokenBuyEstimate(address tokenAddr, uint amount) external view returns(uint outputAmount);
    function slcTokenSellEstimate(address tokenAddr, uint amount) external view returns(uint outputAmount);
    function slcTokenBuy(address tokenAddr, uint amount) external  returns(uint outputAmount);
    function slcTokenSell(address tokenAddr, uint amount) external  returns(uint outputAmount);
    //---------------------------- borrow & lend  Function----------------------------
    // licensed Assets Pledge
    function licensedAssetsPledge(address tokenAddr, uint amount, address user) external ;
    // redeem Pledged Assets
    function redeemPledgedAssets(address tokenAddr, uint amount, address user) external ;
    // obtain SLC coin
    function obtainSLC(uint amount, address user) external ;
    // return SLC coin
    function returnSLC(uint amount, address user) external ;


    // mapping(address => licensedAsset) public licensedAssets;
    // address[] public assetsSerialNumber;
    
    // // address is user address, second address is licensedAssets address,  uint is the amount of assets
    // mapping(address => mapping(address => uint)) userAssetsMortgageAmount;
    // mapping(address => uint) userAssetsMortgageAmountSum;
    // mapping(address => uint) userObtainedSLCAmount;

    // mapping(address => uint8) public userMode; //0 High liquidity collateral mode; 1 Risk isolation mode

}