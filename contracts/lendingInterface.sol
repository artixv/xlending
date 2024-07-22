// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/iLendingManager.sol";
import "./interfaces/iwxcfx.sol";
import "./interfaces/islcoracle.sol";

contract lendingInterface  {
    address public lendingManager;
    address public wcfx;
    address public oracleAddr;

    constructor(address _lendingManager, address _wcfx, address _oracleAddr) {
        lendingManager = _lendingManager;
        wcfx = _wcfx;
        oracleAddr = _oracleAddr;
    }

    //------------------------------------------------ View ----------------------------------------------------
    function licensedAssets(address token) public view returns (iLendingManager.licensedAsset memory){
        return iLendingManager(lendingManager).licensedAssets(token);
    }

    function viewUsersHealthFactor(address user) public view returns(uint userHealthFactor){
        return iLendingManager(lendingManager).viewUsersHealthFactor(user);
    }

    function assetsLiqPenaltyInfo(address token) external view returns(uint liqPenalty){
        return iLendingManager(lendingManager).assetsLiqPenaltyInfo( token);
    }

    function assetsDepositAndLendAddrs(address token) public view returns (address[2] memory depositAndLend){
        return iLendingManager(lendingManager).assetsDepositAndLendAddrs( token);
    }
    function assetsDepositAndLendAmount(address token) public view returns (uint[2] memory depositAndLendAmount){
        address[2] memory depositAndLend = iLendingManager(lendingManager).assetsDepositAndLendAddrs( token);
        depositAndLendAmount[0] = IERC20(depositAndLend[0]).totalSupply();
        depositAndLendAmount[1] = IERC20(depositAndLend[1]).totalSupply();
    }
    function lendAvailableAmount() external view returns (uint[] memory availableAmount){
        uint[] memory assetPrice = licensedAssetPrice();
        availableAmount = new uint[](assetPrice.length);
        uint[2] memory depositAndLendAmount;
        for(uint i=0;i<assetPrice.length;i++){
            depositAndLendAmount = assetsDepositAndLendAmount(assetsSerialNumber(i));
            if(depositAndLendAmount[0]>depositAndLendAmount[1]){
                availableAmount[i] = depositAndLendAmount[0] - depositAndLendAmount[1];
            }else{
                availableAmount[i] = 0;
            }
        }
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
    
    function assetsTimeDependentParameter(address token) public view returns(uint latestDepositCoinValue,
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
    function licensedRIMassetsInfo() public view returns(address[] memory allRIMtokens,
                                                         uint[] memory allRIMtokensPrice, 
                                                         uint[] memory maxLendingAmountInRIM){
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
    function userAssetOverview(address user) public view returns(address[] memory tokens, 
                                                                   uint[] memory _amountDeposit, 
                                                                   uint[] memory _amountLending){
        return iLendingManager(lendingManager).userAssetOverview( user);
    }
    function userAssetDetail(address user) external view returns(address[] memory tokens, 
                                                                uint[] memory _amountDeposit, 
                                                                uint[] memory _amountLending,
                                                                uint[] memory _depositInterest,
                                                                uint[] memory _lendingInterest,
                                                                uint[] memory _availableAmount){
        (tokens,_amountDeposit,_amountLending) = iLendingManager(lendingManager).userAssetOverview(user);
        uint UserLendableLimit = viewUserLendableLimit(user);
        uint[] memory assetsPrice= licensedAssetPrice();
        _depositInterest = new uint[](tokens.length);
        _lendingInterest = new uint[](tokens.length);
        _availableAmount = new uint[](tokens.length);
        for(uint i=0;i<tokens.length;i++){
            (,,_depositInterest[i],_lendingInterest[i]) = assetsTimeDependentParameter(tokens[i]);
            if(assetsPrice[i] > 0){
                _availableAmount[i] = UserLendableLimit * 1 ether / assetsPrice[i];
            }else{
                _availableAmount[i] = 0;
            }
            
        }
        
    }
    // operator mode:  assetsDeposit 0, withdrawDeposit 1, lendAsset 2, repayLoan 3
    function usersHealthFactorEstimate(address user,address token,uint amount,uint operator) external view returns(uint userHealthFactor){
        // require(assetsSerialNumber.length < 100,"Lending Manager: Too Much assets");
        uint _amountDeposit;
        uint _amountLending;

        (_amountDeposit,_amountLending) = iLendingManager(lendingManager).userDepositAndLendingValue( user);
        if(operator == 0){
            _amountDeposit += amount * iSlcOracle(oracleAddr).getPrice(token) / 1 ether;
        }else if(operator == 1){
            _amountDeposit -= amount * iSlcOracle(oracleAddr).getPrice(token) / 1 ether;
        }else if(operator == 2){
            _amountLending += amount * iSlcOracle(oracleAddr).getPrice(token) / 1 ether;
        }else if(operator == 3){
            _amountLending -= amount * iSlcOracle(oracleAddr).getPrice(token) / 1 ether;
        }
        if(_amountLending > 0){
            userHealthFactor = _amountDeposit * 1 ether / _amountLending;
        }else if(_amountDeposit > 0){
            userHealthFactor = 1000 ether;
        }else{
            userHealthFactor = 0 ether;
        }
        if(userHealthFactor > 1000 ether){
            userHealthFactor = 1000 ether;
        }
    }
    // User's Lendable Limit
    function viewUserLendableLimit(address user) public view returns(uint userLendableLimit){
        // require(assetsSerialNumber.length < 100,"Lending Manager: Too Much assets");
        uint _amountDeposit;
        uint _amountLending;
        uint8 _userMode = iLendingManager(lendingManager).userMode(user);
        (_amountDeposit,_amountLending) = iLendingManager(lendingManager).userDepositAndLendingValue( user);
        if(_userMode>1){
            userLendableLimit = _amountDeposit * 1 ether / nomalFloorOfHealthFactor() - _amountLending;
        }else{
            userLendableLimit = _amountDeposit * 1 ether / homogeneousFloorOfHealthFactor() - _amountLending;
        }
    }

    function assetsSerialNumber(uint num) public view returns(address){
        return iLendingManager(lendingManager).assetsSerialNumber(num);
    }
    function userMode(address user) public view returns(uint8 mode, address userSetAssets){
        mode = iLendingManager(lendingManager).userMode(user);
        userSetAssets = iLendingManager(lendingManager).userRIMAssetsAddress(user);
    }
    // uint public constant ONE_YEAR = 31536000;
    function ONE_YEAR() public view returns (uint){
        return iLendingManager(lendingManager).ONE_YEAR();
    }
    // uint public constant UPPER_SYSTEM_LIMIT = 10000;
    function UPPER_SYSTEM_LIMIT() public view returns (uint){
        return iLendingManager(lendingManager).UPPER_SYSTEM_LIMIT();
    }
    // uint    public nomalFloorOfHealthFactor;
    function nomalFloorOfHealthFactor() public view returns (uint){
        return iLendingManager(lendingManager).nomalFloorOfHealthFactor();
    }
    // uint    public homogeneousFloorOfHealthFactor;
    function homogeneousFloorOfHealthFactor() public view returns (uint){
        return iLendingManager(lendingManager).homogeneousFloorOfHealthFactor();
    }
    
    function userRIMAssetsLendingNetAmount(address user,address token) public view returns (uint){
        return iLendingManager(lendingManager).userRIMAssetsLendingNetAmount(user,token);
    }
    // mapping(address => uint) public riskIsolationModeLendingNetAmount; //RIM  Risk Isolation Mode
    function riskIsolationModeLendingNetAmount(address token) public view returns (uint){
        return iLendingManager(lendingManager).riskIsolationModeLendingNetAmount(token);
    }

    function usersRiskDetails(address user) external view returns(uint userValueUsedRatio, 
                                                                  uint userMaxUsedRatio, 
                                                                  uint tokenLiquidateRatio){
        uint[3] memory tempRustFactor;
        uint8 _mode;
        address _userRIMSetAssets;
        (_mode, _userRIMSetAssets) = userMode( user);
        // tempRustFactor[0] = viewUsersHealthFactor(user);
        // userHealthFactor = tempRustFactor[0];
        address[] memory tokens;
        uint[] memory _amountDeposit;
        uint[] memory _amountLending;
        // uint _max_amount = UPPER_SYSTEM_LIMIT();  
        iLendingManager.licensedAsset memory usefulAsset;
        uint[] memory assetPrice = licensedAssetPrice();
        (tokens, _amountDeposit, _amountLending) = userAssetOverview(user);
        if(_mode == 1){
            for(uint i=0;i<tokens.length;i++){
                if(tokens[i] ==_userRIMSetAssets && _amountDeposit[i] > 0){
                    userValueUsedRatio = (userRIMAssetsLendingNetAmount(user,_userRIMSetAssets) * 10000 / _amountDeposit[i] )
                                       * 1 ether / assetPrice[i];
                    usefulAsset = licensedAssets(tokens[i]);
                    userMaxUsedRatio = usefulAsset.maximumLTV * 1 ether / nomalFloorOfHealthFactor();
                    tokenLiquidateRatio = usefulAsset.maximumLTV;
                    break;
                }
            }
        }else if(_mode == 0){
            for(uint i=0;i<tokens.length;i++){
                usefulAsset = licensedAssets(tokens[i]);
                if(usefulAsset.lendingModeNum != 1){
                    tempRustFactor[1] += _amountDeposit[i] * assetPrice[i] / 1 ether;
                    tempRustFactor[2] += _amountLending[i] * assetPrice[i] / 1 ether;
                    userMaxUsedRatio += _amountDeposit[i] * assetPrice[i] * usefulAsset.maximumLTV / nomalFloorOfHealthFactor()
                                    / 10000;
                    tokenLiquidateRatio += _amountDeposit[i] * assetPrice[i] / 1 ether * usefulAsset.maximumLTV / 10000;
                }
            }
            if(tempRustFactor[1] > 0){
                userValueUsedRatio = tempRustFactor[2] * 10000 / tempRustFactor[1];
                userMaxUsedRatio = userMaxUsedRatio * 10000 / tempRustFactor[1];
                tokenLiquidateRatio = tokenLiquidateRatio * 10000/ tempRustFactor[1];
            }else{
                userValueUsedRatio = 0;
                userMaxUsedRatio = 0;
                tokenLiquidateRatio = 0;
            }
        }else if(_mode > 1){
            for(uint i=0;i<tokens.length;i++){
                usefulAsset = licensedAssets(tokens[i]);
                if(usefulAsset.lendingModeNum == _mode){
                    tempRustFactor[1] += _amountDeposit[i] * assetPrice[i] / 1 ether;
                    tempRustFactor[2] += _amountLending[i] * assetPrice[i] / 1 ether;
                    userMaxUsedRatio += _amountDeposit[i] * assetPrice[i] * usefulAsset.maximumLTV / homogeneousFloorOfHealthFactor()
                                    / 10000;
                    tokenLiquidateRatio += _amountDeposit[i] * assetPrice[i] / 1 ether * usefulAsset.maximumLTV / 10000;
                }
            }
            if(tempRustFactor[1] > 0){
                userValueUsedRatio = tempRustFactor[2] * 10000 / tempRustFactor[1];
                userMaxUsedRatio = userMaxUsedRatio * 10000 / tempRustFactor[1];
                tokenLiquidateRatio = tokenLiquidateRatio * 10000 / tempRustFactor[1];
            }else{
                userValueUsedRatio = 0;
                userMaxUsedRatio = 0;
                tokenLiquidateRatio = 0;
            }
        }
    }

    function userProfile(address user) public view returns (int netWorth, int netApy){
        uint[5] memory tempRustFactor;
        uint8 _mode;
        address _userRIMSetAssets;
        (_mode, _userRIMSetAssets) = userMode( user);
        
        address[] memory tokens;
        uint[] memory _amountDeposit;
        uint[] memory _amountLending;
        uint[] memory assetPrice = licensedAssetPrice();
        (tokens, _amountDeposit, _amountLending) = userAssetOverview(user);
        uint  depositInterest;
        uint  lendingInterest;
        for(uint i=0;i<tokens.length;i++){
            tempRustFactor[0] = tempRustFactor[0] + _amountDeposit[i];
            tempRustFactor[1] = tempRustFactor[1] + _amountDeposit[i] * assetPrice[i] / 1 ether;
            tempRustFactor[2] = tempRustFactor[2] + _amountLending[i] * assetPrice[i] / 1 ether;
            (,,depositInterest,lendingInterest) = assetsTimeDependentParameter(tokens[i]);
            tempRustFactor[3] = tempRustFactor[3] + depositInterest * _amountDeposit[i] * assetPrice[i] / 1 ether;
            tempRustFactor[4] = tempRustFactor[4] + lendingInterest * _amountLending[i] * assetPrice[i] / 1 ether;
        }
        netWorth = netWorth + int(tempRustFactor[1]) - int(tempRustFactor[2]);
        if(tempRustFactor[0] == 0){
            netApy = 0;
        }else{
            netApy = (int(tempRustFactor[3]) - int(tempRustFactor[4])) / int(tempRustFactor[0]);
        }
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
    function withdrawDepositMax(address tokenAddr) external{
        address[2] memory depositAndLend = assetsDepositAndLendAddrs(tokenAddr);
        uint tokenBalance = IERC20(depositAndLend[0]).balanceOf(address(msg.sender));
        iLendingManager(lendingManager).withdrawDeposit( tokenAddr, tokenBalance, msg.sender);
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
    function repayLoanMax(address tokenAddr) external{
        address[2] memory depositAndLend = assetsDepositAndLendAddrs(tokenAddr);
        uint tokenBalance = IERC20(depositAndLend[1]).balanceOf(address(msg.sender));
        IERC20(tokenAddr).transferFrom(msg.sender,address(this),tokenBalance);
        IERC20(tokenAddr).approve(lendingManager, tokenBalance);
        iLendingManager(lendingManager).repayLoan( tokenAddr, tokenBalance, msg.sender);
        if(IERC20(tokenAddr).balanceOf(address(this))>0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
    }
    //-----------------------------------------Operation 2 can use CFX---------------------------------------------
    //  Assets Deposit
    function assetsDeposit2(address tokenAddr, uint amount) external payable {
        if(tokenAddr == wcfx){
            require(amount <= msg.value,"Lending Interface: amount should == msg.value");
            iwxCFX(wcfx).deposit{value:amount}();
        }else{
            require(msg.value == 0,"Lending Interface: msg.value should == 0");
            IERC20(tokenAddr).transferFrom(msg.sender,address(this),amount);
        }
        
        IERC20(tokenAddr).approve(lendingManager, amount);
        iLendingManager(lendingManager).assetsDeposit(tokenAddr, amount, msg.sender);
        if(IERC20(wcfx).balanceOf(address(this))>0){
            iwxCFX(wcfx).withdraw(IERC20(wcfx).balanceOf(address(this)));
        }
        if(IERC20(tokenAddr).balanceOf(address(this))>0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
        if(address(this).balance>0){
            address payable receiver = payable(msg.sender); // Set receiver
            (bool success, ) = receiver.call{value:address(this).balance}("");
            require(success,"Lending Interface: CFX Transfer Failed");
        }
    }
    // Withdrawal of deposits
    function withdrawDeposit2(address tokenAddr, uint amount) external{
        iLendingManager(lendingManager).withdrawDeposit( tokenAddr, amount, msg.sender);
        if(IERC20(wcfx).balanceOf(address(this))>0){
            iwxCFX(wcfx).withdraw(IERC20(wcfx).balanceOf(address(this)));
        }
        if(IERC20(tokenAddr).balanceOf(address(this)) > 0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
        if(address(this).balance>0){
            address payable receiver = payable(msg.sender); // Set receiver
            (bool success, ) = receiver.call{value:address(this).balance}("");
            require(success,"Lending Interface: CFX Transfer Failed");
        }
    }
    function withdrawDepositMax2(address tokenAddr) external{
        address[2] memory depositAndLend = assetsDepositAndLendAddrs(tokenAddr);
        uint tokenBalance = IERC20(depositAndLend[0]).balanceOf(address(msg.sender));
        iLendingManager(lendingManager).withdrawDeposit( tokenAddr, tokenBalance, msg.sender);
        if(IERC20(wcfx).balanceOf(address(this))>0){
            iwxCFX(wcfx).withdraw(IERC20(wcfx).balanceOf(address(this)));
        }
        if(IERC20(tokenAddr).balanceOf(address(this)) > 0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
        if(address(this).balance>0){
            address payable receiver = payable(msg.sender); // Set receiver
            (bool success, ) = receiver.call{value:address(this).balance}("");
            require(success,"Lending Interface: CFX Transfer Failed");
        }
    }
    // lend Asset
    function lendAsset2(address tokenAddr, uint amount) external{
        iLendingManager(lendingManager).lendAsset( tokenAddr, amount, msg.sender);
        if(IERC20(wcfx).balanceOf(address(this))>0){
            iwxCFX(wcfx).withdraw(IERC20(wcfx).balanceOf(address(this)));
        }else if(IERC20(tokenAddr).balanceOf(address(this)) > 0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
        if(address(this).balance>0){
            address payable receiver = payable(msg.sender); // Set receiver
            (bool success, ) = receiver.call{value:address(this).balance}("");
            require(success,"Lending Interface: CFX Transfer Failed");
        }
    }
    // repay Loan
    function repayLoan2(address tokenAddr,uint amount) external payable {
        if(tokenAddr == wcfx){
            require(amount <= msg.value,"Lending Interface: amount should == msg.value");
            iwxCFX(wcfx).deposit{value:amount}();
        }else{
            require(msg.value == 0,"Lending Interface: msg.value should == 0");
            IERC20(tokenAddr).transferFrom(msg.sender,address(this),amount);
        }
        IERC20(tokenAddr).approve(lendingManager, amount);
        iLendingManager(lendingManager).repayLoan( tokenAddr, amount, msg.sender);
        if(IERC20(wcfx).balanceOf(address(this))>0){
            iwxCFX(wcfx).withdraw(IERC20(wcfx).balanceOf(address(this)));
        }
        if(IERC20(tokenAddr).balanceOf(address(this))>0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
        if(address(this).balance>0){
            address payable receiver = payable(msg.sender); // Set receiver
            (bool success, ) = receiver.call{value:address(this).balance}("");
            require(success,"Lending Interface: CFX Transfer Failed");
        }
    }
    function repayLoanMax2(address tokenAddr) external payable {
        address[2] memory depositAndLend = assetsDepositAndLendAddrs(tokenAddr);
        uint tokenBalance = IERC20(depositAndLend[1]).balanceOf(address(msg.sender));
        if(tokenAddr == wcfx){
            require(tokenBalance <= msg.value,"Lending Interface: amount should == msg.value");
            iwxCFX(wcfx).deposit{value:tokenBalance}();
        }else{
            require(msg.value == 0,"Lending Interface: msg.value should == 0");
            IERC20(tokenAddr).transferFrom(msg.sender,address(this),tokenBalance);
        }
        // IERC20(tokenAddr).transferFrom(msg.sender,address(this),tokenBalance);
        IERC20(tokenAddr).approve(lendingManager, tokenBalance);
        iLendingManager(lendingManager).repayLoan( tokenAddr, tokenBalance, msg.sender);
        if(IERC20(wcfx).balanceOf(address(this))>0){
            iwxCFX(wcfx).withdraw(IERC20(wcfx).balanceOf(address(this)));
        }
        if(IERC20(tokenAddr).balanceOf(address(this))>0){
            IERC20(tokenAddr).transfer(msg.sender,IERC20(tokenAddr).balanceOf(address(this)));
        }
        if(address(this).balance>0){
            address payable receiver = payable(msg.sender); // Set receiver
            (bool success, ) = receiver.call{value:address(this).balance}("");
            require(success,"Lending Interface: CFX Transfer Failed");
        }
    }
    // ======================== contract base methods =====================
    fallback() external payable {}
    receive() external payable {}

}