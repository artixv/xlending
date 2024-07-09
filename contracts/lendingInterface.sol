// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/iLendingManager.sol";

contract lendingInterface  {
    address lendingManager;

    constructor(address _lendingManager) {
        lendingManager = _lendingManager;
    }

    //------------------------------------------------ View ----------------------------------------------------

    function viewUsersHealthFactor(address user) external view returns(uint userHealthFactor){
        return iLendingManager(lendingManager).viewUsersHealthFactor(user);
    }
    function viewUserLendableLimit(address user) external view returns(uint userLendableLimit){
        return iLendingManager(lendingManager).viewUserLendableLimit( user);
    }
    function assetsLiqPenaltyInfo(address token) external view returns(uint liqPenalty){
        return iLendingManager(lendingManager).assetsLiqPenaltyInfo( token);
    }

    function assetsDepositAndLendAddrs(address token) external view returns (address[2] memory depositAndLend){
        return iLendingManager(lendingManager).assetsDepositAndLendAddrs( token);
    }
    function assetsDepositAndLendAmount(address token) external view returns (uint[2] memory depositAndLendAmount){
        address[2] memory depositAndLend = iLendingManager(lendingManager).assetsDepositAndLendAddrs( token);
        depositAndLendAmount[0] = IERC20(depositAndLend[0]).totalSupply();
        depositAndLendAmount[1] = IERC20(depositAndLend[1]).totalSupply();
    }

    function assetsBaseInfo(address token) public view returns(uint maximumLTV,
                                                               uint liquidationPenalty,
                                                               uint maxLendingAmountInRIM,
                                                               uint bestLendingRatio,
                                                               uint lendingModeNum,
                                                               uint homogeneousModeLTV,
                                                               uint bestDepositInterestRate){
        return iLendingManager(lendingManager).assetsBaseInfo(token);
    }
    
    function assetsTimeDependentParameter(address token) external view returns(uint latestDepositCoinValue,
                                                                   uint latestLendingCoinValue,
                                                                   uint latestDepositInterest,
                                                                   uint latestLendingInterest){
        return iLendingManager(lendingManager).assetsTimeDependentParameter( token);
    }
    
    function licensedAssetPrice() public view returns(uint[] memory assetPrice){
        return iLendingManager(lendingManager).licensedAssetPrice() ;
    }
    function licensedAssetOverview() external view returns(uint totalValueOfMortgagedAssets, uint totalValueOfLendedAssets){
        return iLendingManager(lendingManager).licensedAssetOverview();
    }
    function licensedRIMassetsInfo() public view returns(address[] memory allRIMtokens,uint[] memory allRIMtokensPrice, uint[] memory maxLendingAmountInRIM){
        uint[] memory assetPrice = licensedAssetPrice();
        address[] memory assets = new address[](assetPrice.length);
        uint[] memory maxLendingAmount = new uint[](assetPrice.length);
        uint num = assetPrice.length;
        uint RIMnum;
        uint tempMax;
        for(uint i; i<num; i++){
            (,,tempMax,,,,) = assetsBaseInfo(assetsSerialNumber(i));
            if(tempMax > 0){
                RIMnum +=1;
                assets[RIMnum - 1] = assetsSerialNumber(i);
                assetPrice[RIMnum - 1] = assetPrice[i];
                maxLendingAmount[RIMnum - 1] = tempMax;
            }
        }
        allRIMtokens = new address[](RIMnum);
        maxLendingAmountInRIM = new uint[](RIMnum);
        allRIMtokensPrice = new uint[](RIMnum);
        for(uint i; i<RIMnum; i++){
            allRIMtokens[i] = assets[i];
            allRIMtokensPrice[i] = assetPrice[i];
            maxLendingAmountInRIM[i] = maxLendingAmount[i];
        }
    }
    function userDepositAndLendingValue(address user) public view returns(uint _amountDeposit,uint _amountLending){
        return iLendingManager(lendingManager).userDepositAndLendingValue( user);
    }
    function userAssetOverview(address user) external view returns(address[] memory tokens, uint[] memory _amountDeposit, uint[] memory _amountLending){
        return iLendingManager(lendingManager).userAssetOverview( user);
    }
    function usersHealthFactorEstimate(address user,address token,uint amount,uint operator) external view returns(uint userHealthFactor){
        return iLendingManager(lendingManager).usersHealthFactorEstimate(user, token, amount, operator);
    }
    function assetsSerialNumber(uint num) public view returns(address){
        return iLendingManager(lendingManager).assetsSerialNumber(num);
    }

    //------------------------------------------------Operation----------------------------------------------------
    function userModeSetting(uint8 _mode,address _userRIMAssetsAddress) external{
        iLendingManager(lendingManager).userModeSetting( _mode, _userRIMAssetsAddress, msg.sender);
    }
    //  Assets Deposit
    function assetsDeposit(address tokenAddr, uint amount) external{
        IERC20(tokenAddr).transferFrom(msg.sender,address(this),amount);
        IERC20(tokenAddr).approve(lendingManager, amount);
        iLendingManager(lendingManager).assetsDeposit(tokenAddr, amount, msg.sender);
        if(IERC20(tokenAddr).balanceOf(address(this))>0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
    }
    // Withdrawal of deposits
    function withdrawDeposit(address tokenAddr, uint amount) external{
        iLendingManager(lendingManager).withdrawDeposit( tokenAddr, amount, msg.sender);
        if(IERC20(tokenAddr).balanceOf(address(this)) > 0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
    }
    // lend Asset
    function lendAsset(address tokenAddr, uint amount) external{
        iLendingManager(lendingManager).lendAsset( tokenAddr, amount, msg.sender);
        if(IERC20(tokenAddr).balanceOf(address(this)) > 0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
    }
    // repay Loan
    function repayLoan(address tokenAddr,uint amount) external{
        IERC20(tokenAddr).transferFrom(msg.sender,address(this),amount);
        IERC20(tokenAddr).approve(lendingManager, amount);
        iLendingManager(lendingManager).repayLoan( tokenAddr, amount, msg.sender);
        if(IERC20(tokenAddr).balanceOf(address(this))>0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
    }

}