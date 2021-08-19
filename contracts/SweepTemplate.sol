// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    
}

// EMPIRE EDITS
enum PairType {Common, LiquidityLocked, SweepableToken0, SweepableToken1}

interface IEmpirePair {
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function sweptAmount() external view returns (uint256);

    function sweepableToken() external view returns (address);

    function liquidityLocked() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(
        address,
        address,
        PairType,
        uint256
    ) external;

    function sweep(uint256 amount, bytes calldata data) external;

    function unsweep(uint256 amount) external;

    function getMaxSweepable() external view returns (uint256);

    function calculateSubFloor(IERC20 wrappedToken, IERC20 WBNB) external view returns (uint256);    
}

contract SweepTemplate is Context, IERC20, Ownable {

    string public constant name = "SWEEP_TEMPLATE";
    string public constant symbol = "SWEEP_1";
    uint8 public constant decimals = 18;
    
    // EMPIRE EDITS
    address public empirePair;
    address public WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;

    mapping(address => uint256) balances;

    mapping(address => mapping (address => uint256)) allowed;

    uint256 totalSupply_;

    using SafeMath for uint256;

   constructor(uint256 total) public {
    totalSupply_ = total;
    balances[msg.sender] = totalSupply_;
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

    // require(amount < calculateSubFloor(wrappedToken?, WBNB)) - basic idea need refining

    function unsweep(uint256 amount) external onlyOwner() {
        IERC20(WBNB).approve(empirePair, amount);
        IEmpirePair(empirePair).unsweep(amount);
    }

    uint256 belowFloorSweepInitiation;
    address public uniswapV2Factory = 0x54CF8930796e1e0c7366c6F04D1Ea6Ad6FA5B708; //NOT FACTORY ADDR
    event belowFloorSweepInitiated();


    function declareSweepBelowFloorIntent() external onlyOwner {
        belowFloorSweepInitiation = now;
        emit belowFloorSweepInitiated();
    }

    function sweepBelowFloor(uint256 amount, bytes calldata data) external onlyOwner() {
        require(belowFloorSweepInitiation = now - 7 days);
    }

    //wrapped token?
    //import uniswapv2library 
    //uniswap library works for BSC?
    function calculateSubFloor(IERC20 wrappedToken) public override view returns (uint256)
    {
        uint256 freeEmpire = this.totalSupply().sub(this.balanceOf(empirePair));
        uint256 sellAllProceeds = 0;
        if (freeEmpire > 0) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = address(WBNB);
            uint256[] memory amountsOut = UniswapV2Library.getAmountsOut(address(uniswapV2Factory), freeEmpire, path);
            sellAllProceeds = amountsOut[1];
        }
        uint256 backingInPool = WBNB.balanceOf(empirePair);
        if (backingInPool <= sellAllProceeds) { return 0; }
        uint256 excessInPool = backingInPool - sellAllProceeds;

        uint256 requiredBacking = WBNB.totalSupply().sub(excessInPool);
        uint256 currentBacking = wrappedToken.balanceOf(address(WBNB));
        if (requiredBacking >= currentBacking) { return 0; }
        return currentBacking - requiredBacking;
    }

    receive() external payable {
    }
    
}


