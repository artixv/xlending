// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.07.30

pragma solidity 0.8.6;
import "./interfaces/iLendingManager.sol";
import "./interfaces/iDepositOrLoanCoin.sol";

contract lendingCoreAlgorithm  {
    address public lendingManager;

    constructor(address _setLendingManager) {
        lendingManager = _setLendingManager;
    }
    struct assetInfo{
        uint    latestDepositCoinValue;
        uint    latestLendingCoinValue;
        uint    latestDepositInterest;
        uint    latestLendingInterest;
    }
    function assetsValueUpdate(address token) public view returns(uint[2] memory latestInterest){
        address[2] memory depositAndLend = iLendingManager(lendingManager).assetsDepositAndLendAddrs(token);
        uint lendingRatio;

        if(iDepositOrLoanCoin(depositAndLend[0]).totalSupply() > 0){
            lendingRatio = iDepositOrLoanCoin(depositAndLend[1]).totalSupply() * 10000 / iDepositOrLoanCoin(depositAndLend[0]).totalSupply();
        }else{
            lendingRatio = 0;
        }
        
        if(lendingRatio > 10000){
            lendingRatio = 10000;
        }
        latestInterest[0] = depositInterestRate( token, lendingRatio);
        latestInterest[1] = lendingInterestRate( token, lendingRatio);
    }
    // function assetsBaseInfo(address token) external view returns(uint maximumLTV,
    //                                                            uint liquidationPenalty,
    //                                                            uint maxLendingAmountInRIM,
    //                                                            uint bestLendingRatio,
    //                                                            uint lendingModeNum,
    //                                                            uint homogeneousModeLTV,
    //                                                            uint bestDepositInterestRate);

    function assetsBaseInfo(address token) internal view returns(uint maximumLTV,
                                                               uint bestLendingRatio,
                                                               uint lendingModeNum,
                                                               uint bestDepositInterestRate){
        (maximumLTV,,,bestLendingRatio,lendingModeNum,,bestDepositInterestRate) = iLendingManager(lendingManager).assetsBaseInfo(token);
    }

    function depositInterestRate(address token,uint lendingRatio) public view returns(uint _rate){
        uint[4] memory info;
        (info[0],info[1],info[2],info[3]) = assetsBaseInfo(token);
        uint bestLendingRatio = info[1];
        if(lendingRatio <= bestLendingRatio + 500){
            _rate = (info[3] * lendingRatio / bestLendingRatio) * lendingRatio / bestLendingRatio;
        }else if(lendingRatio <= 9500){
            _rate = (info[3] * lendingRatio / bestLendingRatio) * lendingRatio / bestLendingRatio
                  * (lendingRatio - bestLendingRatio)  / 500;
        }else if(lendingRatio <= 10000){
            _rate = (info[3] * lendingRatio / bestLendingRatio) * lendingRatio / bestLendingRatio
                  * (lendingRatio - bestLendingRatio)  / 500
                  * (lendingRatio - 9400) / 100;
        }
    }
    function lendingInterestRate(address token,uint lendingRatio) public view returns(uint _rate){
        uint[4] memory info;
        (info[0],info[1],info[2],info[3]) = assetsBaseInfo(token);
        uint bestLendingRatio = info[1];
        if(lendingRatio <= bestLendingRatio + 500){
            _rate = (info[3] * lendingRatio / bestLendingRatio) * 10500 / bestLendingRatio * 10000 / info[0] ;
        }else if(lendingRatio <= 9500){
            _rate = (info[3] * lendingRatio / bestLendingRatio) * 10500 / bestLendingRatio * 10000 / info[0]
                  * (lendingRatio - bestLendingRatio)  / 500 * lendingRatio / (bestLendingRatio +500);
        }else if(lendingRatio <= 10000){
            _rate = (info[3] * lendingRatio / bestLendingRatio) * 10500 / bestLendingRatio * 10000 / info[0]
                  * (lendingRatio - bestLendingRatio)  / 500 * lendingRatio / (bestLendingRatio +500)
                  * (lendingRatio - 9400) * (lendingRatio - 9400)/ 10000;
        }
    }

}