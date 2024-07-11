// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20NoTransfer.sol";
import "../interfaces/iLendingManager.sol";

contract depositOrLoanCoin is ERC20NoTransfer {
    address public manager;
    address public setter;
    address newsetter;
    address public OCoin;
    uint public depositOrLoan;
    uint public OQCtotalSupply; //OriginalQuantityCoin
    mapping(address=>uint) public userOQCAmount;

    constructor(uint _depositOrLoan,address _OCoin, address _manager, string memory _name,string memory _symbol) ERC20NoTransfer(_name, _symbol){
        setter = msg.sender;
        OCoin = _OCoin;
        manager = _manager;
        depositOrLoan = _depositOrLoan;
    }

    //----------------------------modifier ----------------------------
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'Deposit Or Loan Coin: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    modifier onlyManager() {
        require(msg.sender == manager, 'Deposit Or Loan Coin: Only Manager Use');
        _;
    }
    modifier onlySetter() {
        require(msg.sender == setter, 'Deposit Or Loan Coin: Only setter Use');
        _;
    }

    //----------------------------- event -----------------------------
    event Mint(address indexed token,address mintAddress, uint amount);
    event Burn(address indexed token,address burnAddress, uint amount);
    //-------------------------- sys function --------------------------

    function resetup(address _manager) external onlySetter{
        manager = _manager;
    }
    function transferSetter(address _set) external onlySetter{
        newsetter = _set;
    }
    function acceptSetter(bool _TorF) external {
        require(msg.sender == newsetter, 'Deposit Or Loan Coin: Permission FORBIDDEN');
        if(_TorF){
            setter = newsetter;
        }
        newsetter = address(0);
    }
    //----------------------------- function -----------------------------

    /**
     * @dev mint
     */
    function mintCoin(address _account,uint256 _value) public onlyManager lock{
        uint addTokens;
        require(_value > 0,"Deposit Or Loan Coin: Input value MUST > 0");

        addTokens = iLendingManager(manager).getCoinValues(address(this))[depositOrLoan];

        addTokens = _value * 1 ether / addTokens;
        userOQCAmount[_account] += addTokens;
        OQCtotalSupply += addTokens;

        emit Transfer(address(0), _account, _value);
        emit Mint(address(this), _account, _value);
    }
    /**
     * @dev burn
     */
    function burnCoin(address _account,uint256 _value) public onlyManager lock{
        uint burnTokens;
        require(_value > 0,"Deposit Or Loan Coin: Con't burn 0");
        require(_value <= balanceOf(_account),"Deposit Or Loan Coin: Must <= account balance");

        burnTokens = iLendingManager(manager).getCoinValues(address(this))[depositOrLoan];

        burnTokens = _value * 1 ether / burnTokens;
        userOQCAmount[_account] -= burnTokens;
        OQCtotalSupply -= burnTokens;

        emit Burn(address(this), _account, _value);
        emit Transfer(_account, address(0), _value);
    }

    function burnAllCoin(address _account) public {
        burnCoin( _account,balanceOf(_account));
    }

    //---------------------------------------------------------------------
    /**
     * @dev balance Of account will auto increase
     */
    function balanceOf(address account) public view virtual override returns (uint) {
        uint coinValue;
        coinValue = iLendingManager(manager).getCoinValues(OCoin)[depositOrLoan];
        return coinValue * userOQCAmount[account] / 1 ether;
    }
    /**
     * @dev balance Of totalSupply will auto increase
     */
    function totalSupply() public view virtual override returns (uint) {
        uint coinValue;
        coinValue = iLendingManager(manager).getCoinValues(OCoin)[depositOrLoan];
        return coinValue * OQCtotalSupply / 1 ether;
    }

}
