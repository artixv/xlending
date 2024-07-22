// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/iDepositOrLoanCoin.sol";
import "./interfaces/iLendingManager.sol";

contract lendingVaults  {
    address public lendingManager;

    address public setter;
    address newsetter;
    address public rebalancer;

    constructor() {
        setter = msg.sender;
    }

    //----------------------------modifier ----------------------------

    modifier onlySetter() {
        require(msg.sender == setter, 'Lending Manager: Only Setter Use');
        _;
    }
    modifier onlyManager() {
        require(msg.sender == lendingManager, 'Lending Manager: Only Setter Use');
        _;
    }
    modifier onlyRebalancer() {
        require(msg.sender == rebalancer, 'Lending Manager: Only Rebalancer Use');
        _;
    }

    //----------------------------        ----------------------------
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
    function setManager(address _manager) external onlySetter{
        lendingManager = _manager;
    }
    function setRebalancer(address _rebalancer) external onlySetter{
        rebalancer = _rebalancer;
    }
    // function assetsDepositAndLendAddrs(address token) external view returns(address[2] memory addrs)
    function excessDisposal(address token) public onlyRebalancer(){
        uint amountD = iDepositOrLoanCoin(iLendingManager(lendingManager).assetsDepositAndLendAddrs(token)[0]).totalSupply();
        uint amountL = iDepositOrLoanCoin(iLendingManager(lendingManager).assetsDepositAndLendAddrs(token)[1]).totalSupply();
        require(IERC20(token).balanceOf(address(this)) > amountD - amountL,"Lending Manager: Cant Do Excess Disposal, asset not enough!");
        IERC20(token).transfer(msg.sender,IERC20(token).balanceOf(address(this)) + amountL - amountD);
    }

    function vaultsERC20Approve(address ERC20Addr,uint amount) external onlyManager{
        IERC20(ERC20Addr).approve(lendingManager,amount);
    }

    // ======================== contract base methods =====================
    fallback() external payable {}
    receive() external payable {}

}