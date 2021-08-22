// SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IEmpirePair.sol";
import "../interfaces/IEmpireFactory.sol";
import "../interfaces/IEmpireRouter.sol";

contract EmpireTemplateLocked is Context, IERC20, Ownable {

    string public constant name = "EMPIRE_TEMPLATE";
    string public constant symbol = "EMPIRE_L";
    uint8 public constant decimals = 18;
    
    // EMPIRE EDITS
    address public empirePair;
    address public WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;

    mapping(address => uint256) balances;

    mapping(address => mapping (address => uint256)) allowed;

    uint256 totalSupply_;

    using SafeMath for uint256;

   constructor(uint256 total, address tester) public {
        totalSupply_ = total;
        balances[tester] = totalSupply_;

        IEmpireRouter _empireRouter = IEmpireRouter(0xE80F605F0dC26639288BB49AF43116Ac8ddF143e);
        empirePair = IEmpireFactory(_empireRouter.factory())
            .createEmpirePair(address(this), _empireRouter.WETH(), PairType.SweepableToken1, 0);


    }

    function totalSupply() public override view returns (uint256) {
    return totalSupply_;
    }

    function balanceOf(address tokenOwner) public override view returns (uint256) {
        return balances[tokenOwner];
    }

    function transfer(address receiver, uint256 numTokens) public override returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(numTokens);
        balances[receiver] = balances[receiver].add(numTokens);
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }

    function approve(address delegate, uint256 numTokens) public override returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    function allowance(address owner, address delegate) public override view returns (uint) {
        return allowed[owner][delegate];
    }

    function transferFrom(address owner, address buyer, uint256 numTokens) public override returns (bool) {
        require(numTokens <= balances[owner]);
        require(numTokens <= allowed[owner][msg.sender]);

        balances[owner] = balances[owner].sub(numTokens);
        allowed[owner][msg.sender] = allowed[owner][msg.sender].sub(numTokens);
        balances[buyer] = balances[buyer].add(numTokens);
        emit Transfer(owner, buyer, numTokens);
        return true;
    }
    
     modifier onlyPair() {
        require(
            msg.sender == empirePair,
            "Empire::onlyPair: Insufficient Privileges"
        );
        _;
    }

    // EMPIRE EDITS
    function updateSweepablePair(address pair) external onlyOwner() {
        empirePair = pair;
    }
    
    function sweep(uint256 amount, bytes calldata data) external onlyOwner() {
        IEmpirePair(empirePair).sweep(amount, data);
    }

    function empireSweepCall(uint256 amount, bytes calldata) external onlyPair() {
        IERC20(WBNB).transfer(owner(), amount);
    }

    function unsweep(uint256 amount) external onlyOwner() {
        IERC20(WBNB).approve(empirePair, amount);
        IEmpirePair(empirePair).unsweep(amount);
    }

    receive() external payable {
    }
    
}


