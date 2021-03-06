/**
 *Submitted for verification at Etherscan.io on 2019-11-14
*/

// hevm: flattened sources of /nix/store/pn2d4gb0yq19i7ixbxiy90933vlxhacj-esm-8e2d767/src/ESM.sol
pragma solidity >=0.5.12;

interface GemLikeESM {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface EndLikeESM {
    function cage() external;
}

contract ESM {
    GemLikeESM public gem; // collateral
    EndLikeESM public end; // cage module
    address public pit; // burner
    uint256 public min; // threshold
    uint256 public fired;

    mapping(address => uint256) public sum; // per-address balance
    uint256 public Sum; // total balance

    constructor(address gem_, address end_, address pit_, uint256 min_) public {
        gem = GemLikeESM(gem_);
        end = EndLikeESM(end_);
        pit = pit_;
        min = min_;
    }

    // -- math --
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x + y;
        require(z >= x);
    }

    function fire() external {
        require(fired == 0,  "esm/already-fired");
        require(Sum >= min,  "esm/min-not-reached");

        end.cage();

        fired = 1;
    }

    function join(uint256 wad) external {
        require(fired == 0, "esm/already-fired");

        sum[msg.sender] = add(sum[msg.sender], wad);
        Sum = add(Sum, wad);

        require(gem.transferFrom(msg.sender, pit, wad), "esm/transfer-failed");
    }
}
