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
import "../libraries/EmpireLibrary.sol";

contract EmpireTemplateSweepable is Context, IERC20, Ownable {

    string public constant name = "EMPIRE_TEMPLATE";
    string public constant symbol = "TEST_SWEEP_1";
    uint8 public constant decimals = 18;
    
    // EMPIRE EDITS
    address public empirePair;
    // address public WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; //TESTNET
    address public empireFactory = 0x06530550A48F990360DFD642d2132354A144F31d; //mainnet address

    mapping(address => uint256) balances;

    mapping(address => mapping (address => uint256)) allowed;

    uint256 totalSupply_;

    uint256 belowFloorSweepStart;

    // uint256 public pairType = 3;

    using SafeMath for uint256;

    event sweepBelowFloorIntent();
    event sweptBelowFloor(uint256 amountSwept);

   constructor(uint256 total, address tester) {
        totalSupply_ = total;
        balances[tester] = totalSupply_;

        IEmpireRouter _empireRouter = IEmpireRouter(0xCfAA4334ec6d5bBCB597e227c28D84bC52d5B5A4);
        empirePair = IEmpireFactory(_empireRouter.factory())
            .createEmpirePair(_empireRouter.WETH(), address(this), PairType.SweepableToken0, 0);

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

    // Allows for Owner to add the pair address after deploying token on the Empire DEX front end
    function updateSweepablePair(address pair) external onlyOwner() {
        empirePair = pair;
    }
    
    // Allows for Owner to sweep any tokens above the price floor
    function sweep(uint256 amount, bytes calldata data) external onlyOwner() {
        require(amount < calculateSubFloor(), "Attempting to Sweep below the price floor"); // REQUIRE THE SWEEP WILL NOT TAKE BELOW THE FLOOR
        IEmpirePair(empirePair).sweep(amount, data);
    }

    // Sweep function utilised by the trading pair address
    function empireSweepCall(uint256 amount, bytes calldata) external onlyPair() {
        IERC20(WBNB).transfer(owner(), amount);
    }

    // Allows for Owner to add liquidity back into the trading pair
    function unsweep(uint256 amount) external onlyOwner() {
        IERC20(WBNB).approve(empirePair, amount);
        IEmpirePair(empirePair).unsweep(amount);
    }

    // Allows for Owner to begin the process to sweep below the floor, requires 7 days wait after initiating
    function beginSweepBelowFloor() external onlyOwner() {
        belowFloorSweepStart = block.timestamp;
        emit sweepBelowFloorIntent();
    }

    // Allows for Owner to sweep tokens below the price floor. Must be called after 7 days of calling beginSweepBelowFloor and only available for 1 Day
    function sweepBelowFloor(uint256 amount, bytes calldata data) external onlyOwner() {
        require(belowFloorSweepStart + 7 days > block.timestamp, "Attempting to Sweep below the price floor before 7 days have expired");
        require(belowFloorSweepStart + 8 days < block.timestamp, "Attempting to Sweep below the price floor after 8 days, re-declare intent to sweep below floor");   //double check logic here, add error notes
        belowFloorSweepStart = 0;
        IEmpirePair(empirePair).sweep(amount, data);
        emit sweptBelowFloor(amount);
    }

    // Calculates the price floor of the token, which is determined by finding how much of the backing token would be left if all holders sold their tokens
    function calculateSubFloor(IERC20 wrappedToken) public view returns (uint256) {
        uint256 freeTokens = this.totalSupply().sub(this.balanceOf(empirePair));
        uint256 sellAllProceeds = 0;
        if (freeTokens > 0) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = address(WBNB);
            uint256[] memory amountsOut = EmpireLibrary.getAmountsOut(address(empireFactory), freeTokens, path);
            sellAllProceeds = amountsOut[1];
        }
        uint256 backingInPool = IERC20(WBNB).balanceOf(empirePair);
        if (backingInPool <= sellAllProceeds) { return 0; }
        uint256 excessInPool = backingInPool - sellAllProceeds;

        // what is this backing stuff? Seems to me excessInPool is the amount of BNB that is in the pool that would still be available if all tokens on the market were sold back into the liquidity pair
        uint256 requiredBacking = IERC20(WBNB).totalSupply().sub(excessInPool);
        uint256 currentBacking = wrappedToken.balanceOf(address(WBNB));
        if (requiredBacking >= currentBacking) { return 0; }
        return currentBacking - requiredBacking;
    }

    // ROOTKIT Calculator for reference

    // https://github.com/RootkitFinance/root-protocol/blob/master/contracts/ERC31337.sol
    // https://github.com/RootkitFinance/root-protocol/blob/master/contracts/RootKitFloorCalculator.sol

    // constructor(IERC20 _wrappedToken, string memory _name, string memory _symbol)
    // WrappedERC20(_wrappedToken, _name, _symbol)

    // function sweepFloor(address to) public override returns (uint256 amountSwept)
    // {
    //     require (to != address(0));
    //     require (sweepers[msg.sender], "Sweepers only");
    //     amountSwept = floorCalculator.calculateSubFloor(wrappedToken, this);
    //     if (amountSwept > 0) {
    //         wrappedToken.safeTransfer(to, amountSwept);
    //     }

    // function calculateSubFloor(IERC20 wrappedToken, IERC20 backingToken) public override view returns (uint256)
    // {
    //     address pair = UniswapV2Library.pairFor(address(uniswapV2Factory), address(rootKit), address(backingToken));
    //     uint256 freeRootKit = rootKit.totalSupply().sub(rootKit.balanceOf(pair));
    //     uint256 sellAllProceeds = 0;
    //     if (freeRootKit > 0) {
    //         address[] memory path = new address[](2);
    //         path[0] = address(rootKit);
    //         path[1] = address(backingToken);
    //         uint256[] memory amountsOut = UniswapV2Library.getAmountsOut(address(uniswapV2Factory), freeRootKit, path);
    //         sellAllProceeds = amountsOut[1];
    //     }
    //     uint256 backingInPool = backingToken.balanceOf(pair);
    //     if (backingInPool <= sellAllProceeds) { return 0; }
    //     uint256 excessInPool = backingInPool - sellAllProceeds;

    //     uint256 requiredBacking = backingToken.totalSupply().sub(excessInPool);
    //     uint256 currentBacking = wrappedToken.balanceOf(address(backingToken));
    //     if (requiredBacking >= currentBacking) { return 0; }
    //     return currentBacking - requiredBacking;
    // }


    // This could be all the code that is necessary cutting out ROOT's backing shit which is from them wrapping their own token I think
    function calculateAmountAvailableForSweep() public view returns (uint256) {
        uint256 freeTokens = this.totalSupply().sub(this.balanceOf(empirePair));
        uint256 sellAllProceeds = 0;
        if (freeTokens > 0) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = address(WBNB);
            uint256[] memory amountsOut = EmpireLibrary.getAmountsOut(address(empireFactory), freeTokens, path);
            sellAllProceeds = amountsOut[1];
        }
        uint256 backingInPool = IERC20(WBNB).balanceOf(empirePair);
        if (backingInPool <= sellAllProceeds) { return 0; }
        uint256 excessBackingInPool = backingInPool - sellAllProceeds;

        return excessBackingInPool;
    }

    receive() external payable {
    }
    
}