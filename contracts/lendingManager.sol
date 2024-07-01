// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ixinterface.sol";
import "./interfaces/islcoracle.sol";

import "./interfaces/iCoinfactory.sol";
import "./interfaces/iDepositOrLoanCoin.sol";
import "./interfaces/iLendingCoreAlgorithm.sol";
import "./interfaces/iLendingVaults.sol";

contract lendingManager  {
    address public superLibraCoin;
    uint    public slcValue;
    uint    public slcUnsecuredIssuancesAmount;

    address public xInterface;
    address public oracleAddr;
    address public coinFactory;
    address public lendingVault;
    address public coreAlgorithm;

    address public setter;
    address newsetter;
    address public rebalancer;

    uint    public nomalFloorOfHealthFactor;
    uint    public homogeneousFloorOfHealthFactor;

    //  Assets Init:   SLC  USDT  USDC  BTC  ETH  CFX  xCFX sxCFX NUT  CFXs
    //  MaximumLTV:    96%   95%   95%  88%  85%  65%  65%   75%  55%  55%
    //  LiqPenalty:     3%    5%    5%   5%   5%   5%   5%    5%   5%   5%
    //maxLendingAmountInRIM:  0    0     0    0    0    0    0      0  1e6  1e6
    //bestLendingRatio: 90%  85%   85%  70%  70%  65%  65%   65%  50%  50%
    //lendingModeNum:    2     2     2    0    0    3    3     3    0    0


    struct licensedAsset{
        address assetAddr;             
        uint    maximumLTV;               // loan-to-value (LTV) ratio is a measurement lenders use to compare your loan amount 
                                          // for a home against the value of that property.(MAX = 10000) 
        uint    liquidationPenalty;       // MAX = 10000 ,default is 500(5%)
        uint    bestLendingRatio;         // MAX = 10000 , setting NOT more than 9000
        uint    bestDepositInterestRate ; // MAX = 10000 , setting NOT more than 1000
        uint    maxLendingAmountInRIM;         // default is 0, means no limits; if > 0, have limits : 1 ether = 1 slc
        uint8   lendingModeNum;           // Risk Isolation Mode: 1 ; SLC  USDT  USDC : 2  ;  CFX  xCFX sxCFX : 3
        uint    homogeneousModeLTV;       // SLC  USDT  USDC : 97%  ; CFX  xCFX sxCFX : 95%
    }

    struct assetInfo{
        uint    latestDepositCoinValue;   // Relative to the initial DepositCoin value, the initial value is 1 ether
        uint    latestLendingCoinValue;   // Relative to the initial LendingCoin value, the initial value is 1 ether
        uint    latestDepositInterest;    // Latest interest value of DepositCoin
        uint    latestLendingInterest;    // Latest interest value of LendingCoin
        uint    latestTimeStamp;          // Latest TimeStamp
    }

    mapping(address => licensedAsset) public licensedAssets;
    mapping(address => address[2]) assetsDepositAndLend;
    address[] public assetsSerialNumber;

    mapping(address => bool) public lendingInterface;

    mapping(address => assetInfo) public assetInfos;
    
    mapping(address => mapping(address => uint)) public userRIMAssetsLendingNetAmount;
    mapping(address => uint) public riskIsolationModeLendingNetAmount; //RIM  Risk Isolation Mode
    mapping(address => address) public userRIMAssetsAddress; 
    address public riskIsolationModeAcceptAssets;

    mapping(address => uint8) public userMode; // High liquidity collateral mode:  0 ; 
                                               // Risk isolation mode              1 ;
                                               // homogeneousMode:                 2  SLC  USDT  USDC; 96% 3%
                                               // homogeneousMode:                 3  CFX  xCFX sxCFX; 95% 5%

    //----------------------------modifier ----------------------------
    modifier onlySetter() {
        require(msg.sender == setter, 'Lending Manager: Only Setter Use');
        _;
    }
    //----------------------------- event -----------------------------
    event AssetsDeposit(address indexed tokenAddr, uint amount, address user);
    event WithdrawDeposit(address indexed tokenAddr, uint amount, address user);
    event LendAsset(address indexed tokenAddr, uint amount, address user);
    event RepayLoan(address indexed tokenAddr,uint amount, address user);
    event LicensedAssetsSetup(address indexed _asset, 
                                uint _maxLTV, 
                                uint _liqPenalty,
                                uint _maxLendingAmountInRIM, 
                                uint _bestLendingRatio, 
                                uint8 _lendingModeNum,
                                uint _homogeneousModeLTV,
                                uint _bestDepositInterestRate) ;
    event UserModeSetting(address indexed user,uint8 _mode,address _userRIMAssetsAddress);
    //------------------------------------------------------------------

    constructor() {
        setter = msg.sender;
        slcValue = 1 ether;
        rebalancer = msg.sender;
        nomalFloorOfHealthFactor = 1.2 ether;
        homogeneousFloorOfHealthFactor = 1.03 ether;
    }

    // Evaluate the value of superLibraCoin
    function slcValueRevaluate(uint newValue) public  onlySetter {
        slcValue = newValue;
    }

    function transferSetter(address _set) external onlySetter{
        newsetter = _set;
    }
    function acceptSetter(bool _TorF) external {
        require(msg.sender == newsetter, 'Lending Manager: Permission FORBIDDEN');
        if(_TorF){
            setter = newsetter;
        }
        newsetter = address(0);
    }
    
    function setup( address _superLibraCoin,
                    address _xInterface,
                    address _coinFactory,
                    address _lendingVault,
                    address _riskIsolationModeAcceptAssets,
                    address _coreAlgorithm,
                    address _oracleAddr ) external onlySetter{
        superLibraCoin = _superLibraCoin;
        coinFactory = _coinFactory;
        xInterface = _xInterface;
        oracleAddr = _oracleAddr;
        lendingVault = _lendingVault;
        coreAlgorithm = _coreAlgorithm;
        riskIsolationModeAcceptAssets = _riskIsolationModeAcceptAssets;
    }
    function setlendingInterface(address _interface, bool _ToF) external onlySetter{
        lendingInterface[_interface] = _ToF;
    }
    function setFloorOfHealthFactor(uint nomal, uint homogeneous) external onlySetter{
        nomalFloorOfHealthFactor = nomal;
        homogeneousFloorOfHealthFactor = homogeneous;
    }

    function licensedAssetsRegister(address _asset, 
                                    uint _maxLTV, 
                                    uint _liqPenalty,
                                    uint _maxLendingAmountInRIM, 
                                    uint _bestLendingRatio, 
                                    uint8 _lendingModeNum,
                                    uint _homogeneousModeLTV,
                                    uint _bestDepositInterestRate) public onlySetter {
        require(licensedAssets[_asset].assetAddr == address(0),"Lending Manager: asset already registered!");
        assetsSerialNumber.push(_asset);
        licensedAssets[_asset].assetAddr = _asset;
        licensedAssets[_asset].maximumLTV = _maxLTV;
        licensedAssets[_asset].liquidationPenalty = _liqPenalty;
        licensedAssets[_asset].maxLendingAmountInRIM = _maxLendingAmountInRIM;
        licensedAssets[_asset].bestLendingRatio = _bestLendingRatio;
        licensedAssets[_asset].lendingModeNum = _lendingModeNum;
        licensedAssets[_asset].homogeneousModeLTV = _homogeneousModeLTV;
        licensedAssets[_asset].bestDepositInterestRate = _bestDepositInterestRate;
        assetsDepositAndLend[_asset] = iCoinFactory(coinFactory).createDeAndLoCoin(_asset);
        emit LicensedAssetsSetup(_asset, 
                                 _maxLTV, 
                                 _liqPenalty,
                                 _maxLendingAmountInRIM, 
                                 _bestLendingRatio, 
                                 _lendingModeNum,
                                 _homogeneousModeLTV,
                                 _bestDepositInterestRate) ;
    }
    function licensedAssetsReset(address _asset,
                                uint _maxLTV, 
                                uint _liqPenalty,
                                uint _maxLendingAmountInRIM, 
                                uint _bestLendingRatio, 
                                uint8 _lendingModeNum,
                                uint _homogeneousModeLTV,
                                uint _bestDepositInterestRate) public onlySetter {
        require(licensedAssets[_asset].assetAddr == _asset,"Lending Manager: asset is Not registered!");
        licensedAssets[_asset].maximumLTV = _maxLTV;
        licensedAssets[_asset].liquidationPenalty = _liqPenalty;
        licensedAssets[_asset].maxLendingAmountInRIM = _maxLendingAmountInRIM;
        licensedAssets[_asset].bestLendingRatio = _bestLendingRatio;
        licensedAssets[_asset].lendingModeNum = _lendingModeNum;
        licensedAssets[_asset].homogeneousModeLTV = _homogeneousModeLTV;
        licensedAssets[_asset].bestDepositInterestRate = _bestDepositInterestRate;
        emit LicensedAssetsSetup(_asset, 
                                 _maxLTV, 
                                 _liqPenalty,
                                 _maxLendingAmountInRIM, 
                                 _bestLendingRatio, 
                                 _lendingModeNum,
                                 _homogeneousModeLTV,
                                 _bestDepositInterestRate) ;
    }

    function userModeSetting(uint8 _mode,address _userRIMAssetsAddress, address user) public {
        if(lendingInterface[msg.sender] == false){
            require(user == msg.sender,"Lending Manager: Not registered as slcInterface or user need be msg.sender!");
        }
        require(userTotalLendingValue(user) == 0,"Lending Manager: Cant Change Mode before return all Lending Assets.");
        
        userMode[user] = _mode;
        userRIMAssetsAddress[user] = _userRIMAssetsAddress;
        emit UserModeSetting(user, _mode, _userRIMAssetsAddress);
    }

    //----------------------------- View Function------------------------------------
    function assetsBaseInfo(address token) public view returns(uint maximumLTV,uint bestLendingRatio,uint lendingModeNum,uint bestDepositInterestRate){
        return (licensedAssets[token].maximumLTV,licensedAssets[token].bestLendingRatio,licensedAssets[token].lendingModeNum,licensedAssets[token].bestDepositInterestRate);
    }
    function assetsLiqPenaltyInfo(address token) public view returns(uint liqPenalty){
        liqPenalty = licensedAssets[token].liquidationPenalty;
    }
    function assetsTimeDependentParameter(address token) public view returns(uint latestDepositCoinValue,
                                                                             uint latestLendingCoinValue,
                                                                             uint latestDepositInterest,
                                                                             uint latestLendingInterest){
        return (assetInfos[token].latestDepositCoinValue,
                assetInfos[token].latestLendingCoinValue,
                assetInfos[token].latestDepositInterest,
                assetInfos[token].latestLendingInterest);
    }
    function assetsDepositAndLendAddrs(address token) external view returns(address[2] memory addrs){
        return assetsDepositAndLend[token];
    }

    function licensedAssetPrice() public view returns(uint[] memory assetPrice){
        assetPrice = new uint[](assetsSerialNumber.length);
        require(assetsSerialNumber.length < 100,"Lending Manager: Too Much assets");
        for(uint i=0;i<assetsSerialNumber.length;i++){
            assetPrice[i] = iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]);
        }
    }
    function userTotalLendingValue(address _user) public view returns(uint values){
        require(assetsSerialNumber.length < 100,"Lending Manager: Too Much assets");
        for(uint i=0;i<assetsSerialNumber.length;i++){
            values += IERC20(assetsDepositAndLend[assetsSerialNumber[i]][1]).balanceOf(_user) * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether;
        }
    }
    function _userDepositAndLendingValue(address user) internal view returns(uint _amountDeposit,uint _amountLending){
        require(assetsSerialNumber.length < 100,"Lending Manager: Too Much assets");
        

        for(uint i=0;i<assetsSerialNumber.length;i++){
            if(userMode[user]==1 && assetsSerialNumber[i] == userRIMAssetsAddress[user]){
                _amountDeposit  = iDepositOrLoanCoin(assetsDepositAndLend[assetsSerialNumber[i]][0]).balanceOf(user)
                                * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether
                                * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
                _amountLending  = iDepositOrLoanCoin(assetsDepositAndLend[riskIsolationModeAcceptAssets][1]).balanceOf(user)
                                * iSlcOracle(oracleAddr).getPrice(riskIsolationModeAcceptAssets) / 1 ether
                                * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
                break;
            }
            if(userMode[user]>1){
                if(licensedAssets[assetsSerialNumber[i]].lendingModeNum == userMode[user]){
                    _amountDeposit += iDepositOrLoanCoin(assetsDepositAndLend[assetsSerialNumber[i]][0]).balanceOf(user)
                                    * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether
                                    * licensedAssets[assetsSerialNumber[i]].homogeneousModeLTV / 10000;
                    _amountLending += iDepositOrLoanCoin(assetsDepositAndLend[assetsSerialNumber[i]][1]).balanceOf(user)
                                    * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether
                                    * licensedAssets[assetsSerialNumber[i]].homogeneousModeLTV / 10000;
                }
                continue;
            }
            if(userMode[user]==0){
                if(licensedAssets[assetsSerialNumber[i]].maxLendingAmountInRIM > 0){
                    continue;
                }
                _amountDeposit += iDepositOrLoanCoin(assetsDepositAndLend[assetsSerialNumber[i]][0]).balanceOf(user)
                                * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether
                                * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
                _amountLending += iDepositOrLoanCoin(assetsDepositAndLend[assetsSerialNumber[i]][1]).balanceOf(user)
                                * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether
                                * licensedAssets[assetsSerialNumber[i]].maximumLTV / 10000;
            }
        }
    }

    function viewUsersHealthFactor(address user) public view returns(uint userHealthFactor){
        require(assetsSerialNumber.length < 100,"Lending Manager: Too Much assets");
        uint _amountDeposit;
        uint _amountLending;

        (_amountDeposit,_amountLending) = _userDepositAndLendingValue( user);
        if(_amountLending > 0){
            userHealthFactor = _amountDeposit * 1 ether / _amountLending;
        }else if(_amountDeposit > 0){
            userHealthFactor = 1000 ether;
        }else{
            userHealthFactor = 0 ether;
        }
    }
    // User's Lendable Limit
    function viewUserLendableLimit(address user) public view returns(uint userLendableLimit){
        require(assetsSerialNumber.length < 100,"Lending Manager: Too Much assets");
        uint _amountDeposit;
        uint _amountLending;
        (_amountDeposit,_amountLending) = _userDepositAndLendingValue( user);
        if(userMode[user]>1){
            userLendableLimit = _amountDeposit * 1 ether / nomalFloorOfHealthFactor - _amountLending;
        }else{
            userLendableLimit = _amountDeposit * 1 ether / homogeneousFloorOfHealthFactor - _amountLending;
        }
    }

    function licensedAssetOverview() public view returns(uint totalValueOfMortgagedAssets, uint totalValueOfLendedAssets){
        require(assetsSerialNumber.length < 100,"Lending Manager: Too Much assets");
        for(uint i=0;i<assetsSerialNumber.length;i++){
            totalValueOfMortgagedAssets += IERC20(assetsDepositAndLend[assetsSerialNumber[i]][0]).totalSupply() * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether;
            totalValueOfLendedAssets += IERC20(assetsDepositAndLend[assetsSerialNumber[i]][1]).totalSupply() * iSlcOracle(oracleAddr).getPrice(assetsSerialNumber[i]) / 1 ether;
        }
    }
    // 1 year = 31,536,000 s
    function getCoinValues(address token) public view returns(uint[2] memory currentValue){
        currentValue[0] = assetInfos[token].latestDepositCoinValue 
                        + (block.timestamp - assetInfos[token].latestTimeStamp) * 1 ether
                        * assetInfos[token].latestDepositInterest / (31536000 * 10000);
        currentValue[1] = assetInfos[token].latestLendingCoinValue 
                        + (block.timestamp - assetInfos[token].latestTimeStamp) * 1 ether
                        * assetInfos[token].latestLendingInterest / (31536000 * 10000);

        if(currentValue[0] == 0){
            currentValue[0] = 1 ether;
        }
        if(currentValue[1] == 0){
            currentValue[1] = 1 ether;
        }

    }

    function userAssetOverview(address user) public view returns(uint[] memory _amountDeposit, uint[] memory _amountLending){
        require(assetsSerialNumber.length < 100,"Lending Manager: Too Much assets");
        _amountDeposit = new uint[](assetsSerialNumber.length);
        _amountLending = new uint[](assetsSerialNumber.length);
        for(uint i=0;i<assetsSerialNumber.length;i++){
            _amountDeposit[i] = iDepositOrLoanCoin(assetsDepositAndLend[assetsSerialNumber[i]][0]).balanceOf(user);
            _amountLending[i] = iDepositOrLoanCoin(assetsDepositAndLend[assetsSerialNumber[i]][1]).balanceOf(user);
        }
    }

    //---------------------------- borrow & lend  Function----------------------------
    // struct assetInfo{
    //     uint    latestDepositCoinValue;
    //     uint    latestLendingCoinValue;
    //     uint    latestDepositInterest;
    //     uint    latestLendingInterest;
    //     uint    latestTimeStamp;
    // }
    function _beforeUpdate(address token) internal returns(uint[2] memory latestValues){
        latestValues = getCoinValues(token);
        assetInfos[token].latestDepositCoinValue = latestValues[0];
        assetInfos[token].latestLendingCoinValue = latestValues[1];
        assetInfos[token].latestTimeStamp = block.timestamp;

    }
    function _assetsValueUpdate(address token) internal returns(uint[2] memory latestInterest){
        require(assetInfos[token].latestTimeStamp == block.timestamp,"Lending Manager: Only be uesd after beforeUpdate");
        latestInterest = iLendingCoreAlgorithm(coreAlgorithm).assetsValueUpdate(token);
        assetInfos[token].latestDepositInterest = latestInterest[0];
        assetInfos[token].latestLendingInterest = latestInterest[1];
        
    }

    //  Assets Deposit
    function assetsDeposit(address tokenAddr, uint amount, address user) public  {
        if(lendingInterface[msg.sender]==false){
            require(user == msg.sender,"Lending Manager: Not registered as slcInterface or user need be msg.sender!");
        }
        require(amount > 0,"Lending Manager: Cant Pledge 0 amount");
        if(userMode[user] == 0){
            require(licensedAssets[tokenAddr].maxLendingAmountInRIM == 0,"Lending Manager: Wrong Token in Risk Isolation Mode");
        }else if(userMode[user] == 1){
            require((tokenAddr == userRIMAssetsAddress[user]),"Lending Manager: Wrong Token in Risk Isolation Mode");
        }else {
            require((licensedAssets[tokenAddr].lendingModeNum == userMode[user]),"Lending Manager: Wrong Mode, Need in same homogeneous Mode");
        }
        _beforeUpdate(tokenAddr);
        IERC20(tokenAddr).transferFrom(user,lendingVault,amount);
        iDepositOrLoanCoin(assetsDepositAndLend[tokenAddr][0]).mintCoin(user,amount);
        _assetsValueUpdate(tokenAddr);
        emit AssetsDeposit(tokenAddr, amount, user);
    
    }

    // Withdrawal of deposits
    function withdrawDeposit(address tokenAddr, uint amount, address user) public  {
        if(lendingInterface[msg.sender]==false){
            require(user == msg.sender,"Lending Manager: Not registered as slcInterface or user need be msg.sender!");
        }
        require(amount > 0,"Lending Manager: Cant Pledge 0 amount");
        if(userMode[user] == 0){
            require(licensedAssets[tokenAddr].maxLendingAmountInRIM == 0,"Lending Manager: Wrong Token in Risk Isolation Mode");
        }else if(userMode[user] == 1){
            require((tokenAddr == userRIMAssetsAddress[user]),"Lending Manager: Wrong Token in Risk Isolation Mode");
        }else {
            require((licensedAssets[tokenAddr].lendingModeNum == userMode[user]),"Lending Manager: Wrong Mode, Need in same homogeneous Mode");
        }
        //need + vualt add accept amount function (only manager)
        iLendingVaults(lendingVault).vaultsERC20Approve(tokenAddr, amount);
        _beforeUpdate(tokenAddr);
        IERC20(tokenAddr).transferFrom(lendingVault,user,amount);
        iDepositOrLoanCoin(assetsDepositAndLend[tokenAddr][0]).burnCoin(user,amount);
        _assetsValueUpdate(tokenAddr);
        
        uint factor;
        (factor) = viewUsersHealthFactor(user);
        if(userMode[user] > 1){
            require( factor >= homogeneousFloorOfHealthFactor,"Your Health Factor <= homogeneous Floor Of Health Factor, Cant redeem assets");
        }else{
            require( factor >= nomalFloorOfHealthFactor,"Your Health Factor <= nomal Floor Of Health Factor, Cant redeem assets");
        }
        emit WithdrawDeposit(tokenAddr, amount, user);
    
    }

    // lend Asset
    function lendAsset(address tokenAddr, uint amount, address user) public  {
        if(lendingInterface[msg.sender]==false){
            require(user == msg.sender,"Lending Manager: Not registered as slcInterface or user need be msg.sender!");
        }
        require(amount > 0,"Lending Manager: Cant Pledge 0 amount");
        if(userMode[user] == 0){
            require(licensedAssets[tokenAddr].maxLendingAmountInRIM == 0,"Lending Manager: Wrong Token in Risk Isolation Mode");
        }else if(userMode[user] == 1){
            require(tokenAddr == riskIsolationModeAcceptAssets,"Lending Manager: Wrong Token in Risk Isolation Mode");
            riskIsolationModeLendingNetAmount[tokenAddr] = riskIsolationModeLendingNetAmount[tokenAddr] 
                                                         - userRIMAssetsLendingNetAmount[user][tokenAddr]
                                                         + IERC20(assetsDepositAndLend[riskIsolationModeAcceptAssets][1]).balanceOf(user)
                                                         + amount;
            userRIMAssetsLendingNetAmount[user][tokenAddr] = IERC20(assetsDepositAndLend[riskIsolationModeAcceptAssets][1]).balanceOf(user)
                                                           + amount;
            require(riskIsolationModeLendingNetAmount[tokenAddr] <= licensedAssets[userRIMAssetsAddress[user]].maxLendingAmountInRIM,"Lending Manager: Deposit Amount exceed limits");
        }else {
            require((licensedAssets[tokenAddr].lendingModeNum == userMode[user]),"Lending Manager: Wrong Mode, Need in same homogeneous Mode");
        }
        _beforeUpdate(tokenAddr);
        iLendingVaults(lendingVault).vaultsERC20Approve(tokenAddr, amount);
        iDepositOrLoanCoin(assetsDepositAndLend[tokenAddr][1]).mintCoin(user,amount);
        IERC20(tokenAddr).transferFrom(lendingVault,msg.sender,amount);
        _assetsValueUpdate(tokenAddr);

        uint factor;
        (factor) = viewUsersHealthFactor(user);
        if(userMode[user] > 1){
            require( factor >= homogeneousFloorOfHealthFactor,"Your Health Factor <= homogeneous Floor Of Health Factor, Cant redeem assets");
        }else{
            require( factor >= nomalFloorOfHealthFactor,"Your Health Factor <= nomal Floor Of Health Factor, Cant redeem assets");
        }
        emit LendAsset(tokenAddr, amount, user);
    
    }

    // repay Loan
    function repayLoan(address tokenAddr,uint amount, address user) public  {
        if(lendingInterface[msg.sender]==false){
            require(user == msg.sender,"Lending Manager: Not registered as slcInterface or user need be msg.sender!");
        }
        require(amount > 0,"Lending Manager: Cant Pledge 0 amount");
        if(userMode[user] == 0){
            require(licensedAssets[tokenAddr].maxLendingAmountInRIM == 0,"Lending Manager: Wrong Token in Risk Isolation Mode");
        }else if(userMode[user] == 1){
            require(licensedAssets[tokenAddr].maxLendingAmountInRIM > 0,"Lending Manager: Wrong Token in Risk Isolation Mode");
            require((tokenAddr == riskIsolationModeAcceptAssets),"Lending Manager: Wrong Token in Risk Isolation Mode");
            riskIsolationModeLendingNetAmount[tokenAddr] = riskIsolationModeLendingNetAmount[tokenAddr] 
                                                         - userRIMAssetsLendingNetAmount[user][tokenAddr]
                                                         + IERC20(assetsDepositAndLend[riskIsolationModeAcceptAssets][1]).balanceOf(user)
                                                         - amount;
            userRIMAssetsLendingNetAmount[user][tokenAddr] = IERC20(assetsDepositAndLend[riskIsolationModeAcceptAssets][1]).balanceOf(user)
                                                           - amount;
        }else {
            require((licensedAssets[tokenAddr].lendingModeNum == userMode[user]),"Lending Manager: Wrong Mode, Need in same homogeneous Mode");
        }
        _beforeUpdate(tokenAddr);
        iDepositOrLoanCoin(assetsDepositAndLend[tokenAddr][1]).burnCoin(user,amount);
        IERC20(tokenAddr).transferFrom(msg.sender,lendingVault,amount);
        _assetsValueUpdate(tokenAddr);
        emit RepayLoan(tokenAddr, amount, user);
    }

    //------------------------------ Liquidate Function------------------------------
    // token Liquidate
    function tokenLiquidate(address user,
                            address liquidateToken,
                            uint    liquidateAmount, 
                            address depositToken) public returns(uint usedAmount) {
        require(liquidateAmount > 0,"Lending Manager: Cant Pledge 0 amount");
        require(viewUsersHealthFactor(user) < 1 ether,"Lending Manager: Users Health Factor Need < 1 ether");
        uint amountLending = iDepositOrLoanCoin(assetsDepositAndLend[liquidateToken][0]).balanceOf(user);
        uint amountDeposit = iDepositOrLoanCoin(assetsDepositAndLend[depositToken][1]).balanceOf(user);
        require( amountLending >= liquidateAmount,"Lending Manager: amountLending >= liquidateAmount");

        usedAmount  = usedAmount * iSlcOracle(oracleAddr).getPrice(liquidateToken) / 1 ether;
        usedAmount = usedAmount * (10000 - licensedAssets[liquidateToken].liquidationPenalty) * 1 ether / 
                                  (10000 * iSlcOracle(oracleAddr).getPrice(depositToken));
        require( amountDeposit >= usedAmount,"Lending Manager: amountLending >= liquidateAmount");

        iLendingVaults(lendingVault).vaultsERC20Approve(liquidateToken, liquidateAmount); 
        IERC20(depositToken).transferFrom(msg.sender, lendingVault, usedAmount);
        IERC20(liquidateToken).transferFrom(lendingVault, msg.sender, liquidateAmount);
        iDepositOrLoanCoin(assetsDepositAndLend[liquidateToken][0]).burnCoin(user,liquidateAmount);
        iDepositOrLoanCoin(assetsDepositAndLend[depositToken][1]).burnCoin(user,usedAmount);
    }
    function tokenLiquidateEstimate(address user,
                            address liquidateToken,
                            address depositToken) public view returns(uint[2] memory maxAmounts){
        if(viewUsersHealthFactor(user) >= 1 ether){
            uint[2] memory zero;
            return zero;
        }
        uint amountliquidate = iDepositOrLoanCoin(assetsDepositAndLend[liquidateToken][0]).balanceOf(user);
        uint amountDeposit = iDepositOrLoanCoin(assetsDepositAndLend[depositToken][1]).balanceOf(user);

        amountliquidate = amountliquidate * iSlcOracle(oracleAddr).getPrice(liquidateToken) / 1 ether;
        amountDeposit = amountDeposit * iSlcOracle(oracleAddr).getPrice(depositToken) / 1 ether
                      * 10000 / (10000 - licensedAssets[liquidateToken].liquidationPenalty);

        if(amountliquidate < amountDeposit){
            maxAmounts[0] = amountliquidate;
            maxAmounts[1] = amountliquidate * (10000 - licensedAssets[liquidateToken].liquidationPenalty) * 1 ether 
                                            / (10000 * iSlcOracle(oracleAddr).getPrice(depositToken));
        }else if(amountliquidate == amountDeposit){
            maxAmounts[0] = amountliquidate;
            maxAmounts[1] = amountDeposit;
        }else{
            maxAmounts[1] = amountDeposit;
            maxAmounts[0] = amountDeposit * 1 ether / iSlcOracle(oracleAddr).getPrice(depositToken);
        }
    }
}